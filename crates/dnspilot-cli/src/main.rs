use clap::{Parser, Subcommand, ValueEnum};
use dnspilot_core::{
    apply_plan_payload_for, apply_prompt_policy_payload_for, benchmark_preflight_payload_for,
    built_in_profiles, built_in_test_suites, capability_for, capability_matrix_payload,
    catalog_payload,
    connect_probe::{ConnectProbeOutcome, ConnectProbeSample, TcpConnectTarget},
    connection_path::{run_udp_connection_path_estimate, ConnectionPathConfig},
    dns_benchmark::{
        run_udp_dns_benchmark, DnsBenchmarkConfig, DnsBenchmarkSample, DnsRecordFamily,
        DnsSampleOutcome,
    },
    dns_wire::{validate_domain_name, RecordType},
    recommend, recommendation_gate,
    system_dns::run_system_dns_benchmark,
    tls_probe::{TlsProbeOutcome, TlsProbeSample},
    BenchmarkHistoryRecord, BenchmarkMetrics, BenchmarkPreflightScope, Confidence, DnsProfile,
    DnsProtocol, FilteringType, MeasurementScope, NetworkEnvironment, Platform, Recommendation,
    RecommendationDecision, RecommendationGate, RecommendationHealth, RecommendationIssue,
    RecommendationMode, SqliteStorage, StorageSnapshot, TestSuite, STORAGE_SCHEMA_VERSION,
};
use std::net::{IpAddr, SocketAddr};
use std::time::{Duration, Instant};

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
    ApplyPolicy {
        #[arg(value_enum)]
        platform: PlatformArg,
        #[arg(long)]
        vpn_active: bool,
        #[arg(long)]
        mdm_profile_active: bool,
        #[arg(long)]
        corporate_dns_detected: bool,
        #[arg(long)]
        captive_portal_detected: bool,
    },
    ApplyPlan {
        #[arg(value_enum)]
        platform: PlatformArg,
        #[arg(long)]
        profile_db: Option<std::path::PathBuf>,
        #[arg(long)]
        profile_id: Option<String>,
        #[arg(long)]
        tested_resolver: Option<String>,
        #[arg(long, value_enum, default_value_t = ConfidenceArg::High)]
        confidence: ConfidenceArg,
        #[arg(long, value_enum, default_value_t = GateHealthArg::Healthy)]
        gate_health: GateHealthArg,
        #[arg(long)]
        vpn_active: bool,
        #[arg(long)]
        mdm_profile_active: bool,
        #[arg(long)]
        corporate_dns_detected: bool,
        #[arg(long)]
        captive_portal_detected: bool,
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
        #[arg(long, value_enum, default_value_t = IpFamilyArg::Both)]
        ip_family: IpFamilyArg,
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
    SystemBenchmark {
        #[arg(long, value_enum, default_value_t = PlatformArg::MacosStore)]
        platform: PlatformArg,
        #[arg(long = "domain")]
        domains: Vec<String>,
        #[arg(long)]
        suite_db: Option<std::path::PathBuf>,
        #[arg(long)]
        suite_id: Option<String>,
        #[arg(long, default_value_t = 3)]
        attempts: usize,
        #[arg(long, value_enum, default_value_t = IpFamilyArg::Both)]
        ip_family: IpFamilyArg,
        #[arg(long, default_value_t = 800)]
        timeout_ms: u64,
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
        #[arg(long, value_enum, default_value_t = IpFamilyArg::Both)]
        ip_family: IpFamilyArg,
        #[arg(long, default_value_t = 800)]
        timeout_ms: u64,
        #[arg(long)]
        save_db: Option<std::path::PathBuf>,
        #[arg(long)]
        history_id: Option<String>,
        #[arg(long)]
        progress_jsonl: bool,
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
        #[arg(long, value_enum, default_value_t = IpFamilyArg::Both)]
        ip_family: IpFamilyArg,
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
        #[arg(long, value_enum, default_value_t = IpFamilyArg::Both)]
        ip_family: IpFamilyArg,
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
        #[arg(long)]
        progress_jsonl: bool,
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
    ProfileUpdate {
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
    ProfileDelete {
        #[arg(long)]
        db: std::path::PathBuf,
        #[arg(long)]
        id: String,
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
    SuiteUpdate {
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
    SuiteDelete {
        #[arg(long)]
        db: std::path::PathBuf,
        #[arg(long)]
        id: String,
    },
    SuiteList {
        #[arg(long)]
        db: std::path::PathBuf,
    },
    HistoryList {
        #[arg(long)]
        db: std::path::PathBuf,
    },
    HistoryDelete {
        #[arg(long)]
        db: std::path::PathBuf,
        #[arg(long)]
        id: String,
    },
    HistoryClear {
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

#[derive(Debug, Clone, Copy, ValueEnum)]
enum ConfidenceArg {
    High,
    Medium,
    Low,
    Inconclusive,
}

#[derive(Debug, Clone, Copy, ValueEnum)]
enum GateHealthArg {
    Healthy,
    Degraded,
    Failed,
    Inconclusive,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, ValueEnum)]
enum FilteringTypeArg {
    None,
    Malware,
    Family,
    Ads,
    Security,
}

#[derive(Debug, Clone, Copy, ValueEnum)]
enum IpFamilyArg {
    Both,
    Ipv4Only,
    Ipv6Only,
}

fn main() {
    let cli = Cli::parse();
    match cli.command {
        Command::Catalog => {
            println!(
                "{}",
                serde_json::to_string_pretty(&catalog_payload()).expect("serialize catalog")
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
            println!(
                "{}",
                serde_json::to_string_pretty(&capability_matrix_payload())
                    .expect("serialize capabilities")
            );
        }
        Command::Preflight { platform, scope } => {
            let preflight = benchmark_preflight_payload_for(platform.into(), scope.into());
            println!(
                "{}",
                serde_json::to_string_pretty(&preflight).expect("serialize preflight")
            );
        }
        Command::ApplyPolicy {
            platform,
            vpn_active,
            mdm_profile_active,
            corporate_dns_detected,
            captive_portal_detected,
        } => {
            let environment = NetworkEnvironment {
                vpn_active,
                mdm_profile_active,
                corporate_dns_detected,
                captive_portal_detected,
            };
            let policy = apply_prompt_policy_payload_for(platform.into(), &environment);
            println!(
                "{}",
                serde_json::to_string_pretty(&policy).expect("serialize apply policy")
            );
        }
        Command::ApplyPlan {
            platform,
            profile_db,
            profile_id,
            tested_resolver,
            confidence,
            gate_health,
            vpn_active,
            mdm_profile_active,
            corporate_dns_detected,
            captive_portal_detected,
        } => {
            let environment = NetworkEnvironment {
                vpn_active,
                mdm_profile_active,
                corporate_dns_detected,
                captive_portal_detected,
            };
            let profiles = resolve_apply_plan_profiles(profile_db.as_deref());
            let gate = apply_plan_gate(gate_health);
            let recommendation = profile_id.map(|profile_id| Recommendation {
                decision: RecommendationDecision::ApplyProfile(profile_id.clone()),
                profile_id,
                score: 1.0,
                confidence: confidence.into(),
                reasons: vec!["CLI apply-plan recommendation input.".into()],
                caveats: Vec::new(),
            });
            let plan = apply_plan_payload_for(
                platform.into(),
                &environment,
                &gate,
                recommendation.as_ref(),
                tested_resolver.as_deref(),
                &profiles,
            );
            println!(
                "{}",
                serde_json::to_string_pretty(&plan).expect("serialize apply plan")
            );
        }
        Command::Benchmark {
            resolver,
            profile_db,
            domains,
            suite_db,
            suite_id,
            attempts,
            ip_family,
            timeout_ms,
            profile_id,
            resolver_port,
            save_db,
            history_id,
        } => {
            reject_zero_usize("--attempts", attempts);
            reject_zero_u64("--timeout-ms", timeout_ms);
            reject_zero_optional_socket_port("--resolver", resolver);
            reject_zero_u16("--resolver-port", resolver_port);

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
                record_family: ip_family.into(),
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
                "ip_family": ip_family_name(ip_family),
                "saved_history_id": saved_history_id,
                "warning": "Live DNS results estimate resolver behavior on this network; they do not prove full browser or app speed.",
            });
            println!(
                "{}",
                serde_json::to_string_pretty(&payload).expect("serialize benchmark")
            );
        }
        Command::SystemBenchmark {
            platform,
            domains,
            suite_db,
            suite_id,
            attempts,
            ip_family,
            timeout_ms,
        } => {
            reject_zero_usize("--attempts", attempts);
            reject_zero_u64("--timeout-ms", timeout_ms);

            let domains = resolve_domains(domains, suite_db.as_deref(), suite_id);
            let config = DnsBenchmarkConfig {
                profile_id: "system-dns".into(),
                domains,
                attempts_per_record: attempts,
                timeout: Duration::from_millis(timeout_ms),
                first_transaction_id: 0x6000,
                record_family: ip_family.into(),
            };
            let run = run_system_dns_benchmark(&config);
            let preflight = benchmark_preflight_payload_for(
                platform.into(),
                BenchmarkPreflightScope::SystemDnsValidation,
            );
            let payload = serde_json::json!({
                "scope": "system-dns-validation",
                "preflight": preflight.preflight,
                "metrics": run.metrics,
                "samples": run.samples.iter().map(sample_to_json).collect::<Vec<_>>(),
                "ip_family": ip_family_name(ip_family),
                "warning": "System DNS validation measures the OS resolver path after DNS changes; flush cache first, and still expect browser Secure DNS, VPN, MDM, captive portal, and app caches to distort results.",
            });
            println!(
                "{}",
                serde_json::to_string_pretty(&payload).expect("serialize system benchmark")
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
            ip_family,
            timeout_ms,
            save_db,
            history_id,
            progress_jsonl,
        } => {
            reject_zero_usize("--attempts", attempts);
            reject_zero_u64("--timeout-ms", timeout_ms);
            reject_zero_u16("--resolver-port", resolver_port);

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
                emit_resolver_progress(
                    progress_jsonl,
                    "resolver_started",
                    MeasurementScope::DnsOnly,
                    &profile_id,
                    resolver,
                    index + 1,
                    resolver_count,
                    None,
                    None,
                );
                let resolver_started_at = Instant::now();
                let config = DnsBenchmarkConfig {
                    profile_id: profile_id.clone(),
                    domains: domains.clone(),
                    attempts_per_record: attempts,
                    timeout: Duration::from_millis(timeout_ms),
                    first_transaction_id: 0x9000_u16
                        .wrapping_add((index as u16).wrapping_mul(0x0100)),
                    record_family: ip_family.into(),
                };
                let run = run_udp_dns_benchmark(&config, resolver);
                emit_resolver_progress(
                    progress_jsonl,
                    "resolver_finished",
                    MeasurementScope::DnsOnly,
                    &profile_id,
                    resolver,
                    index + 1,
                    resolver_count,
                    Some(&run.metrics),
                    Some(resolver_started_at.elapsed()),
                );
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
                    "ip_family": ip_family_name(ip_family),
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
            ip_family,
            dns_timeout_ms,
            connect_timeout_ms,
            connect_port,
            max_connect_targets_per_domain,
            tls_handshake_timeout_ms,
            profile_id,
            resolver_port,
        } => {
            reject_zero_usize("--attempts", attempts);
            reject_zero_u64("--dns-timeout-ms", dns_timeout_ms);
            reject_zero_u64("--connect-timeout-ms", connect_timeout_ms);
            reject_zero_optional_u64("--tls-handshake-timeout-ms", tls_handshake_timeout_ms);
            reject_zero_usize(
                "--max-connect-targets-per-domain",
                max_connect_targets_per_domain,
            );
            reject_zero_optional_socket_port("--resolver", resolver);
            reject_zero_u16("--resolver-port", resolver_port);
            reject_zero_u16("--connect-port", connect_port);

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
                record_family: ip_family.into(),
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
                "ip_family": ip_family_name(ip_family),
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
            ip_family,
            dns_timeout_ms,
            connect_timeout_ms,
            connect_port,
            max_connect_targets_per_domain,
            tls_handshake_timeout_ms,
            save_db,
            history_id,
            progress_jsonl,
        } => {
            reject_zero_usize("--attempts", attempts);
            reject_zero_u64("--dns-timeout-ms", dns_timeout_ms);
            reject_zero_u64("--connect-timeout-ms", connect_timeout_ms);
            reject_zero_optional_u64("--tls-handshake-timeout-ms", tls_handshake_timeout_ms);
            reject_zero_usize(
                "--max-connect-targets-per-domain",
                max_connect_targets_per_domain,
            );
            reject_zero_u16("--resolver-port", resolver_port);
            reject_zero_u16("--connect-port", connect_port);

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
                let scope = if tls_enabled {
                    MeasurementScope::DnsTcpTls
                } else {
                    MeasurementScope::DnsTcp
                };
                emit_resolver_progress(
                    progress_jsonl,
                    "resolver_started",
                    scope,
                    &profile_id,
                    resolver,
                    index + 1,
                    resolver_count,
                    None,
                    None,
                );

                let resolver_started_at = Instant::now();
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
                    record_family: ip_family.into(),
                };
                let run = run_udp_connection_path_estimate(&config, resolver);
                emit_resolver_progress(
                    progress_jsonl,
                    "resolver_finished",
                    scope,
                    &profile_id,
                    resolver,
                    index + 1,
                    resolver_count,
                    Some(&run.metrics),
                    Some(resolver_started_at.elapsed()),
                );
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
                    "ip_family": ip_family_name(ip_family),
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
            if snapshot.profiles.iter().any(|profile| profile.id == id) {
                eprintln!("DNS profile '{id}' already exists");
                std::process::exit(2);
            }
            let profile = make_custom_profile(
                id.clone(),
                name.clone(),
                protocol,
                ipv4_servers,
                ipv6_servers,
                doh_url,
                dot_hostname,
                filtering,
                tags,
            );
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
        Command::ProfileUpdate {
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
            let index = snapshot
                .profiles
                .iter()
                .position(|profile| profile.id == id)
                .unwrap_or_else(|| {
                    eprintln!("DNS profile '{id}' not found");
                    std::process::exit(2);
                });
            if !is_custom_profile(&snapshot.profiles[index]) {
                eprintln!("cannot update built-in profile '{id}'");
                std::process::exit(2);
            }

            let profile = make_custom_profile(
                id.clone(),
                name.clone(),
                protocol,
                ipv4_servers,
                ipv6_servers,
                doh_url,
                dot_hostname,
                filtering,
                tags,
            );
            profile.validate().unwrap_or_else(|error| {
                eprintln!("{error}");
                std::process::exit(2);
            });
            snapshot.profiles[index] = profile;
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
                serde_json::to_string_pretty(&payload).expect("serialize profile update")
            );
        }
        Command::ProfileDelete { db, id } => {
            let storage = SqliteStorage::open(&db).unwrap_or_else(|error| {
                eprintln!("{error}");
                std::process::exit(2);
            });
            let mut snapshot = load_snapshot_or_builtin(&storage);
            let index = snapshot
                .profiles
                .iter()
                .position(|profile| profile.id == id)
                .unwrap_or_else(|| {
                    eprintln!("DNS profile '{id}' not found");
                    std::process::exit(2);
                });
            if !is_custom_profile(&snapshot.profiles[index]) {
                eprintln!("cannot delete built-in profile '{id}'");
                std::process::exit(2);
            }
            snapshot.profiles.remove(index);
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
                serde_json::to_string_pretty(&payload).expect("serialize profile delete")
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
            if snapshot.test_suites.iter().any(|suite| suite.id == id) {
                eprintln!("test suite '{id}' already exists");
                std::process::exit(2);
            }
            let suite = make_custom_suite(id.clone(), name.clone(), domains, tags);
            suite.validate().unwrap_or_else(|error| {
                eprintln!("{error}");
                std::process::exit(2);
            });
            snapshot.test_suites.push(suite);
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
        Command::SuiteUpdate {
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
            let index = snapshot
                .test_suites
                .iter()
                .position(|suite| suite.id == id)
                .unwrap_or_else(|| {
                    eprintln!("test suite '{id}' not found");
                    std::process::exit(2);
                });
            if !is_custom_suite(&snapshot.test_suites[index]) {
                eprintln!("cannot update built-in test suite '{id}'");
                std::process::exit(2);
            }

            let suite = make_custom_suite(id.clone(), name.clone(), domains, tags);
            suite.validate().unwrap_or_else(|error| {
                eprintln!("{error}");
                std::process::exit(2);
            });
            snapshot.test_suites[index] = suite;
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
                serde_json::to_string_pretty(&payload).expect("serialize suite update")
            );
        }
        Command::SuiteDelete { db, id } => {
            let storage = SqliteStorage::open(&db).unwrap_or_else(|error| {
                eprintln!("{error}");
                std::process::exit(2);
            });
            let mut snapshot = load_snapshot_or_builtin(&storage);
            let index = snapshot
                .test_suites
                .iter()
                .position(|suite| suite.id == id)
                .unwrap_or_else(|| {
                    eprintln!("test suite '{id}' not found");
                    std::process::exit(2);
                });
            if !is_custom_suite(&snapshot.test_suites[index]) {
                eprintln!("cannot delete built-in test suite '{id}'");
                std::process::exit(2);
            }
            snapshot.test_suites.remove(index);
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
                serde_json::to_string_pretty(&payload).expect("serialize suite delete")
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
        Command::HistoryDelete { db, id } => {
            let storage = SqliteStorage::open(&db).unwrap_or_else(|error| {
                eprintln!("{error}");
                std::process::exit(2);
            });
            let mut snapshot = load_snapshot_or_builtin(&storage);
            let index = snapshot
                .benchmark_history
                .iter()
                .position(|record| record.id == id)
                .unwrap_or_else(|| {
                    eprintln!("benchmark history '{id}' not found");
                    std::process::exit(2);
                });
            snapshot.benchmark_history.remove(index);
            storage.save_snapshot(&snapshot).unwrap_or_else(|error| {
                eprintln!("{error}");
                std::process::exit(2);
            });
            let payload = serde_json::json!({
                "db": db.to_string_lossy(),
                "history_id": id,
                "benchmark_history_count": snapshot.benchmark_history.len(),
            });
            println!(
                "{}",
                serde_json::to_string_pretty(&payload).expect("serialize history delete")
            );
        }
        Command::HistoryClear { db } => {
            let storage = SqliteStorage::open(&db).unwrap_or_else(|error| {
                eprintln!("{error}");
                std::process::exit(2);
            });
            let mut snapshot = load_snapshot_or_builtin(&storage);
            snapshot.benchmark_history.clear();
            storage.save_snapshot(&snapshot).unwrap_or_else(|error| {
                eprintln!("{error}");
                std::process::exit(2);
            });
            let payload = serde_json::json!({
                "db": db.to_string_lossy(),
                "benchmark_history_count": snapshot.benchmark_history.len(),
            });
            println!(
                "{}",
                serde_json::to_string_pretty(&payload).expect("serialize history clear")
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

fn make_custom_profile(
    id: String,
    name: String,
    protocol: ProfileProtocolArg,
    ipv4_servers: Vec<String>,
    ipv6_servers: Vec<String>,
    doh_url: Option<String>,
    dot_hostname: Option<String>,
    filtering: FilteringTypeArg,
    tags: Vec<String>,
) -> DnsProfile {
    DnsProfile {
        id,
        name,
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
    }
}

fn is_custom_profile(profile: &DnsProfile) -> bool {
    profile.use_case == "custom" || profile.tags.iter().any(|tag| tag == "custom")
}

fn make_custom_suite(
    id: String,
    name: String,
    domains: Vec<String>,
    tags: Vec<String>,
) -> TestSuite {
    TestSuite {
        id,
        name,
        description: "Custom domain test suite.".into(),
        domains,
        tags,
    }
}

fn is_custom_suite(suite: &TestSuite) -> bool {
    suite.description == "Custom domain test suite." || suite.tags.iter().any(|tag| tag == "custom")
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
    validate_domains(&resolved);
    resolved
}

fn validate_domains(domains: &[String]) {
    let mut seen = std::collections::BTreeSet::new();
    for domain in domains {
        validate_domain_name(domain).unwrap_or_else(|error| {
            eprintln!("invalid --domain '{domain}': {error}");
            std::process::exit(2);
        });
        let normalized = domain.trim_end_matches('.').to_ascii_lowercase();
        if !seen.insert(normalized) {
            eprintln!("duplicate domain '{domain}'");
            std::process::exit(2);
        }
    }
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

fn resolve_apply_plan_profiles(profile_db: Option<&std::path::Path>) -> Vec<DnsProfile> {
    let Some(profile_db) = profile_db else {
        return built_in_profiles();
    };
    let storage = SqliteStorage::open(profile_db).unwrap_or_else(|error| {
        eprintln!("{error}");
        std::process::exit(2);
    });
    load_snapshot_or_builtin(&storage).profiles
}

fn apply_plan_gate(health: GateHealthArg) -> RecommendationGate {
    let can_recommend = matches!(health, GateHealthArg::Healthy | GateHealthArg::Degraded);
    let primary_issue = match health {
        GateHealthArg::Healthy => RecommendationIssue::None,
        GateHealthArg::Degraded => RecommendationIssue::PartialFailure,
        GateHealthArg::Failed => RecommendationIssue::AllResolversFailed,
        GateHealthArg::Inconclusive => RecommendationIssue::NoResolvers,
    };
    let notes = match health {
        GateHealthArg::Healthy => Vec::new(),
        GateHealthArg::Degraded => {
            vec!["At least one candidate had partial failure or timeout.".into()]
        }
        GateHealthArg::Failed => vec!["Every candidate failed the measured scope.".into()],
        GateHealthArg::Inconclusive => vec!["Benchmark result was inconclusive.".into()],
    };

    RecommendationGate {
        can_recommend,
        health: health.into(),
        primary_issue,
        notes,
    }
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

fn emit_resolver_progress(
    enabled: bool,
    event_type: &str,
    measurement_scope: MeasurementScope,
    profile_id: &str,
    resolver: SocketAddr,
    index: usize,
    total: usize,
    metrics: Option<&BenchmarkMetrics>,
    elapsed: Option<Duration>,
) {
    if !enabled {
        return;
    }

    let mut event = serde_json::json!({
        "type": event_type,
        "measurement_scope": measurement_scope_name(measurement_scope),
        "profile_id": profile_id,
        "resolver": resolver.to_string(),
        "index": index,
        "total": total,
    });
    if let Some(metrics) = metrics {
        event["status"] = serde_json::Value::String(progress_status(metrics).into());
        event["failure_rate"] = serde_json::Value::from(metrics.failure_rate);
        event["timeout_rate"] = serde_json::Value::from(metrics.timeout_rate);
    }
    if let Some(elapsed) = elapsed {
        event["elapsed_ms"] = serde_json::Value::from(elapsed.as_secs_f64() * 1000.0);
    }

    eprintln!(
        "{}",
        serde_json::to_string(&event).expect("serialize progress event")
    );
}

fn progress_status(metrics: &BenchmarkMetrics) -> &'static str {
    if metrics.failure_rate >= 1.0 {
        "failed"
    } else if metrics.failure_rate > 0.0 || metrics.timeout_rate > 0.0 {
        "degraded"
    } else {
        "success"
    }
}

fn measurement_scope_name(scope: MeasurementScope) -> &'static str {
    match scope {
        MeasurementScope::DnsOnly => "dns-only",
        MeasurementScope::DnsTcp => "dns-tcp",
        MeasurementScope::DnsTcpTls => "dns-tcp-tls",
    }
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

fn reject_zero_usize(flag: &str, value: usize) {
    if value == 0 {
        eprintln!("{flag} must be greater than 0");
        std::process::exit(2);
    }
}

fn reject_zero_u64(flag: &str, value: u64) {
    if value == 0 {
        eprintln!("{flag} must be greater than 0");
        std::process::exit(2);
    }
}

fn reject_zero_u16(flag: &str, value: u16) {
    if value == 0 {
        eprintln!("{flag} must be greater than 0");
        std::process::exit(2);
    }
}

fn reject_zero_optional_u64(flag: &str, value: Option<u64>) {
    if value == Some(0) {
        eprintln!("{flag} must be greater than 0");
        std::process::exit(2);
    }
}

fn reject_zero_optional_socket_port(flag: &str, value: Option<SocketAddr>) {
    if value.is_some_and(|address| address.port() == 0) {
        eprintln!("{flag} port must be greater than 0");
        std::process::exit(2);
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
    if resolver.port() == 0 {
        return Err(format!(
            "invalid --resolver '{spec}'; --resolver port must be greater than 0"
        ));
    }

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

impl From<ConfidenceArg> for Confidence {
    fn from(value: ConfidenceArg) -> Self {
        match value {
            ConfidenceArg::High => Confidence::High,
            ConfidenceArg::Medium => Confidence::Medium,
            ConfidenceArg::Low => Confidence::Low,
            ConfidenceArg::Inconclusive => Confidence::Inconclusive,
        }
    }
}

impl From<GateHealthArg> for RecommendationHealth {
    fn from(value: GateHealthArg) -> Self {
        match value {
            GateHealthArg::Healthy => RecommendationHealth::Healthy,
            GateHealthArg::Degraded => RecommendationHealth::Degraded,
            GateHealthArg::Failed => RecommendationHealth::Failed,
            GateHealthArg::Inconclusive => RecommendationHealth::Inconclusive,
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

impl From<IpFamilyArg> for DnsRecordFamily {
    fn from(value: IpFamilyArg) -> Self {
        match value {
            IpFamilyArg::Both => DnsRecordFamily::Both,
            IpFamilyArg::Ipv4Only => DnsRecordFamily::Ipv4Only,
            IpFamilyArg::Ipv6Only => DnsRecordFamily::Ipv6Only,
        }
    }
}

fn ip_family_name(value: IpFamilyArg) -> &'static str {
    match value {
        IpFamilyArg::Both => "both",
        IpFamilyArg::Ipv4Only => "ipv4-only",
        IpFamilyArg::Ipv6Only => "ipv6-only",
    }
}
