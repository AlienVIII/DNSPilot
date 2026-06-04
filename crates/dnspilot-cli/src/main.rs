use clap::{Parser, Subcommand, ValueEnum};
use dnspilot_core::{
    built_in_profiles, built_in_test_suites, capability_for, recommend, BenchmarkMetrics, Platform,
    RecommendationMode,
};

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
