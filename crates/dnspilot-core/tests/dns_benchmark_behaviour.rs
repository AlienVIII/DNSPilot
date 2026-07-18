use dnspilot_core::dns_benchmark::{
    run_dns_benchmark_with_lookup, run_udp_dns_benchmark, DnsBenchmarkConfig, DnsRecordFamily,
    DnsSampleOutcome,
};
use dnspilot_core::dns_resolver::DnsResolverError;
use dnspilot_core::dns_wire::RecordType;
use std::net::UdpSocket;
use std::sync::mpsc;
use std::thread;
use std::time::Duration;

#[test]
fn aggregates_dns_samples_into_benchmark_metrics() {
    let config = DnsBenchmarkConfig {
        profile_id: "cloudflare".into(),
        domains: vec!["example.com".into()],
        attempts_per_record: 3,
        timeout: Duration::from_millis(250),
        first_transaction_id: 0x1000,
        record_family: DnsRecordFamily::Both,
    };
    let mut calls = Vec::new();
    let mut outcomes = vec![
        Ok(Duration::from_millis(10)),
        Err(DnsResolverError::Timeout),
        Ok(Duration::from_millis(30)),
        Ok(Duration::from_millis(50)),
        Err(DnsResolverError::ResponseCode(2)),
        Ok(Duration::from_millis(70)),
    ]
    .into_iter();

    let run = run_dns_benchmark_with_lookup(&config, |domain, record_type, transaction_id| {
        calls.push((domain.to_string(), record_type, transaction_id));
        outcomes.next().expect("one outcome per query")
    });

    assert_eq!(run.samples.len(), 6);
    assert_eq!(run.metrics.profile_id, "cloudflare");
    assert_eq!(run.metrics.median_dns_latency_ms, 40.0);
    assert_eq!(run.metrics.p95_dns_latency_ms, 70.0);
    assert!((run.metrics.failure_rate - (2.0 / 6.0)).abs() < f64::EPSILON);
    assert!((run.metrics.timeout_rate - (1.0 / 6.0)).abs() < f64::EPSILON);
    assert!((run.metrics.ipv4_health - (2.0 / 3.0)).abs() < f64::EPSILON);
    assert!((run.metrics.ipv6_health - (2.0 / 3.0)).abs() < f64::EPSILON);

    assert_eq!(calls[0], ("example.com".into(), RecordType::A, 0x1000));
    assert_eq!(calls[3], ("example.com".into(), RecordType::Aaaa, 0x1003));
}

#[test]
fn records_timeout_and_failure_outcomes_without_latency() {
    let config = DnsBenchmarkConfig {
        profile_id: "broken".into(),
        domains: vec!["example.com".into()],
        attempts_per_record: 1,
        timeout: Duration::from_millis(10),
        first_transaction_id: 0x2000,
        record_family: DnsRecordFamily::Both,
    };

    let run = run_dns_benchmark_with_lookup(&config, |_domain, record_type, _transaction_id| {
        match record_type {
            RecordType::A => Err(DnsResolverError::Timeout),
            RecordType::Aaaa => Err(DnsResolverError::ResponseCode(3)),
        }
    });

    assert!(run.metrics.median_dns_latency_ms.is_infinite());
    assert!(run.metrics.p95_dns_latency_ms.is_infinite());
    assert_eq!(run.metrics.failure_rate, 1.0);
    assert_eq!(run.metrics.timeout_rate, 0.5);
    assert_eq!(run.metrics.ipv4_health, 0.0);
    assert_eq!(run.metrics.ipv6_health, 0.0);
    assert!(matches!(run.samples[0].outcome, DnsSampleOutcome::Timeout));
    assert_eq!(
        run.samples[0].failure_detail.as_deref(),
        Some("DNS query timed out")
    );
    assert!(matches!(run.samples[1].outcome, DnsSampleOutcome::Failure));
    assert_eq!(
        run.samples[1].failure_detail.as_deref(),
        Some("DNS resolver returned response code 3")
    );
}

#[test]
fn can_limit_dns_benchmark_to_ipv4_records() {
    let config = DnsBenchmarkConfig {
        profile_id: "ipv4-only".into(),
        domains: vec!["example.com".into()],
        attempts_per_record: 2,
        timeout: Duration::from_millis(250),
        first_transaction_id: 0x3000,
        record_family: DnsRecordFamily::Ipv4Only,
    };
    let mut calls = Vec::new();

    let run = run_dns_benchmark_with_lookup(&config, |domain, record_type, transaction_id| {
        calls.push((domain.to_string(), record_type, transaction_id));
        Ok(Duration::from_millis(10))
    });

    assert_eq!(run.samples.len(), 2);
    assert!(run
        .samples
        .iter()
        .all(|sample| sample.record_type == RecordType::A));
    assert_eq!(run.metrics.failure_rate, 0.0);
    assert_eq!(run.metrics.ipv4_health, 1.0);
    assert_eq!(run.metrics.ipv6_health, 1.0);
    assert_eq!(calls[0], ("example.com".into(), RecordType::A, 0x3000));
    assert_eq!(calls[1], ("example.com".into(), RecordType::A, 0x3001));
}

#[test]
fn live_udp_benchmark_uses_fresh_transaction_ids_on_the_wire() {
    let socket = UdpSocket::bind("127.0.0.1:0").expect("bind fake resolver");
    let resolver = socket.local_addr().expect("resolver address");
    let (sender, receiver) = mpsc::channel();

    thread::spawn(move || {
        let mut transaction_ids = Vec::new();
        for _ in 0..2 {
            let mut buffer = [0_u8; 512];
            let (length, peer) = socket.recv_from(&mut buffer).expect("receive DNS query");
            let request = &buffer[..length];
            transaction_ids.push(u16::from_be_bytes([request[0], request[1]]));
            let mut response = vec![
                request[0], request[1], 0x81, 0x80, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            ];
            response.extend(&request[12..]);
            socket.send_to(&response, peer).expect("send DNS response");
        }
        sender.send(transaction_ids).expect("send transaction IDs");
    });

    let config = DnsBenchmarkConfig {
        profile_id: "local".into(),
        domains: vec!["example.com".into()],
        attempts_per_record: 2,
        timeout: Duration::from_millis(500),
        first_transaction_id: 0x1234,
        record_family: DnsRecordFamily::Ipv4Only,
    };

    let run = run_udp_dns_benchmark(&config, resolver);
    let transaction_ids = receiver
        .recv_timeout(Duration::from_secs(1))
        .expect("resolver should receive both queries");

    assert_ne!(transaction_ids[0], config.first_transaction_id);
    assert_ne!(
        transaction_ids[1],
        config.first_transaction_id.wrapping_add(1)
    );
    assert_ne!(transaction_ids[0], transaction_ids[1]);
    assert_eq!(
        run.samples
            .iter()
            .map(|sample| sample.transaction_id)
            .collect::<Vec<_>>(),
        transaction_ids
    );
}
