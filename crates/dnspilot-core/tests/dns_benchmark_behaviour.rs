use dnspilot_core::dns_benchmark::{
    run_dns_benchmark_with_lookup, DnsBenchmarkConfig, DnsRecordFamily, DnsSampleOutcome,
};
use dnspilot_core::dns_resolver::DnsResolverError;
use dnspilot_core::dns_wire::RecordType;
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
    assert_eq!(run.samples[0].failure_detail.as_deref(), Some("DNS query timed out"));
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
