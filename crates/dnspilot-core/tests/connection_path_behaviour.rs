use dnspilot_core::connect_probe::ConnectProbeError;
use dnspilot_core::connection_path::{
    run_connection_path_with_clients, run_connection_path_with_clients_and_tls,
    run_udp_connection_path_estimate, ConnectionPathConfig, DnsLookupMeasurement,
};
use dnspilot_core::dns_benchmark::DnsRecordFamily;
use dnspilot_core::dns_resolver::DnsResolverError;
use dnspilot_core::dns_wire::{DnsAnswer, DnsRecordData, DnsResponse, RecordType};
use dnspilot_core::tls_probe::TlsProbeError;
use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, TcpListener, UdpSocket};
use std::sync::mpsc;
use std::thread;
use std::time::Duration;

#[test]
fn combines_dns_latency_with_tcp_connect_latency_for_answer_ips() {
    let config = ConnectionPathConfig {
        profile_id: "cloudflare".into(),
        domains: vec!["example.com".into()],
        attempts_per_record: 1,
        dns_timeout: Duration::from_millis(250),
        connect_timeout: Duration::from_millis(500),
        first_transaction_id: 0x7000,
        connect_port: 443,
        max_connect_targets_per_domain: 4,
        tls_handshake_timeout: None,
        record_family: DnsRecordFamily::Both,
    };
    let mut connect_targets = Vec::new();

    let run = run_connection_path_with_clients(
        &config,
        |_domain, record_type, transaction_id| {
            Ok(DnsLookupMeasurement {
                elapsed: match record_type {
                    RecordType::A => Duration::from_millis(10),
                    RecordType::Aaaa => Duration::from_millis(20),
                },
                response: dns_response(transaction_id, record_type),
            })
        },
        |target| {
            connect_targets.push(target.clone());
            match target.endpoint.ip() {
                IpAddr::V4(_) => Ok(Duration::from_millis(80)),
                IpAddr::V6(_) => Ok(Duration::from_millis(120)),
            }
        },
    );

    assert_eq!(run.dns.samples.len(), 2);
    assert_eq!(run.connect.samples.len(), 2);
    assert_eq!(run.metrics.median_dns_latency_ms, 15.0);
    assert_eq!(run.metrics.median_connect_latency_ms, 100.0);
    assert_eq!(run.metrics.failure_rate, 0.0);
    assert_eq!(run.metrics.timeout_rate, 0.0);
    assert_eq!(run.connect_targets.len(), 2);
    assert!(connect_targets
        .iter()
        .all(|target| target.endpoint.port() == 443));
}

#[test]
fn tcp_family_failures_reduce_path_ip_family_health() {
    let config = ConnectionPathConfig {
        profile_id: "dual-stack-partial".into(),
        domains: vec!["example.com".into()],
        attempts_per_record: 1,
        dns_timeout: Duration::from_millis(250),
        connect_timeout: Duration::from_millis(500),
        first_transaction_id: 0x7700,
        connect_port: 443,
        max_connect_targets_per_domain: 4,
        tls_handshake_timeout: None,
        record_family: DnsRecordFamily::Both,
    };

    let run = run_connection_path_with_clients(
        &config,
        |_domain, record_type, transaction_id| {
            Ok(DnsLookupMeasurement {
                elapsed: Duration::from_millis(10),
                response: dns_response(transaction_id, record_type),
            })
        },
        |target| match target.endpoint.ip() {
            IpAddr::V4(_) => Ok(Duration::from_millis(80)),
            IpAddr::V6(_) => Err(ConnectProbeError::Timeout),
        },
    );

    assert_eq!(run.metrics.failure_rate, 0.5);
    assert_eq!(run.metrics.ipv4_health, 1.0);
    assert_eq!(run.metrics.ipv6_health, 0.0);
}

#[test]
fn tls_certificate_failures_reduce_combined_reliability_when_enabled() {
    let config = ConnectionPathConfig {
        profile_id: "tls-bad-path".into(),
        domains: vec!["example.com".into()],
        attempts_per_record: 1,
        dns_timeout: Duration::from_millis(250),
        connect_timeout: Duration::from_millis(500),
        first_transaction_id: 0x7600,
        connect_port: 443,
        max_connect_targets_per_domain: 4,
        tls_handshake_timeout: Some(Duration::from_millis(600)),
        record_family: DnsRecordFamily::Both,
    };
    let mut tls_server_names = Vec::new();

    let run = run_connection_path_with_clients_and_tls(
        &config,
        |_domain, record_type, transaction_id| {
            Ok(DnsLookupMeasurement {
                elapsed: Duration::from_millis(10),
                response: dns_response_ipv4_only(transaction_id, record_type),
            })
        },
        |_target| Ok(Duration::from_millis(60)),
        |target| {
            tls_server_names.push(target.server_name.clone());
            Err(TlsProbeError::CertificateRejected)
        },
    );

    let tls = run.tls.expect("TLS probe should run when enabled");
    assert_eq!(tls.samples.len(), 1);
    assert_eq!(tls_server_names, vec!["example.com"]);
    assert_eq!(tls.certificate_failure_rate, 1.0);
    assert_eq!(run.metrics.failure_rate, 1.0);
    assert_eq!(run.metrics.timeout_rate, 0.0);
    assert!(run
        .caveats
        .iter()
        .any(|caveat| caveat.contains("TLS certificate")));
}

#[test]
fn reports_caveat_when_dns_response_has_no_usable_ip_answers() {
    let config = ConnectionPathConfig {
        profile_id: "empty".into(),
        domains: vec!["example.com".into()],
        attempts_per_record: 1,
        dns_timeout: Duration::from_millis(250),
        connect_timeout: Duration::from_millis(500),
        first_transaction_id: 0x7100,
        connect_port: 443,
        max_connect_targets_per_domain: 4,
        tls_handshake_timeout: None,
        record_family: DnsRecordFamily::Both,
    };

    let run = run_connection_path_with_clients(
        &config,
        |_domain, _record_type, transaction_id| {
            Ok(DnsLookupMeasurement {
                elapsed: Duration::from_millis(15),
                response: DnsResponse {
                    transaction_id,
                    response_code: 0,
                    answers: vec![],
                },
            })
        },
        |_target| unreachable!("no IP answers should mean no connect probes"),
    );

    assert!(run.metrics.median_connect_latency_ms.is_infinite());
    assert!(run.connect_targets.is_empty());
    assert!(run
        .caveats
        .iter()
        .any(|caveat| caveat.contains("No usable A/AAAA")));
}

#[test]
fn connect_failures_reduce_combined_reliability() {
    let config = ConnectionPathConfig {
        profile_id: "edge-slow".into(),
        domains: vec!["example.com".into()],
        attempts_per_record: 1,
        dns_timeout: Duration::from_millis(250),
        connect_timeout: Duration::from_millis(500),
        first_transaction_id: 0x7200,
        connect_port: 443,
        max_connect_targets_per_domain: 4,
        tls_handshake_timeout: None,
        record_family: DnsRecordFamily::Both,
    };

    let run = run_connection_path_with_clients(
        &config,
        |_domain, record_type, transaction_id| {
            if record_type == RecordType::Aaaa {
                return Err(DnsResolverError::Timeout);
            }
            Ok(DnsLookupMeasurement {
                elapsed: Duration::from_millis(8),
                response: dns_response(transaction_id, record_type),
            })
        },
        |_target| Err(ConnectProbeError::Timeout),
    );

    assert_eq!(run.dns.metrics.timeout_rate, 0.5);
    assert_eq!(run.connect.timeout_rate, 1.0);
    assert_eq!(run.metrics.failure_rate, 1.0);
    assert_eq!(run.metrics.timeout_rate, 1.0);
    assert!(run.metrics.median_connect_latency_ms.is_infinite());
}

#[test]
fn limits_connect_targets_per_domain_and_records_caveat() {
    let config = ConnectionPathConfig {
        profile_id: "many-edges".into(),
        domains: vec!["example.com".into()],
        attempts_per_record: 1,
        dns_timeout: Duration::from_millis(250),
        connect_timeout: Duration::from_millis(500),
        first_transaction_id: 0x7300,
        connect_port: 443,
        max_connect_targets_per_domain: 2,
        tls_handshake_timeout: None,
        record_family: DnsRecordFamily::Both,
    };
    let mut probed = Vec::new();

    let run = run_connection_path_with_clients(
        &config,
        |_domain, record_type, transaction_id| {
            Ok(DnsLookupMeasurement {
                elapsed: Duration::from_millis(12),
                response: dns_response_many_edges(transaction_id, record_type),
            })
        },
        |target| {
            probed.push(target.endpoint);
            Ok(Duration::from_millis(60))
        },
    );

    assert_eq!(run.connect_targets.len(), 2);
    assert_eq!(probed.len(), 2);
    assert!(run
        .caveats
        .iter()
        .any(|caveat| caveat.contains("Limited TCP connect probes")));
}

#[test]
fn limit_keeps_both_ipv4_and_ipv6_when_available() {
    let config = ConnectionPathConfig {
        profile_id: "dual-stack-cdn".into(),
        domains: vec!["example.com".into()],
        attempts_per_record: 1,
        dns_timeout: Duration::from_millis(250),
        connect_timeout: Duration::from_millis(500),
        first_transaction_id: 0x7500,
        connect_port: 443,
        max_connect_targets_per_domain: 2,
        tls_handshake_timeout: None,
        record_family: DnsRecordFamily::Both,
    };

    let run = run_connection_path_with_clients(
        &config,
        |_domain, record_type, transaction_id| {
            Ok(DnsLookupMeasurement {
                elapsed: Duration::from_millis(12),
                response: dns_response_many_edges(transaction_id, record_type),
            })
        },
        |_target| Ok(Duration::from_millis(60)),
    );

    let selected_ips: Vec<IpAddr> = run
        .connect_targets
        .iter()
        .map(|target| target.endpoint.ip())
        .collect();

    assert_eq!(selected_ips.len(), 2);
    assert!(selected_ips.iter().any(IpAddr::is_ipv4));
    assert!(selected_ips.iter().any(IpAddr::is_ipv6));
    assert!(run
        .caveats
        .iter()
        .any(|caveat| caveat.contains("balanced across IPv4/IPv6")));
}

#[test]
fn does_not_record_limit_caveat_when_no_endpoint_was_skipped() {
    let config = ConnectionPathConfig {
        profile_id: "exact-limit".into(),
        domains: vec!["example.com".into()],
        attempts_per_record: 1,
        dns_timeout: Duration::from_millis(250),
        connect_timeout: Duration::from_millis(500),
        first_transaction_id: 0x7400,
        connect_port: 443,
        max_connect_targets_per_domain: 2,
        tls_handshake_timeout: None,
        record_family: DnsRecordFamily::Both,
    };

    let run = run_connection_path_with_clients(
        &config,
        |_domain, record_type, transaction_id| {
            Ok(DnsLookupMeasurement {
                elapsed: Duration::from_millis(12),
                response: dns_response(transaction_id, record_type),
            })
        },
        |_target| Ok(Duration::from_millis(60)),
    );

    assert_eq!(run.connect_targets.len(), 2);
    assert!(!run
        .caveats
        .iter()
        .any(|caveat| caveat.contains("Limited TCP connect probes")));
}

#[test]
fn connection_path_can_limit_dns_records_to_ipv4() {
    let config = ConnectionPathConfig {
        profile_id: "ipv4-path".into(),
        domains: vec!["example.com".into()],
        attempts_per_record: 1,
        dns_timeout: Duration::from_millis(250),
        connect_timeout: Duration::from_millis(500),
        first_transaction_id: 0x7800,
        connect_port: 443,
        max_connect_targets_per_domain: 4,
        tls_handshake_timeout: None,
        record_family: DnsRecordFamily::Ipv4Only,
    };

    let run = run_connection_path_with_clients(
        &config,
        |_domain, record_type, transaction_id| {
            assert_eq!(record_type, RecordType::A);
            Ok(DnsLookupMeasurement {
                elapsed: Duration::from_millis(10),
                response: dns_response(transaction_id, record_type),
            })
        },
        |_target| Ok(Duration::from_millis(60)),
    );

    assert_eq!(run.dns.samples.len(), 1);
    assert!(run
        .dns
        .samples
        .iter()
        .all(|sample| sample.record_type == RecordType::A));
    assert_eq!(run.connect_targets.len(), 1);
    assert!(run
        .connect_targets
        .iter()
        .all(|target| target.endpoint.ip().is_ipv4()));
    assert_eq!(run.metrics.failure_rate, 0.0);
    assert_eq!(run.metrics.ipv4_health, 1.0);
    assert_eq!(run.metrics.ipv6_health, 1.0);
}

#[test]
fn live_connection_path_uses_a_fresh_dns_transaction_id() {
    let listener = TcpListener::bind("127.0.0.1:0").expect("bind TCP listener");
    let connect_port = listener.local_addr().expect("TCP address").port();
    thread::spawn(move || {
        let _ = listener.accept();
    });

    let socket = UdpSocket::bind("127.0.0.1:0").expect("bind fake resolver");
    let resolver = socket.local_addr().expect("resolver address");
    let (sender, receiver) = mpsc::channel();
    thread::spawn(move || {
        let mut buffer = [0_u8; 512];
        let (length, peer) = socket.recv_from(&mut buffer).expect("receive DNS query");
        let request = &buffer[..length];
        let transaction_id = u16::from_be_bytes([request[0], request[1]]);
        let mut response = vec![
            request[0], request[1], 0x81, 0x80, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00,
        ];
        response.extend(&request[12..]);
        response.extend([
            0xc0, 0x0c, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x1e, 0x00, 0x04, 127, 0, 0, 1,
        ]);
        socket.send_to(&response, peer).expect("send DNS response");
        sender.send(transaction_id).expect("send transaction ID");
    });

    let config = ConnectionPathConfig {
        profile_id: "local".into(),
        domains: vec!["example.com".into()],
        attempts_per_record: 1,
        dns_timeout: Duration::from_millis(500),
        connect_timeout: Duration::from_millis(500),
        first_transaction_id: 0x7000,
        connect_port,
        max_connect_targets_per_domain: 1,
        tls_handshake_timeout: None,
        record_family: DnsRecordFamily::Ipv4Only,
    };

    let run = run_udp_connection_path_estimate(&config, resolver);
    let transaction_id = receiver
        .recv_timeout(Duration::from_secs(1))
        .expect("resolver should receive the query");

    assert_ne!(transaction_id, config.first_transaction_id);
    assert_eq!(run.dns.samples[0].transaction_id, transaction_id);
}

fn dns_response(transaction_id: u16, record_type: RecordType) -> DnsResponse {
    let answer = match record_type {
        RecordType::A => DnsRecordData::A(Ipv4Addr::new(93, 184, 216, 34)),
        RecordType::Aaaa => DnsRecordData::Aaaa(Ipv6Addr::new(
            0x2606, 0x2800, 0x0220, 0x0001, 0x0248, 0x1893, 0x25c8, 0x1946,
        )),
    };

    DnsResponse {
        transaction_id,
        response_code: 0,
        answers: vec![DnsAnswer {
            name: "example.com".into(),
            ttl_seconds: 60,
            data: answer,
        }],
    }
}

fn dns_response_ipv4_only(transaction_id: u16, record_type: RecordType) -> DnsResponse {
    let answers = match record_type {
        RecordType::A => vec![DnsAnswer {
            name: "example.com".into(),
            ttl_seconds: 60,
            data: DnsRecordData::A(Ipv4Addr::new(93, 184, 216, 34)),
        }],
        RecordType::Aaaa => vec![],
    };

    DnsResponse {
        transaction_id,
        response_code: 0,
        answers,
    }
}

fn dns_response_many_edges(transaction_id: u16, record_type: RecordType) -> DnsResponse {
    let answers = match record_type {
        RecordType::A => vec![
            DnsRecordData::A(Ipv4Addr::new(93, 184, 216, 34)),
            DnsRecordData::A(Ipv4Addr::new(93, 184, 216, 35)),
            DnsRecordData::A(Ipv4Addr::new(93, 184, 216, 36)),
        ],
        RecordType::Aaaa => vec![
            DnsRecordData::Aaaa(Ipv6Addr::new(
                0x2606, 0x2800, 0x0220, 0x0001, 0x0248, 0x1893, 0x25c8, 0x1946,
            )),
            DnsRecordData::Aaaa(Ipv6Addr::new(
                0x2606, 0x2800, 0x0220, 0x0001, 0x0248, 0x1893, 0x25c8, 0x1947,
            )),
        ],
    };

    DnsResponse {
        transaction_id,
        response_code: 0,
        answers: answers
            .into_iter()
            .map(|data| DnsAnswer {
                name: "example.com".into(),
                ttl_seconds: 60,
                data,
            })
            .collect(),
    }
}
