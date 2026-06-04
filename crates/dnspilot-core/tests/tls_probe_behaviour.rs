use dnspilot_core::tls_probe::{
    run_tls_handshake_probes_with_handshaker, TlsHandshakeTarget, TlsProbeConfig, TlsProbeError,
    TlsProbeOutcome,
};
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::time::Duration;

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
