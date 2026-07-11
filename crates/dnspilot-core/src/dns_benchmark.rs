use crate::dns_resolver::{query_udp_once, DnsResolverError};
use crate::dns_wire::RecordType;
use crate::BenchmarkMetrics;
use std::net::SocketAddr;
use std::time::Duration;

const BOTH_RECORD_TYPES: [RecordType; 2] = [RecordType::A, RecordType::Aaaa];
const IPV4_RECORD_TYPES: [RecordType; 1] = [RecordType::A];
const IPV6_RECORD_TYPES: [RecordType; 1] = [RecordType::Aaaa];

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DnsRecordFamily {
    Both,
    Ipv4Only,
    Ipv6Only,
}

impl DnsRecordFamily {
    fn record_types(self) -> &'static [RecordType] {
        match self {
            DnsRecordFamily::Both => &BOTH_RECORD_TYPES,
            DnsRecordFamily::Ipv4Only => &IPV4_RECORD_TYPES,
            DnsRecordFamily::Ipv6Only => &IPV6_RECORD_TYPES,
        }
    }
}

#[derive(Debug, Clone)]
pub struct DnsBenchmarkConfig {
    pub profile_id: String,
    pub domains: Vec<String>,
    pub attempts_per_record: usize,
    pub timeout: Duration,
    pub first_transaction_id: u16,
    pub record_family: DnsRecordFamily,
}

#[derive(Debug, Clone, PartialEq)]
pub struct DnsBenchmarkRun {
    pub metrics: BenchmarkMetrics,
    pub samples: Vec<DnsBenchmarkSample>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct DnsBenchmarkSample {
    pub domain: String,
    pub record_type: RecordType,
    pub transaction_id: u16,
    pub elapsed: Option<Duration>,
    pub outcome: DnsSampleOutcome,
    pub failure_detail: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DnsSampleOutcome {
    Success,
    Timeout,
    Failure,
}

pub fn run_udp_dns_benchmark(config: &DnsBenchmarkConfig, resolver: SocketAddr) -> DnsBenchmarkRun {
    run_dns_benchmark_with_lookup(config, |domain, record_type, transaction_id| {
        query_udp_once(
            resolver,
            domain,
            record_type,
            config.timeout,
            transaction_id,
        )
        .map(|result| result.elapsed)
    })
}

pub fn run_dns_benchmark_with_lookup<F>(
    config: &DnsBenchmarkConfig,
    mut lookup: F,
) -> DnsBenchmarkRun
where
    F: FnMut(&str, RecordType, u16) -> Result<Duration, DnsResolverError>,
{
    let mut samples = Vec::new();
    let mut query_index = 0_u16;

    for domain in &config.domains {
        for &record_type in config.record_family.record_types() {
            for _ in 0..config.attempts_per_record {
                let transaction_id = config.first_transaction_id.wrapping_add(query_index);
                query_index = query_index.wrapping_add(1);

                let sample = match lookup(domain, record_type, transaction_id) {
                    Ok(elapsed) => DnsBenchmarkSample {
                        domain: domain.clone(),
                        record_type,
                        transaction_id,
                        elapsed: Some(elapsed),
                        outcome: DnsSampleOutcome::Success,
                        failure_detail: None,
                    },
                    Err(error @ DnsResolverError::Timeout) => DnsBenchmarkSample {
                        domain: domain.clone(),
                        record_type,
                        transaction_id,
                        elapsed: None,
                        outcome: DnsSampleOutcome::Timeout,
                        failure_detail: Some(error.to_string()),
                    },
                    Err(error) => DnsBenchmarkSample {
                        domain: domain.clone(),
                        record_type,
                        transaction_id,
                        elapsed: None,
                        outcome: DnsSampleOutcome::Failure,
                        failure_detail: Some(error.to_string()),
                    },
                };
                samples.push(sample);
            }
        }
    }

    DnsBenchmarkRun {
        metrics: summarize_metrics(&config.profile_id, &samples),
        samples,
    }
}

fn summarize_metrics(profile_id: &str, samples: &[DnsBenchmarkSample]) -> BenchmarkMetrics {
    let total = samples.len() as f64;
    let successful_latencies: Vec<f64> = samples
        .iter()
        .filter_map(|sample| sample.elapsed.map(duration_ms))
        .collect();

    let failure_count = samples
        .iter()
        .filter(|sample| sample.outcome != DnsSampleOutcome::Success)
        .count() as f64;
    let timeout_count = samples
        .iter()
        .filter(|sample| sample.outcome == DnsSampleOutcome::Timeout)
        .count() as f64;

    BenchmarkMetrics {
        profile_id: profile_id.into(),
        median_dns_latency_ms: median(&successful_latencies),
        p95_dns_latency_ms: percentile_95(&successful_latencies),
        failure_rate: rate(failure_count, total),
        timeout_rate: rate(timeout_count, total),
        median_connect_latency_ms: f64::INFINITY,
        ipv4_health: record_health(samples, RecordType::A),
        ipv6_health: record_health(samples, RecordType::Aaaa),
        priority_fit: 1.0,
    }
}

fn record_health(samples: &[DnsBenchmarkSample], record_type: RecordType) -> f64 {
    let total = samples
        .iter()
        .filter(|sample| sample.record_type == record_type)
        .count() as f64;
    let successes = samples
        .iter()
        .filter(|sample| {
            sample.record_type == record_type && sample.outcome == DnsSampleOutcome::Success
        })
        .count() as f64;

    if total == 0.0 {
        1.0
    } else {
        rate(successes, total)
    }
}

fn median(values: &[f64]) -> f64 {
    let sorted = sorted_finite(values);
    if sorted.is_empty() {
        return f64::INFINITY;
    }

    let middle = sorted.len() / 2;
    if sorted.len() % 2 == 0 {
        (sorted[middle - 1] + sorted[middle]) / 2.0
    } else {
        sorted[middle]
    }
}

fn percentile_95(values: &[f64]) -> f64 {
    let sorted = sorted_finite(values);
    if sorted.is_empty() {
        return f64::INFINITY;
    }

    let rank = ((sorted.len() as f64) * 0.95).ceil() as usize;
    let index = rank.saturating_sub(1).min(sorted.len() - 1);
    sorted[index]
}

fn sorted_finite(values: &[f64]) -> Vec<f64> {
    let mut sorted: Vec<f64> = values
        .iter()
        .copied()
        .filter(|value| value.is_finite())
        .collect();
    sorted.sort_by(f64::total_cmp);
    sorted
}

fn duration_ms(duration: Duration) -> f64 {
    duration.as_secs_f64() * 1000.0
}

fn rate(numerator: f64, denominator: f64) -> f64 {
    if denominator == 0.0 {
        0.0
    } else {
        numerator / denominator
    }
}
