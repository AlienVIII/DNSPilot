use clap::{Parser, Subcommand, ValueEnum};
use dnspilot_core::{
    built_in_profiles,
    built_in_test_suites,
    capability_for,
    dns_benchmark::{run_udp_dns_benchmark, DnsBenchmarkConfig, DnsBenchmarkSample, DnsSampleOutcome},
    dns_wire::RecordType,
    recommend,
    BenchmarkMetrics,
    Platform,
    RecommendationMode,
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
            println!("{}", serde_json::to_string_pretty(&payload).expect("serialize catalog"));
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
            let recommendation =
                recommend(&[current.clone(), quad9], Some(&current), RecommendationMode::BestOverall)
                    .expect("sample recommendation");
            println!(
                "{}",
                serde_json::to_string_pretty(&recommendation).expect("serialize recommendation")
            );
        }
    }
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
