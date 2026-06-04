use dnspilot_core::tls_probe::{
    probe_tls_handshake_once_with_config, run_tls_handshake_probes_with_handshaker,
    TlsHandshakeTarget, TlsProbeConfig, TlsProbeError, TlsProbeOutcome,
};
use rcgen::{generate_simple_self_signed, CertifiedKey};
use rustls::pki_types::{PrivateKeyDer, PrivatePkcs8KeyDer};
use rustls::{ClientConfig, RootCertStore, ServerConfig, ServerConnection};
use std::io::Write;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::net::TcpListener;
use std::sync::Arc;
use std::thread;
use std::time::Duration;

#[test]
fn performs_live_tls_handshake_to_endpoint_with_sni_server_name() {
    let (client_config, server_config) = local_tls_configs();
    let endpoint = spawn_one_handshake_tls_server(server_config);
    let target = TlsHandshakeTarget {
        domain: "localhost".into(),
        server_name: "localhost".into(),
        endpoint,
    };

    let elapsed = probe_tls_handshake_once_with_config(
        &target,
        Duration::from_secs(2),
        Arc::new(client_config),
    )
    .expect("local TLS handshake should complete");

    assert!(elapsed < Duration::from_secs(2));
}

#[test]
fn aggregates_tls_handshake_samples() {
    let config = TlsProbeConfig {
        targets: vec![
            tls_target("github.com", Ipv4Addr::new(140, 82, 112, 4)),
            tls_target("github.com", Ipv4Addr::new(140, 82, 113, 4)),
        ],
        attempts_per_target: 1,
        timeout: Duration::from_millis(750),
    };

    let run = run_tls_handshake_probes_with_handshaker(&config, |target| {
        assert_eq!(target.server_name, "github.com");
        match target.endpoint.ip() {
            IpAddr::V4(ip) if ip == Ipv4Addr::new(140, 82, 112, 4) => {
                Ok(Duration::from_millis(80))
            }
            _ => Ok(Duration::from_millis(120)),
        }
    });

    assert_eq!(run.samples.len(), 2);
    assert_eq!(run.median_tls_handshake_latency_ms, 100.0);
    assert_eq!(run.p95_tls_handshake_latency_ms, 120.0);
    assert_eq!(run.failure_rate, 0.0);
    assert_eq!(run.timeout_rate, 0.0);
    assert_eq!(run.certificate_failure_rate, 0.0);
    assert!(run
        .samples
        .iter()
        .all(|sample| sample.outcome == TlsProbeOutcome::Success));
}

#[test]
fn classifies_timeout_and_certificate_failures() {
    let config = TlsProbeConfig {
        targets: vec![
            tls_target("example.com", Ipv4Addr::new(93, 184, 216, 34)),
            tls_target("example.com", Ipv4Addr::new(93, 184, 216, 35)),
        ],
        attempts_per_target: 1,
        timeout: Duration::from_millis(750),
    };

    let run = run_tls_handshake_probes_with_handshaker(&config, |target| {
        if target.endpoint.ip() == IpAddr::V4(Ipv4Addr::new(93, 184, 216, 34)) {
            return Err(TlsProbeError::Timeout);
        }
        Err(TlsProbeError::CertificateRejected)
    });

    assert_eq!(run.samples.len(), 2);
    assert_eq!(run.failure_rate, 1.0);
    assert_eq!(run.timeout_rate, 0.5);
    assert_eq!(run.certificate_failure_rate, 0.5);
    assert!(run.median_tls_handshake_latency_ms.is_infinite());
    assert_eq!(run.samples[0].outcome, TlsProbeOutcome::Timeout);
    assert_eq!(run.samples[1].outcome, TlsProbeOutcome::CertificateFailure);
}

fn tls_target(domain: &str, ip: Ipv4Addr) -> TlsHandshakeTarget {
    TlsHandshakeTarget {
        domain: domain.into(),
        server_name: domain.into(),
        endpoint: SocketAddr::new(IpAddr::V4(ip), 443),
    }
}

fn local_tls_configs() -> (ClientConfig, ServerConfig) {
    let CertifiedKey { cert, signing_key } =
        generate_simple_self_signed(vec!["localhost".into()]).unwrap();
    let cert_der = cert.der().clone();
    let private_key = PrivateKeyDer::Pkcs8(PrivatePkcs8KeyDer::from(
        signing_key.serialize_der(),
    ));

    let server_config = ServerConfig::builder()
        .with_no_client_auth()
        .with_single_cert(vec![cert_der.clone()], private_key)
        .unwrap();

    let mut roots = RootCertStore::empty();
    roots.add(cert_der).unwrap();
    let client_config = ClientConfig::builder()
        .with_root_certificates(roots)
        .with_no_client_auth();

    (client_config, server_config)
}

fn spawn_one_handshake_tls_server(server_config: ServerConfig) -> SocketAddr {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let endpoint = listener.local_addr().unwrap();

    thread::spawn(move || {
        let (mut tcp, _) = listener.accept().unwrap();
        tcp.set_read_timeout(Some(Duration::from_secs(2))).unwrap();
        tcp.set_write_timeout(Some(Duration::from_secs(2))).unwrap();
        let mut server = ServerConnection::new(Arc::new(server_config)).unwrap();

        while server.is_handshaking() {
            server.complete_io(&mut tcp).unwrap();
        }

        server.writer().write_all(b"ok").unwrap();
        server.complete_io(&mut tcp).unwrap();
    });

    endpoint
}
