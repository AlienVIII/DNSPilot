use crate::connect_probe::{
    probe_tcp_connect_once, run_tcp_connect_probes_with_connector, ConnectProbeConfig,
    ConnectProbeError, ConnectProbeRun, TcpConnectTarget,
};
use crate::dns_benchmark::{run_dns_benchmark_with_lookup, DnsBenchmarkConfig, DnsBenchmarkRun};
use crate::dns_resolver::{query_udp_once, DnsResolverError};
use crate::dns_wire::{DnsRecordData, DnsResponse, RecordType};
use crate::BenchmarkMetrics;
use std::net::{IpAddr, SocketAddr};
use std::time::Duration;

#[derive(Debug, Clone)]
pub struct ConnectionPathConfig {
    pub profile_id: String,
    pub domains: Vec<String>,
    pub attempts_per_record: usize,
    pub dns_timeout: Duration,
    pub connect_timeout: Duration,
    pub first_transaction_id: u16,
    pub connect_port: u16,
    pub max_connect_targets_per_domain: usize,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ConnectionPathRun {
    pub metrics: BenchmarkMetrics,
    pub dns: DnsBenchmarkRun,
    pub connect: ConnectProbeRun,
    pub connect_targets: Vec<TcpConnectTarget>,
    pub caveats: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DnsLookupMeasurement {
    pub response: DnsResponse,
    pub elapsed: Duration,
}

pub fn run_udp_connection_path_estimate(
    config: &ConnectionPathConfig,
    resolver: SocketAddr,
) -> ConnectionPathRun {
    run_connection_path_with_clients(
        config,
        |domain, record_type, transaction_id| {
            query_udp_once(
                resolver,
                domain,
                record_type,
                config.dns_timeout,
                transaction_id,
            )
            .map(|result| DnsLookupMeasurement {
                response: result.response,
                elapsed: result.elapsed,
            })
        },
        |target| probe_tcp_connect_once(target, config.connect_timeout),
    )
}

pub fn run_connection_path_with_clients<D, C>(
    config: &ConnectionPathConfig,
    mut dns_lookup: D,
    connector: C,
) -> ConnectionPathRun
where
    D: FnMut(&str, RecordType, u16) -> Result<DnsLookupMeasurement, DnsResolverError>,
    C: FnMut(&TcpConnectTarget) -> Result<Duration, ConnectProbeError>,
{
    let mut candidate_targets = Vec::new();
    let dns_config = DnsBenchmarkConfig {
        profile_id: config.profile_id.clone(),
        domains: config.domains.clone(),
        attempts_per_record: config.attempts_per_record,
        timeout: config.dns_timeout,
        first_transaction_id: config.first_transaction_id,
    };

    let dns = run_dns_benchmark_with_lookup(&dns_config, |domain, record_type, transaction_id| {
        let measurement = dns_lookup(domain, record_type, transaction_id)?;
        collect_connect_targets(
            &mut candidate_targets,
            domain,
            record_type,
            &measurement.response,
            config.connect_port,
        );
        Ok(measurement.elapsed)
    });

    let (targets, skipped_connect_targets) =
        select_connect_targets(candidate_targets, config.max_connect_targets_per_domain);
    let connect_config = ConnectProbeConfig {
        targets: targets.clone(),
        attempts_per_target: config.attempts_per_record,
        timeout: config.connect_timeout,
    };
    let connect = run_tcp_connect_probes_with_connector(&connect_config, connector);
    let metrics = combine_metrics(&dns.metrics, &connect);
    let caveats = caveats_for(
        &targets,
        &dns,
        &connect,
        config.max_connect_targets_per_domain,
        skipped_connect_targets,
    );

    ConnectionPathRun {
        metrics,
        dns,
        connect,
        connect_targets: targets,
        caveats,
    }
}

fn collect_connect_targets(
    targets: &mut Vec<TcpConnectTarget>,
    domain: &str,
    record_type: RecordType,
    response: &DnsResponse,
    port: u16,
) {
    for answer in &response.answers {
        let ip = match (&answer.data, record_type) {
            (DnsRecordData::A(ip), RecordType::A) => IpAddr::V4(*ip),
            (DnsRecordData::Aaaa(ip), RecordType::Aaaa) => IpAddr::V6(*ip),
            _ => continue,
        };
        let endpoint = SocketAddr::new(ip, port);
        if !targets.iter().any(|target| {
            target.domain == domain && target.endpoint.ip() == ip && target.endpoint.port() == port
        }) {
            targets.push(TcpConnectTarget {
                domain: domain.into(),
                endpoint,
            });
        }
    }
}

fn select_connect_targets(
    candidates: Vec<TcpConnectTarget>,
    max_per_domain: usize,
) -> (Vec<TcpConnectTarget>, usize) {
    if max_per_domain == 0 {
        return (candidates, 0);
    }

    let mut selected = Vec::new();
    let mut skipped = 0;
    let mut domains = Vec::<String>::new();

    for candidate in &candidates {
        if !domains.iter().any(|domain| domain == &candidate.domain) {
            domains.push(candidate.domain.clone());
        }
    }

    for domain in domains {
        let domain_candidates: Vec<&TcpConnectTarget> = candidates
            .iter()
            .filter(|candidate| candidate.domain == domain)
            .collect();
        let limited = balanced_targets_for_domain(&domain_candidates, max_per_domain);
        skipped += domain_candidates.len().saturating_sub(limited.len());
        selected.extend(limited.into_iter().cloned());
    }

    (selected, skipped)
}

fn balanced_targets_for_domain<'a>(
    candidates: &[&'a TcpConnectTarget],
    max_per_domain: usize,
) -> Vec<&'a TcpConnectTarget> {
    let ipv4: Vec<&TcpConnectTarget> = candidates
        .iter()
        .copied()
        .filter(|target| target.endpoint.ip().is_ipv4())
        .collect();
    let ipv6: Vec<&TcpConnectTarget> = candidates
        .iter()
        .copied()
        .filter(|target| target.endpoint.ip().is_ipv6())
        .collect();
    let mut selected = Vec::new();
    let mut ipv4_index = 0;
    let mut ipv6_index = 0;

    while selected.len() < max_per_domain && (ipv4_index < ipv4.len() || ipv6_index < ipv6.len())
    {
        if ipv4_index < ipv4.len() {
            selected.push(ipv4[ipv4_index]);
            ipv4_index += 1;
        }
        if selected.len() >= max_per_domain {
            break;
        }
        if ipv6_index < ipv6.len() {
            selected.push(ipv6[ipv6_index]);
            ipv6_index += 1;
        }
    }

    selected
}

fn combine_metrics(dns: &BenchmarkMetrics, connect: &ConnectProbeRun) -> BenchmarkMetrics {
    BenchmarkMetrics {
        profile_id: dns.profile_id.clone(),
        median_dns_latency_ms: dns.median_dns_latency_ms,
        p95_dns_latency_ms: dns.p95_dns_latency_ms,
        failure_rate: dns.failure_rate.max(connect.failure_rate),
        timeout_rate: dns.timeout_rate.max(connect.timeout_rate),
        median_connect_latency_ms: connect.median_connect_latency_ms,
        ipv4_health: dns.ipv4_health,
        ipv6_health: dns.ipv6_health,
        priority_fit: dns.priority_fit,
    }
}

fn caveats_for(
    targets: &[TcpConnectTarget],
    dns: &DnsBenchmarkRun,
    connect: &ConnectProbeRun,
    max_connect_targets_per_domain: usize,
    skipped_connect_targets: usize,
) -> Vec<String> {
    let mut caveats = vec![
        "Connection-path estimate uses DNS and TCP connect timing only; TLS, HTTP, QUIC, browser cache, and server latency are not measured yet.".into(),
    ];

    if targets.is_empty() {
        caveats.push("No usable A/AAAA answers were returned, so TCP connect probes were skipped.".into());
    }
    if dns.metrics.failure_rate > 0.0 {
        caveats.push("Some DNS lookups failed or timed out.".into());
    }
    if connect.failure_rate > 0.0 {
        caveats.push("Some resolved endpoints failed TCP connect; DNS may be mapping to a poor, blocked, or unreachable path.".into());
    }
    if max_connect_targets_per_domain > 0 && skipped_connect_targets > 0 {
        caveats.push(format!(
            "Limited TCP connect probes to {max_connect_targets_per_domain} endpoint(s) per domain, balanced across IPv4/IPv6 when available, to avoid excessive network traffic; skipped {skipped_connect_targets} endpoint(s)."
        ));
    }

    caveats
}
