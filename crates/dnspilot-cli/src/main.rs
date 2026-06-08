use clap::{Parser, Subcommand, ValueEnum};
use dnspilot_core::{
    built_in_profiles, built_in_test_suites, capability_for,
    connect_probe::{ConnectProbeOutcome, ConnectProbeSample, TcpConnectTarget},
    connection_path::{run_udp_connection_path_estimate, ConnectionPathConfig},
    dns_benchmark::{
        run_udp_dns_benchmark, DnsBenchmarkConfig, DnsBenchmarkSample, DnsSampleOutcome,
    },
    dns_wire::RecordType,
    recommend,
    tls_probe::{TlsProbeOutcome, TlsProbeSample},
    BenchmarkMetrics, Platform, RecommendationMode,
};
use std::net::SocketAddr;
use std::time::Duration;

#[derive(Debug, Parser)]
#[command(name = "dnspilot")]
#[command(about = "DNS Pilot shared-core smoke CLI")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    Catalog,
    Capability {
        #[arg(value_enum)]
        platform: PlatformArg,
    },
    Benchmark {
        #[arg(long)]
        resolver: SocketAddr,
        #[arg(long = "domain", required = true)]
        domains: Vec<String>,
        #[arg(long, default_value_t = 3)]
        attempts: usize,
        #[arg(long, default_value_t = 800)]
        timeout_ms: u64,
        #[arg(long, default_value = "manual")]
        profile_id: String,
    },
    PathEstimate {
        #[arg(long)]
        resolver: SocketAddr,
        #[arg(long = "domain", required = true)]
        domains: Vec<String>,
        #[arg(long, default_value_t = 3)]
        attempts: usize,
        #[arg(long, default_value_t = 800)]
        dns_timeout_ms: u64,
        #[arg(long, default_value_t = 1000)]
        connect_timeout_ms: u64,
        #[arg(long, default_value_t = 443)]
        connect_port: u16,
        #[arg(long, default_value_t = 4)]
        max_connect_targets_per_domain: usize,
        #[arg(long)]
        tls_handshake_timeout_ms: Option<u64>,
        #[arg(long, default_value = "manual")]
        profile_id: String,
    },
    RecommendSample,
}

#[derive(Debug, Clone, Copy, ValueEnum)]
enum PlatformArg {
    MacosStore,
    Ios,
    AndroidPlay,
    WindowsStore,
    LinuxFlatpak,
    LinuxSnap,
    LinuxNativePower,
    MacosPower,
    WindowsPower,
}

fn main() {
    let cli = Cli::parse();
    match cli.command {
        Command::Catalog => {
            let payload = serde_json::json!({
                "profiles": built_in_profiles(),
                "testSuites": built_in_test_suites(),
            });
            println!(
                "{}",
                serde_json::to_string_pretty(&payload).expect("serialize catalog")
            );
        }
        Command::Capability { platform } => {
            let capability = capability_for(platform.into());
            println!(
                "{}",
                serde_json::to_string_pretty(&capability).expect("serialize capability")
            );
        }
        Command::Benchmark {
            resolver,
            domains,
            attempts,
            timeout_ms,
            profile_id,
        } => {
            let config = DnsBenchmarkConfig {
                profile_id,
                domains,
                attempts_per_record: attempts,
                timeout: Duration::from_millis(timeout_ms),
                first_transaction_id: 0x5000,
            };
            let run = run_udp_dns_benchmark(&config, resolver);
            let payload = serde_json::json!({
                "metrics": run.metrics,
                "samples": run.samples.iter().map(sample_to_json).collect::<Vec<_>>(),
                "warning": "Live DNS results estimate resolver behavior on this network; they do not prove full browser or app speed.",
            });
            println!(
                "{}",
                serde_json::to_string_pretty(&payload).expect("serialize benchmark")
            );
        }
        Command::PathEstimate {
            resolver,
            domains,
            attempts,
            dns_timeout_ms,
            connect_timeout_ms,
            connect_port,
            max_connect_targets_per_domain,
            tls_handshake_timeout_ms,
            profile_id,
        } => {
            let config = ConnectionPathConfig {
                profile_id,
                domains,
                attempts_per_record: attempts,
                dns_timeout: Duration::from_millis(dns_timeout_ms),
                connect_timeout: Duration::from_millis(connect_timeout_ms),
                first_transaction_id: 0x7000,
                connect_port,
                max_connect_targets_per_domain,
                tls_handshake_timeout: tls_handshake_timeout_ms.map(Duration::from_millis),
            };
            let run = run_udp_connection_path_estimate(&config, resolver);
            let tls_samples = run
                .tls
                .as_ref()
                .map(|tls| {
                    tls.samples
                        .iter()
                        .map(tls_sample_to_json)
                        .collect::<Vec<_>>()
                })
                .unwrap_or_default();
            let warning = if tls_handshake_timeout_ms.is_some() {
                "Connection-path estimates use DNS, TCP connect, and TLS/SNI handshake timing only; they do not prove full browser, app, HTTP, or QUIC performance."
            } else {
                "Connection-path estimates use DNS plus TCP connect timing only; they do not prove full browser, app, TLS, HTTP, or QUIC performance."
            };
            let (health, primary_issue) = path_health_summary(&run);
            let summary = serde_json::json!({
                "measurement_scope": if tls_handshake_timeout_ms.is_some() { "dns-tcp-tls" } else { "dns-tcp" },
                "health": health,
                "primary_issue": primary_issue,
                "tls_enabled": tls_handshake_timeout_ms.is_some(),
                "trust_store": if tls_handshake_timeout_ms.is_some() {
                    serde_json::Value::String("mozilla-webpki-roots".into())
                } else {
                    serde_json::Value::Null
                },
                "domain_count": run.dns.samples.iter().map(|sample| &sample.domain).collect::<std::collections::BTreeSet<_>>().len(),
                "dns_sample_count": run.dns.samples.len(),
                "connect_target_count": run.connect_targets.len(),
                "connect_sample_count": run.connect.samples.len(),
                "tls_sample_count": tls_samples.len(),
                "caveat_count": run.caveats.len(),
            });
            let payload = serde_json::json!({
                "summary": summary,
                "metrics": run.metrics,
                "dns_samples": run.dns.samples.iter().map(sample_to_json).collect::<Vec<_>>(),
                "connect_samples": run.connect.samples.iter().map(connect_sample_to_json).collect::<Vec<_>>(),
                "tls_samples": tls_samples,
                "connect_targets": run.connect_targets.iter().map(connect_target_to_json).collect::<Vec<_>>(),
                "caveats": run.caveats,
                "warning": warning,
            });
            println!(
                "{}",
                serde_json::to_string_pretty(&payload).expect("serialize path estimate")
            );
        }
        Command::RecommendSample => {
            let current = BenchmarkMetrics {
                profile_id: "current".into(),
                median_dns_latency_ms: 50.0,
                p95_dns_latency_ms: 140.0,
                failure_rate: 0.02,
                timeout_rate: 0.01,
                median_connect_latency_ms: 170.0,
                ipv4_health: 1.0,
                ipv6_health: 0.7,
                priority_fit: 1.0,
            };
            let quad9 = BenchmarkMetrics {
                profile_id: "quad9".into(),
                median_dns_latency_ms: 18.0,
                p95_dns_latency_ms: 42.0,
                failure_rate: 0.0,
                timeout_rate: 0.0,
                median_connect_latency_ms: 75.0,
                ipv4_health: 1.0,
                ipv6_health: 0.95,
                priority_fit: 1.0,
            };
            let recommendation = recommend(
                &[current.clone(), quad9],
                Some(&current),
                RecommendationMode::BestOverall,
            )
            .expect("sample recommendation");
            println!(
                "{}",
                serde_json::to_string_pretty(&recommendation).expect("serialize recommendation")
            );
        }
    }
}

fn connect_sample_to_json(sample: &ConnectProbeSample) -> serde_json::Value {
    serde_json::json!({
        "domain": sample.domain,
        "endpoint": sample.endpoint.to_string(),
        "elapsed_ms": sample.elapsed.map(|elapsed| elapsed.as_secs_f64() * 1000.0),
        "outcome": connect_outcome_name(sample.outcome),
    })
}

fn connect_target_to_json(target: &TcpConnectTarget) -> serde_json::Value {
    serde_json::json!({
        "domain": target.domain,
        "endpoint": target.endpoint.to_string(),
    })
}

fn path_health_summary(
    run: &dnspilot_core::connection_path::ConnectionPathRun,
) -> (&'static str, &'static str) {
    if run.connect_targets.is_empty() {
        return ("inconclusive", "no-connect-targets");
    }

    if run.dns.metrics.failure_rate >= 1.0 {
        return ("failed", "dns-failure");
    }
    if run.connect.failure_rate >= 1.0 {
        return ("failed", "connect-failure");
    }
    if let Some(tls) = &run.tls {
        if tls.certificate_failure_rate > 0.0 {
            return ("failed", "tls-certificate-failure");
        }
        if tls.failure_rate >= 1.0 {
            return ("failed", "tls-handshake-failure");
        }
        if tls.failure_rate > 0.0 {
            return ("degraded", "tls-handshake-failure");
        }
    }

    if run.metrics.failure_rate > 0.0 || run.metrics.timeout_rate > 0.0 {
        return ("degraded", "partial-failure");
    }

    ("healthy", "none")
}

fn tls_sample_to_json(sample: &TlsProbeSample) -> serde_json::Value {
    serde_json::json!({
        "domain": sample.domain,
        "server_name": sample.server_name,
        "endpoint": sample.endpoint.to_string(),
        "elapsed_ms": sample.elapsed.map(|elapsed| elapsed.as_secs_f64() * 1000.0),
        "outcome": tls_outcome_name(sample.outcome),
    })
}

fn sample_to_json(sample: &DnsBenchmarkSample) -> serde_json::Value {
    serde_json::json!({
        "domain": sample.domain,
        "record_type": record_type_name(sample.record_type),
        "transaction_id": sample.transaction_id,
        "elapsed_ms": sample.elapsed.map(|elapsed| elapsed.as_secs_f64() * 1000.0),
        "outcome": outcome_name(sample.outcome),
    })
}

fn connect_outcome_name(outcome: ConnectProbeOutcome) -> &'static str {
    match outcome {
        ConnectProbeOutcome::Success => "success",
        ConnectProbeOutcome::Timeout => "timeout",
        ConnectProbeOutcome::Failure => "failure",
    }
}

fn tls_outcome_name(outcome: TlsProbeOutcome) -> &'static str {
    match outcome {
        TlsProbeOutcome::Success => "success",
        TlsProbeOutcome::Timeout => "timeout",
        TlsProbeOutcome::CertificateFailure => "certificate-failure",
        TlsProbeOutcome::HandshakeFailure => "handshake-failure",
    }
}

fn record_type_name(record_type: RecordType) -> &'static str {
    match record_type {
        RecordType::A => "A",
        RecordType::Aaaa => "AAAA",
    }
}

fn outcome_name(outcome: DnsSampleOutcome) -> &'static str {
    match outcome {
        DnsSampleOutcome::Success => "success",
        DnsSampleOutcome::Timeout => "timeout",
        DnsSampleOutcome::Failure => "failure",
    }
}

impl From<PlatformArg> for Platform {
    fn from(value: PlatformArg) -> Self {
        match value {
            PlatformArg::MacosStore => Platform::MacOSStore,
            PlatformArg::Ios => Platform::IOS,
            PlatformArg::AndroidPlay => Platform::AndroidPlay,
            PlatformArg::WindowsStore => Platform::WindowsStore,
            PlatformArg::LinuxFlatpak => Platform::LinuxFlatpak,
            PlatformArg::LinuxSnap => Platform::LinuxSnap,
            PlatformArg::LinuxNativePower => Platform::LinuxNativePower,
            PlatformArg::MacosPower => Platform::MacOSPower,
            PlatformArg::WindowsPower => Platform::WindowsPower,
        }
    }
}
