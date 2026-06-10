use clap::{Parser, Subcommand, ValueEnum};
use dnspilot_core::{
    all_platforms, benchmark_preflight_for, built_in_profiles, built_in_test_suites, capability_for,
    connect_probe::{ConnectProbeOutcome, ConnectProbeSample, TcpConnectTarget},
    connection_path::{run_udp_connection_path_estimate, ConnectionPathConfig},
    dns_benchmark::{
        run_udp_dns_benchmark, DnsBenchmarkConfig, DnsBenchmarkSample, DnsSampleOutcome,
    },
    dns_wire::RecordType,
    recommend, recommendation_gate,
    tls_probe::{TlsProbeOutcome, TlsProbeSample},
    BenchmarkHistoryRecord, BenchmarkMetrics, BenchmarkPreflightScope, DnsProfile, DnsProtocol,
    FilteringType, MeasurementScope, Platform, RecommendationMode, SqliteStorage,
    StorageSnapshot, TestSuite, STORAGE_SCHEMA_VERSION,
};
use std::net::{IpAddr, SocketAddr};
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
    Capabilities,
    Preflight {
        #[arg(value_enum)]
        platform: PlatformArg,
        #[arg(long, value_enum, default_value_t = PreflightScopeArg::DirectResolverBenchmark)]
        scope: PreflightScopeArg,
    },
    Benchmark {
        #[arg(long)]
        resolver: Option<SocketAddr>,
        #[arg(long)]
        profile_db: Option<std::path::PathBuf>,
        #[arg(long = "domain")]
        domains: Vec<String>,
        #[arg(long)]
        suite_db: Option<std::path::PathBuf>,
        #[arg(long)]
        suite_id: Option<String>,
        #[arg(long, default_value_t = 3)]
        attempts: usize,
        #[arg(long, default_value_t = 800)]
        timeout_ms: u64,
        #[arg(long, default_value = "manual")]
        profile_id: String,
        #[arg(long, default_value_t = 53)]
        resolver_port: u16,
        #[arg(long)]
        save_db: Option<std::path::PathBuf>,
        #[arg(long)]
        history_id: Option<String>,
    },
    Compare {
        #[arg(long = "resolver")]
        resolver_specs: Vec<String>,
        #[arg(long)]
        profile_db: Option<std::path::PathBuf>,
        #[arg(long = "profile-id")]
        profile_ids: Vec<String>,
        #[arg(long, default_value_t = 53)]
        resolver_port: u16,
        #[arg(long = "domain")]
        domains: Vec<String>,
        #[arg(long)]
        suite_db: Option<std::path::PathBuf>,
        #[arg(long)]
        suite_id: Option<String>,
        #[arg(long, default_value_t = 3)]
        attempts: usize,
        #[arg(long, default_value_t = 800)]
        timeout_ms: u64,
        #[arg(long)]
        save_db: Option<std::path::PathBuf>,
        #[arg(long)]
        history_id: Option<String>,
    },
    PathEstimate {
        #[arg(long)]
        resolver: Option<SocketAddr>,
        #[arg(long)]
        profile_db: Option<std::path::PathBuf>,
        #[arg(long = "domain")]
        domains: Vec<String>,
        #[arg(long)]
        suite_db: Option<std::path::PathBuf>,
        #[arg(long)]
        suite_id: Option<String>,
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
        #[arg(long, default_value_t = 53)]
        resolver_port: u16,
    },
    PathCompare {
        #[arg(long = "resolver")]
        resolver_specs: Vec<String>,
        #[arg(long)]
        profile_db: Option<std::path::PathBuf>,
        #[arg(long = "profile-id")]
        profile_ids: Vec<String>,
        #[arg(long, default_value_t = 53)]
        resolver_port: u16,
        #[arg(long = "domain")]
        domains: Vec<String>,
        #[arg(long)]
        suite_db: Option<std::path::PathBuf>,
        #[arg(long)]
        suite_id: Option<String>,
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
        #[arg(long)]
        save_db: Option<std::path::PathBuf>,
        #[arg(long)]
        history_id: Option<String>,
    },
    StorageSmoke {
        #[arg(long)]
        db: std::path::PathBuf,
    },
    ProfileAdd {
        #[arg(long)]
        db: std::path::PathBuf,
        #[arg(long)]
        id: String,
        #[arg(long)]
        name: String,
        #[arg(long, value_enum, default_value_t = ProfileProtocolArg::Plain)]
        protocol: ProfileProtocolArg,
        #[arg(long = "ipv4")]
        ipv4_servers: Vec<String>,
        #[arg(long = "ipv6")]
        ipv6_servers: Vec<String>,
        #[arg(long)]
        doh_url: Option<String>,
        #[arg(long)]
        dot_hostname: Option<String>,
        #[arg(long, value_enum, default_value_t = FilteringTypeArg::None)]
        filtering: FilteringTypeArg,
        #[arg(long = "tag")]
        tags: Vec<String>,
    },
    ProfileList {
        #[arg(long)]
        db: std::path::PathBuf,
    },
    SuiteAdd {
        #[arg(long)]
        db: std::path::PathBuf,
        #[arg(long)]
        id: String,
        #[arg(long)]
        name: String,
        #[arg(long = "domain", required = true)]
        domains: Vec<String>,
        #[arg(long = "tag")]
        tags: Vec<String>,
    },
    SuiteList {
        #[arg(long)]
        db: std::path::PathBuf,
    },
    HistoryList {
        #[arg(long)]
        db: std::path::PathBuf,
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

#[derive(Debug, Clone, Copy, ValueEnum)]
enum ProfileProtocolArg {
    Plain,
    Doh,
    Dot,
}

#[derive(Debug, Clone, Copy, ValueEnum)]
enum PreflightScopeArg {
    DirectResolverBenchmark,
    SystemDnsValidation,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, ValueEnum)]
enum FilteringTypeArg {
    None,
    Malware,
    Family,
    Ads,
    Security,
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
        Command::Capabilities => {
            let payload = serde_json::json!({
                "capabilities": all_platforms()
                    .iter()
                    .copied()
                    .map(capability_for)
                    .collect::<Vec<_>>(),
            });
            println!(
                "{}",
                serde_json::to_string_pretty(&payload).expect("serialize capabilities")
            );
        }
        Command::Preflight { platform, scope } => {
            let preflight = benchmark_preflight_for(platform.into(), scope.into());
            println!(
                "{}",
                serde_json::to_string_pretty(&preflight).expect("serialize preflight")
            );
        }
        Command::Benchmark {
            resolver,
            profile_db,
            domains,
            suite_db,
            suite_id,
            attempts,
            timeout_ms,
            profile_id,
            resolver_port,
            save_db,
            history_id,
        } => {
            let domains = resolve_domains(domains, suite_db.as_deref(), suite_id);
            let resolver = resolve_benchmark_resolver(
                resolver,
                profile_db.as_deref(),
                &profile_id,
                resolver_port,
            );
            let domains_for_history = domains.clone();
            let config = DnsBenchmarkConfig {
                profile_id: profile_id.clone(),
                domains,
                attempts_per_record: attempts,
                timeout: Duration::from_millis(timeout_ms),
                first_transaction_id: 0x5000,
            };
            let run = run_udp_dns_benchmark(&config, resolver);
            let saved_history_id = save_db.as_ref().map(|db| {
                let id = history_id.unwrap_or_else(|| default_history_id("benchmark"));
                let gate = recommendation_gate(
                    std::slice::from_ref(&run.metrics),
                    MeasurementScope::DnsOnly,
                );
                let recommendation_profile_id = if gate.can_recommend {
                    Some(run.metrics.profile_id.clone())
                } else {
                    None
                };
                save_benchmark_history(
                    db,
                    BenchmarkHistoryRecord {
                        id: id.clone(),
                        started_at: default_history_id("started"),
                        scope: MeasurementScope::DnsOnly,
                        mode: RecommendationMode::FastestRawDns,
                        domains: domains_for_history,
                        resolver_profile_ids: vec![profile_id],
                        metrics: vec![run.metrics.clone()],
                        gate,
                        recommendation_profile_id,
                        notes: vec!["Saved by benchmark CLI.".into()],
                    },
                );
                id
            });
            let payload = serde_json::json!({
                "metrics": run.metrics,
                "samples": run.samples.iter().map(sample_to_json).collect::<Vec<_>>(),
                "saved_history_id": saved_history_id,
                "warning": "Live DNS results estimate resolver behavior on this network; they do not prove full browser or app speed.",
            });
            println!(
                "{}",
                serde_json::to_string_pretty(&payload).expect("serialize benchmark")
            );
        }
        Command::Compare {
            resolver_specs,
            profile_db,
            profile_ids,
            resolver_port,
            domains,
            suite_db,
            suite_id,
            attempts,
            timeout_ms,
            save_db,
            history_id,
        } => {
            if attempts == 0 {
                eprintln!("--attempts must be greater than 0");
                std::process::exit(2);
            }

            let domains = resolve_domains(domains, suite_db.as_deref(), suite_id);
            let domains_for_history = domains.clone();
            let mut resolver_inputs = Vec::new();
            for resolver_spec in &resolver_specs {
                let parsed = parse_resolver_spec(resolver_spec).unwrap_or_else(|message| {
                    eprintln!("{message}");
                    std::process::exit(2);
                });
                resolver_inputs.push(parsed);
            }
            resolver_inputs.extend(resolve_profile_resolvers(
                profile_db.as_deref(),
                profile_ids,
                resolver_port,
            ));
            if resolver_inputs.is_empty() {
                eprintln!("--resolver or --profile-id is required");
                std::process::exit(2);
            }

            let resolver_count = resolver_inputs.len();
            let mut metrics = Vec::new();
            let mut runs = Vec::new();
            let mut seen_profile_ids = std::collections::BTreeSet::new();
            let mut resolver_profile_ids = Vec::new();

            for (index, (profile_id, resolver)) in resolver_inputs.into_iter().enumerate() {
                if !seen_profile_ids.insert(profile_id.clone()) {
                    eprintln!("duplicate --resolver id '{profile_id}'");
                    std::process::exit(2);
                }
                resolver_profile_ids.push(profile_id.clone());
                let config = DnsBenchmarkConfig {
                    profile_id: profile_id.clone(),
                    domains: domains.clone(),
                    attempts_per_record: attempts,
                    timeout: Duration::from_millis(timeout_ms),
                    first_transaction_id: 0x9000_u16
                        .wrapping_add((index as u16).wrapping_mul(0x0100)),
                };
                let run = run_udp_dns_benchmark(&config, resolver);
                metrics.push(run.metrics.clone());
                runs.push(serde_json::json!({
                    "profile_id": profile_id,
                    "resolver": resolver.to_string(),
                    "metrics": run.metrics,
                    "samples": run.samples.iter().map(sample_to_json).collect::<Vec<_>>(),
                }));
            }

            let gate = recommendation_gate(&metrics, MeasurementScope::DnsOnly);
            let recommendation = if gate.can_recommend {
                Some(
                    recommend(&metrics, None, RecommendationMode::FastestRawDns)
                        .expect("compare requires at least one resolver"),
                )
            } else {
                None
            };
            let saved_history_id = save_db.as_ref().map(|db| {
                let id = history_id.unwrap_or_else(|| default_history_id("compare"));
                save_benchmark_history(
                    db,
                    BenchmarkHistoryRecord {
                        id: id.clone(),
                        started_at: default_history_id("started"),
                        scope: MeasurementScope::DnsOnly,
                        mode: RecommendationMode::FastestRawDns,
                        domains: domains_for_history,
                        resolver_profile_ids,
                        metrics: metrics.clone(),
                        gate: gate.clone(),
                        recommendation_profile_id: recommendation
                            .as_ref()
                            .map(|item| item.profile_id.clone()),
                        notes: vec!["Saved by compare CLI.".into()],
                    },
                );
                id
            });
            let payload = serde_json::json!({
                "summary": {
                    "measurement_scope": "dns-only",
                    "mode": "fastest-raw-dns",
                    "health": gate.health,
                    "primary_issue": gate.primary_issue,
                    "can_recommend": gate.can_recommend,
                    "safety_notes": gate.notes,
                    "resolver_count": resolver_count,
                    "domain_count": domains.len(),
                    "attempts_per_record": attempts,
                    "timeout_ms": timeout_ms,
                    "recommended_profile_id": recommendation.as_ref().map(|item| item.profile_id.clone()),
                },
                "runs": runs,
                "recommendation": recommendation,
                "saved_history_id": saved_history_id,
                "warning": "DNS-only comparison estimates resolver lookup latency and reliability; it does not include TCP, TLS, HTTP, QUIC, browser cache, VPN, MDM, captive portal, or app-specific behavior.",
            });
            println!(
                "{}",
                serde_json::to_string_pretty(&payload).expect("serialize compare")
            );
        }
        Command::PathEstimate {
            resolver,
            profile_db,
            domains,
            suite_db,
            suite_id,
            attempts,
            dns_timeout_ms,
            connect_timeout_ms,
            connect_port,
            max_connect_targets_per_domain,
            tls_handshake_timeout_ms,
            profile_id,
            resolver_port,
        } => {
            let domains = resolve_domains(domains, suite_db.as_deref(), suite_id);
            let resolver = resolve_benchmark_resolver(
                resolver,
                profile_db.as_deref(),
                &profile_id,
                resolver_port,
            );
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
        Command::PathCompare {
            resolver_specs,
            profile_db,
            profile_ids,
            resolver_port,
            domains,
            suite_db,
            suite_id,
            attempts,
            dns_timeout_ms,
            connect_timeout_ms,
            connect_port,
            max_connect_targets_per_domain,
            tls_handshake_timeout_ms,
            save_db,
            history_id,
        } => {
            if attempts == 0 {
                eprintln!("--attempts must be greater than 0");
                std::process::exit(2);
            }

            let domains = resolve_domains(domains, suite_db.as_deref(), suite_id);
            let domains_for_history = domains.clone();
            let mut resolver_inputs = Vec::new();
            for resolver_spec in &resolver_specs {
                let parsed = parse_resolver_spec(resolver_spec).unwrap_or_else(|message| {
                    eprintln!("{message}");
                    std::process::exit(2);
                });
                resolver_inputs.push(parsed);
            }
            resolver_inputs.extend(resolve_profile_resolvers(
                profile_db.as_deref(),
                profile_ids,
                resolver_port,
            ));
            if resolver_inputs.is_empty() {
                eprintln!("--resolver or --profile-id is required");
                std::process::exit(2);
            }

            let resolver_count = resolver_inputs.len();
            let tls_enabled = tls_handshake_timeout_ms.is_some();
            let mut metrics = Vec::new();
            let mut runs = Vec::new();
            let mut run_json = Vec::new();
            let mut seen_profile_ids = std::collections::BTreeSet::new();
            let mut resolver_profile_ids = Vec::new();

            for (index, (profile_id, resolver)) in resolver_inputs.into_iter().enumerate() {
                if !seen_profile_ids.insert(profile_id.clone()) {
                    eprintln!("duplicate --resolver id '{profile_id}'");
                    std::process::exit(2);
                }
                resolver_profile_ids.push(profile_id.clone());

                let config = ConnectionPathConfig {
                    profile_id: profile_id.clone(),
                    domains: domains.clone(),
                    attempts_per_record: attempts,
                    dns_timeout: Duration::from_millis(dns_timeout_ms),
                    connect_timeout: Duration::from_millis(connect_timeout_ms),
                    first_transaction_id: 0xa000_u16
                        .wrapping_add((index as u16).wrapping_mul(0x0100)),
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
                let tls_sample_count = tls_samples.len();
                metrics.push(run.metrics.clone());
                run_json.push(serde_json::json!({
                    "profile_id": profile_id,
                    "resolver": resolver.to_string(),
                    "summary": path_run_summary_to_json(&run, tls_enabled, tls_sample_count),
                    "metrics": run.metrics.clone(),
                    "dns_samples": run.dns.samples.iter().map(sample_to_json).collect::<Vec<_>>(),
                    "connect_samples": run.connect.samples.iter().map(connect_sample_to_json).collect::<Vec<_>>(),
                    "tls_samples": tls_samples,
                    "connect_targets": run.connect_targets.iter().map(connect_target_to_json).collect::<Vec<_>>(),
                    "caveats": run.caveats.clone(),
                }));
                runs.push(run);
            }

            let scope = if tls_enabled {
                MeasurementScope::DnsTcpTls
            } else {
                MeasurementScope::DnsTcp
            };
            let gate = recommendation_gate(&metrics, scope);
            let recommendation = if gate.can_recommend {
                Some(
                    recommend(&metrics, None, RecommendationMode::BestOverall)
                        .expect("path-compare requires at least one resolver"),
                )
            } else {
                None
            };
            let saved_history_id = save_db.as_ref().map(|db| {
                let id = history_id.unwrap_or_else(|| default_history_id("path-compare"));
                save_benchmark_history(
                    db,
                    BenchmarkHistoryRecord {
                        id: id.clone(),
                        started_at: default_history_id("started"),
                        scope,
                        mode: RecommendationMode::BestOverall,
                        domains: domains_for_history,
                        resolver_profile_ids,
                        metrics: metrics.clone(),
                        gate: gate.clone(),
                        recommendation_profile_id: recommendation
                            .as_ref()
                            .map(|item| item.profile_id.clone()),
                        notes: vec!["Saved by path-compare CLI.".into()],
                    },
                );
                id
            });
            let warning = if tls_enabled {
                "Path comparison estimates DNS, TCP connect, and TLS/SNI handshake timing only; it does not include HTTP, QUIC, browser cache, VPN, MDM, captive portal, or app-specific behavior."
            } else {
                "Path comparison estimates DNS plus TCP connect timing only; it does not include TLS, HTTP, QUIC, browser cache, VPN, MDM, captive portal, or app-specific behavior."
            };
            let payload = serde_json::json!({
                "summary": {
                    "measurement_scope": if tls_enabled { "dns-tcp-tls" } else { "dns-tcp" },
                    "mode": "best-overall",
                    "health": gate.health,
                    "primary_issue": gate.primary_issue,
                    "can_recommend": gate.can_recommend,
                    "safety_notes": gate.notes,
                    "tls_enabled": tls_enabled,
                    "trust_store": if tls_enabled {
                        serde_json::Value::String("mozilla-webpki-roots".into())
                    } else {
                        serde_json::Value::Null
                    },
                    "resolver_count": resolver_count,
                    "domain_count": domains.len(),
                    "attempts_per_record": attempts,
                    "dns_timeout_ms": dns_timeout_ms,
                    "connect_timeout_ms": connect_timeout_ms,
                    "tls_handshake_timeout_ms": tls_handshake_timeout_ms,
                    "connect_port": connect_port,
                    "max_connect_targets_per_domain": max_connect_targets_per_domain,
                    "tls_sample_count": runs.iter().map(|run| run.tls.as_ref().map(|tls| tls.samples.len()).unwrap_or(0)).sum::<usize>(),
                    "recommended_profile_id": recommendation.as_ref().map(|item| item.profile_id.clone()),
                },
                "runs": run_json,
                "recommendation": recommendation,
                "saved_history_id": saved_history_id,
                "warning": warning,
            });
            println!(
                "{}",
                serde_json::to_string_pretty(&payload).expect("serialize path compare")
            );
        }
        Command::StorageSmoke { db } => {
            let storage = SqliteStorage::open(&db).unwrap_or_else(|error| {
                eprintln!("{error}");
                std::process::exit(2);
            });
            let snapshot = builtin_storage_snapshot();
            storage.save_snapshot(&snapshot).unwrap_or_else(|error| {
                eprintln!("{error}");
                std::process::exit(2);
            });
            let loaded = storage.load_snapshot().unwrap_or_else(|error| {
                eprintln!("{error}");
                std::process::exit(2);
            });
            let payload = serde_json::json!({
                "db": db.to_string_lossy(),
                "schema_version": loaded.schema_version,
                "profile_count": loaded.profiles.len(),
                "test_suite_count": loaded.test_suites.len(),
                "benchmark_history_count": loaded.benchmark_history.len(),
            });
            println!(
                "{}",
                serde_json::to_string_pretty(&payload).expect("serialize storage smoke")
            );
        }
        Command::ProfileAdd {
            db,
            id,
            name,
            protocol,
            ipv4_servers,
            ipv6_servers,
            doh_url,
            dot_hostname,
            filtering,
            tags,
        } => {
            let storage = SqliteStorage::open(&db).unwrap_or_else(|error| {
                eprintln!("{error}");
                std::process::exit(2);
            });
            let mut snapshot = load_snapshot_or_builtin(&storage);
            let profile = DnsProfile {
                id: id.clone(),
                name: name.clone(),
                description: "Custom DNS profile.".into(),
                ipv4_servers,
                ipv6_servers,
                protocol: protocol.into(),
                doh_url,
                dot_hostname,
                tags,
                use_case: "custom".into(),
                filtering_type: filtering.into(),
                security_notes: if filtering == FilteringTypeArg::None {
                    Vec::new()
                } else {
                    vec!["Filtered DNS may intentionally block some domains.".into()]
                },
                provider_metadata: std::collections::BTreeMap::new(),
                created_at: None,
                updated_at: None,
            };
            profile.validate().unwrap_or_else(|error| {
                eprintln!("{error}");
                std::process::exit(2);
            });
            snapshot.profiles.push(profile);
            storage.save_snapshot(&snapshot).unwrap_or_else(|error| {
                eprintln!("{error}");
                std::process::exit(2);
            });
            let payload = serde_json::json!({
                "db": db.to_string_lossy(),
                "profile_id": id,
                "profile_count": snapshot.profiles.len(),
            });
            println!(
                "{}",
                serde_json::to_string_pretty(&payload).expect("serialize profile add")
            );
        }
        Command::ProfileList { db } => {
            let storage = SqliteStorage::open(&db).unwrap_or_else(|error| {
                eprintln!("{error}");
                std::process::exit(2);
            });
            let snapshot = load_snapshot_or_builtin(&storage);
            let payload = serde_json::json!({
                "db": db.to_string_lossy(),
                "schema_version": snapshot.schema_version,
                "profile_count": snapshot.profiles.len(),
                "profiles": snapshot.profiles,
            });
            println!(
                "{}",
                serde_json::to_string_pretty(&payload).expect("serialize profile list")
            );
        }
        Command::SuiteAdd {
            db,
            id,
            name,
            domains,
            tags,
        } => {
            let storage = SqliteStorage::open(&db).unwrap_or_else(|error| {
                eprintln!("{error}");
                std::process::exit(2);
            });
            let mut snapshot = load_snapshot_or_builtin(&storage);
            snapshot.test_suites.push(TestSuite {
                id: id.clone(),
                name: name.clone(),
                description: "Custom domain test suite.".into(),
                domains,
                tags,
            });
            storage.save_snapshot(&snapshot).unwrap_or_else(|error| {
                eprintln!("{error}");
                std::process::exit(2);
            });
            let payload = serde_json::json!({
                "db": db.to_string_lossy(),
                "test_suite_id": id,
                "test_suite_count": snapshot.test_suites.len(),
            });
            println!(
                "{}",
                serde_json::to_string_pretty(&payload).expect("serialize suite add")
            );
        }
        Command::SuiteList { db } => {
            let storage = SqliteStorage::open(&db).unwrap_or_else(|error| {
                eprintln!("{error}");
                std::process::exit(2);
            });
            let snapshot = load_snapshot_or_builtin(&storage);
            let payload = serde_json::json!({
                "db": db.to_string_lossy(),
                "schema_version": snapshot.schema_version,
                "test_suite_count": snapshot.test_suites.len(),
                "test_suites": snapshot.test_suites,
            });
            println!(
                "{}",
                serde_json::to_string_pretty(&payload).expect("serialize suite list")
            );
        }
        Command::HistoryList { db } => {
            let storage = SqliteStorage::open(&db).unwrap_or_else(|error| {
                eprintln!("{error}");
                std::process::exit(2);
            });
            let snapshot = load_snapshot_or_builtin(&storage);
            let payload = serde_json::json!({
                "db": db.to_string_lossy(),
                "schema_version": snapshot.schema_version,
                "benchmark_history_count": snapshot.benchmark_history.len(),
                "benchmark_history": snapshot.benchmark_history,
            });
            println!(
                "{}",
                serde_json::to_string_pretty(&payload).expect("serialize history list")
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

fn builtin_storage_snapshot() -> StorageSnapshot {
    StorageSnapshot {
        schema_version: STORAGE_SCHEMA_VERSION,
        profiles: built_in_profiles(),
        test_suites: built_in_test_suites(),
        benchmark_history: Vec::new(),
    }
}

fn load_snapshot_or_builtin(storage: &SqliteStorage) -> StorageSnapshot {
    match storage.load_snapshot() {
        Ok(snapshot) => snapshot,
        Err(error) if error.to_string().contains("Query returned no rows") => {
            builtin_storage_snapshot()
        }
        Err(error) => {
            eprintln!("{error}");
            std::process::exit(2);
        }
    }
}

fn resolve_domains(
    domains: Vec<String>,
    suite_db: Option<&std::path::Path>,
    suite_id: Option<String>,
) -> Vec<String> {
    let mut resolved = Vec::new();
    if let Some(suite_id) = suite_id {
        let suite_db = suite_db.unwrap_or_else(|| {
            eprintln!("--suite-db is required with --suite-id");
            std::process::exit(2);
        });
        let storage = SqliteStorage::open(suite_db).unwrap_or_else(|error| {
            eprintln!("{error}");
            std::process::exit(2);
        });
        let snapshot = load_snapshot_or_builtin(&storage);
        let suite = snapshot
            .test_suites
            .iter()
            .find(|suite| suite.id == suite_id)
            .unwrap_or_else(|| {
                eprintln!("test suite '{suite_id}' not found");
                std::process::exit(2);
            });
        resolved.extend(suite.domains.clone());
    }
    resolved.extend(domains);
    if resolved.is_empty() {
        eprintln!("--domain or --suite-id is required");
        std::process::exit(2);
    }
    resolved
}

fn resolve_benchmark_resolver(
    resolver: Option<SocketAddr>,
    profile_db: Option<&std::path::Path>,
    profile_id: &str,
    resolver_port: u16,
) -> SocketAddr {
    if let Some(resolver) = resolver {
        return resolver;
    }

    let profile_db = profile_db.unwrap_or_else(|| {
        eprintln!("--resolver or --profile-db is required");
        std::process::exit(2);
    });
    let storage = SqliteStorage::open(profile_db).unwrap_or_else(|error| {
        eprintln!("{error}");
        std::process::exit(2);
    });
    let snapshot = load_snapshot_or_builtin(&storage);
    resolve_plain_profile_address(&snapshot.profiles, profile_id, resolver_port)
}

fn resolve_profile_resolvers(
    profile_db: Option<&std::path::Path>,
    profile_ids: Vec<String>,
    resolver_port: u16,
) -> Vec<(String, SocketAddr)> {
    if profile_ids.is_empty() {
        return Vec::new();
    }

    let profile_db = profile_db.unwrap_or_else(|| {
        eprintln!("--profile-db is required with --profile-id");
        std::process::exit(2);
    });
    let storage = SqliteStorage::open(profile_db).unwrap_or_else(|error| {
        eprintln!("{error}");
        std::process::exit(2);
    });
    let snapshot = load_snapshot_or_builtin(&storage);

    profile_ids
        .into_iter()
        .map(|profile_id| {
            let resolver =
                resolve_plain_profile_address(&snapshot.profiles, &profile_id, resolver_port);
            (profile_id, resolver)
        })
        .collect()
}

fn resolve_plain_profile_address(
    profiles: &[DnsProfile],
    profile_id: &str,
    resolver_port: u16,
) -> SocketAddr {
    let profile = profiles
        .iter()
        .find(|profile| profile.id == profile_id)
        .unwrap_or_else(|| {
            eprintln!("DNS profile '{profile_id}' not found");
            std::process::exit(2);
        });
    if profile.protocol != DnsProtocol::Plain {
        eprintln!("DNS profile '{profile_id}' is not plain DNS");
        std::process::exit(2);
    }

    let server = profile
        .ipv4_servers
        .iter()
        .chain(profile.ipv6_servers.iter())
        .next()
        .unwrap_or_else(|| {
            eprintln!("DNS profile '{profile_id}' has no resolver addresses");
            std::process::exit(2);
        });
    let ip = server.parse::<IpAddr>().unwrap_or_else(|error| {
        eprintln!("invalid DNS profile resolver '{server}': {error}");
        std::process::exit(2);
    });

    SocketAddr::new(ip, resolver_port)
}

fn save_benchmark_history(db: &std::path::Path, record: BenchmarkHistoryRecord) {
    let storage = SqliteStorage::open(db).unwrap_or_else(|error| {
        eprintln!("{error}");
        std::process::exit(2);
    });
    let mut snapshot = load_snapshot_or_builtin(&storage);
    snapshot.benchmark_history.push(record);
    storage.save_snapshot(&snapshot).unwrap_or_else(|error| {
        eprintln!("{error}");
        std::process::exit(2);
    });
}

fn default_history_id(prefix: &str) -> String {
    let seconds = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|duration| duration.as_secs())
        .unwrap_or(0);
    format!("{prefix}-{seconds}")
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

fn path_run_summary_to_json(
    run: &dnspilot_core::connection_path::ConnectionPathRun,
    tls_enabled: bool,
    tls_sample_count: usize,
) -> serde_json::Value {
    let (health, primary_issue) = path_health_summary(run);
    serde_json::json!({
        "measurement_scope": if tls_enabled { "dns-tcp-tls" } else { "dns-tcp" },
        "health": health,
        "primary_issue": primary_issue,
        "tls_enabled": tls_enabled,
        "trust_store": if tls_enabled {
            serde_json::Value::String("mozilla-webpki-roots".into())
        } else {
            serde_json::Value::Null
        },
        "domain_count": run.dns.samples.iter().map(|sample| &sample.domain).collect::<std::collections::BTreeSet<_>>().len(),
        "dns_sample_count": run.dns.samples.len(),
        "connect_target_count": run.connect_targets.len(),
        "connect_sample_count": run.connect.samples.len(),
        "tls_sample_count": tls_sample_count,
        "caveat_count": run.caveats.len(),
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

fn parse_resolver_spec(spec: &str) -> Result<(String, SocketAddr), String> {
    let Some((profile_id, resolver)) = spec.split_once('=') else {
        return Err(format!(
            "invalid --resolver '{spec}'; expected id=host:port, for IPv6 use id=[addr]:53"
        ));
    };

    let profile_id = profile_id.trim();
    if profile_id.is_empty() {
        return Err(format!(
            "invalid --resolver '{spec}'; resolver id cannot be empty"
        ));
    }

    let resolver = resolver.trim().parse::<SocketAddr>().map_err(|error| {
        format!("invalid --resolver '{spec}'; resolver address must be host:port ({error})")
    })?;

    Ok((profile_id.into(), resolver))
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

impl From<PreflightScopeArg> for BenchmarkPreflightScope {
    fn from(value: PreflightScopeArg) -> Self {
        match value {
            PreflightScopeArg::DirectResolverBenchmark => {
                BenchmarkPreflightScope::DirectResolverBenchmark
            }
            PreflightScopeArg::SystemDnsValidation => BenchmarkPreflightScope::SystemDnsValidation,
        }
    }
}

impl From<ProfileProtocolArg> for DnsProtocol {
    fn from(value: ProfileProtocolArg) -> Self {
        match value {
            ProfileProtocolArg::Plain => DnsProtocol::Plain,
            ProfileProtocolArg::Doh => DnsProtocol::Doh,
            ProfileProtocolArg::Dot => DnsProtocol::Dot,
        }
    }
}

impl From<FilteringTypeArg> for FilteringType {
    fn from(value: FilteringTypeArg) -> Self {
        match value {
            FilteringTypeArg::None => FilteringType::None,
            FilteringTypeArg::Malware => FilteringType::Malware,
            FilteringTypeArg::Family => FilteringType::Family,
            FilteringTypeArg::Ads => FilteringType::Ads,
            FilteringTypeArg::Security => FilteringType::Security,
        }
    }
}
