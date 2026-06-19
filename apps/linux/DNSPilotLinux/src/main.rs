use dnspilot_linux_shell::app::LinuxAppSession;
use dnspilot_linux_shell::benchmark::build_core_cli_command;
use dnspilot_linux_shell::capabilities::{
    available_benchmark_modes, capability_view_model, BenchmarkMode, LinuxEnvironmentProbe,
    LinuxPackageKind,
};
use dnspilot_linux_shell::diagnostics::LinuxDiagnosticReport;
use dnspilot_linux_shell::process::LinuxBenchmarkProcessViewModel;
use dnspilot_linux_shell::profiles::{CustomProfileStore, PlainDnsProfile, PlainDnsProfileDraft};
use dnspilot_linux_shell::settings::{DnsRecordFamily, ResolverAddressFamily};
use dnspilot_linux_shell::storage::FileProfileRepository;
use dnspilot_linux_shell::suites::default_suite_catalog;
use std::env;
use std::process;

fn main() {
    match run(env::args().skip(1)) {
        Ok(report) => println!("{report}"),
        Err(error) => {
            eprintln!("{}", error.message);
            process::exit(error.exit_code);
        }
    }
}

fn run(args: impl IntoIterator<Item = String>) -> Result<String, CliError> {
    let args = args.into_iter().collect::<Vec<_>>();
    match args.first().map(String::as_str) {
        Some("profile-add") => run_profile_add(args.into_iter().skip(1)),
        Some("profile-list") => run_profile_list(args.into_iter().skip(1)),
        Some("profile-delete") => run_profile_delete(args.into_iter().skip(1)),
        Some("plan") => run_plan(args.into_iter().skip(1)),
        _ => run_legacy_report(args),
    }
}

fn run_legacy_report(args: impl IntoIterator<Item = String>) -> Result<String, CliError> {
    let config = CliConfig::parse(args)?;
    let probe = config.to_probe();
    let capability = capability_view_model(probe);
    if !available_benchmark_modes(&capability).contains(&config.mode) {
        return Err(CliError::new(
            2,
            format!(
                "{} is not supported by current capabilities",
                config.mode_cli_label()
            ),
        ));
    }

    let process = completed_mock_process(config.mode);
    Ok(LinuxDiagnosticReport::new("mocked-linux", capability, process).to_copyable_text())
}

fn run_profile_add(args: impl IntoIterator<Item = String>) -> Result<String, CliError> {
    let config = ProfileAddConfig::parse(args)?;
    let repo = FileProfileRepository::new(config.store.clone());
    let loaded = repo
        .load_profiles()
        .map_err(|error| CliError::new(2, format!("{error:?}")))?;
    let mut store = CustomProfileStore::new();
    for profile in loaded {
        store
            .add(profile_to_draft(profile))
            .map_err(|error| CliError::new(2, format!("{error:?}")))?;
    }
    let id = config.id.clone();
    store
        .add(PlainDnsProfileDraft {
            id: config.id,
            name: config.name,
            ipv4_servers: config.ipv4_servers,
            ipv6_servers: config.ipv6_servers,
        })
        .map_err(|error| CliError::new(2, format!("{error:?}")))?;
    repo.save_profiles(store.list())
        .map_err(|error| CliError::new(2, format!("{error:?}")))?;
    Ok(format!("Saved profile {id}"))
}

fn run_profile_list(args: impl IntoIterator<Item = String>) -> Result<String, CliError> {
    let config = StoreConfig::parse(args)?;
    let repo = FileProfileRepository::new(config.store.clone());
    let profiles = repo
        .load_profiles()
        .map_err(|error| CliError::new(2, format!("{error:?}")))?;
    if profiles.is_empty() {
        return Ok("No custom profiles".to_string());
    }

    Ok(profiles
        .iter()
        .map(|profile| {
            format!(
                "{}\t{}\t{}\t{}",
                profile.id,
                profile.name,
                profile.ipv4_servers.join(","),
                profile.ipv6_servers.join(",")
            )
        })
        .collect::<Vec<_>>()
        .join("\n"))
}

fn run_profile_delete(args: impl IntoIterator<Item = String>) -> Result<String, CliError> {
    let config = ProfileDeleteConfig::parse(args)?;
    let repo = FileProfileRepository::new(config.store);
    let mut profiles = repo
        .load_profiles()
        .map_err(|error| CliError::new(2, format!("{error:?}")))?;
    let before = profiles.len();
    profiles.retain(|profile| profile.id != config.id);
    if before == profiles.len() {
        return Err(CliError::new(2, format!("Profile {} not found", config.id)));
    }
    repo.save_profiles(&profiles)
        .map_err(|error| CliError::new(2, format!("{error:?}")))?;
    Ok(format!("Deleted profile {}", config.id))
}

fn run_plan(args: impl IntoIterator<Item = String>) -> Result<String, CliError> {
    let config = PlanConfig::parse(args)?;
    let repo = FileProfileRepository::new(config.store.clone());
    let profiles = repo
        .load_profiles()
        .map_err(|error| CliError::new(2, format!("{error:?}")))?;
    let capability = capability_view_model(config.to_probe());
    let mut session = LinuxAppSession::new(
        capability,
        default_suite_catalog(config.catalog_vietnam),
        profiles,
    );
    session
        .select_mode(config.mode)
        .map_err(|error| CliError::new(2, error))?;
    if !config.profile_ids.is_empty() {
        session.set_selected_profiles(config.profile_ids);
    }
    session.resolver_address_family = config.resolver_address_family;
    session.record_family = config.record_family;
    session.selected_suite_id = config.suite_id;
    session.set_custom_domains(config.domains);

    let plan = session
        .build_plan()
        .map_err(|issues| CliError::new(2, issues.join("; ")))?;
    let command = build_core_cli_command("dnspilot-cli", &plan);
    Ok(format!(
        "Core command:\n{} {}",
        command.program,
        command.args.join(" ")
    ))
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct CliConfig {
    package_kind: LinuxPackageKind,
    mode: BenchmarkMode,
    network_manager_available: bool,
    systemd_resolved_available: bool,
    polkit_available: bool,
    system_resolver_probe_available: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct StoreConfig {
    store: String,
}

impl StoreConfig {
    fn parse(args: impl IntoIterator<Item = String>) -> Result<Self, CliError> {
        let mut store = None;
        let mut args = args.into_iter();
        while let Some(arg) = args.next() {
            match arg.as_str() {
                "--store" => store = Some(next_arg(&mut args, "--store")?),
                _ => return Err(CliError::new(2, format!("unknown argument: {arg}"))),
            }
        }
        Ok(Self {
            store: store.ok_or_else(|| CliError::new(2, "--store is required"))?,
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct ProfileAddConfig {
    store: String,
    id: String,
    name: String,
    ipv4_servers: Vec<String>,
    ipv6_servers: Vec<String>,
}

impl ProfileAddConfig {
    fn parse(args: impl IntoIterator<Item = String>) -> Result<Self, CliError> {
        let mut store = None;
        let mut id = None;
        let mut name = None;
        let mut ipv4_servers = Vec::new();
        let mut ipv6_servers = Vec::new();
        let mut args = args.into_iter();
        while let Some(arg) = args.next() {
            match arg.as_str() {
                "--store" => store = Some(next_arg(&mut args, "--store")?),
                "--id" => id = Some(next_arg(&mut args, "--id")?),
                "--name" => name = Some(next_arg(&mut args, "--name")?),
                "--ipv4" => ipv4_servers.push(next_arg(&mut args, "--ipv4")?),
                "--ipv6" => ipv6_servers.push(next_arg(&mut args, "--ipv6")?),
                _ => return Err(CliError::new(2, format!("unknown argument: {arg}"))),
            }
        }
        Ok(Self {
            store: store.ok_or_else(|| CliError::new(2, "--store is required"))?,
            id: id.ok_or_else(|| CliError::new(2, "--id is required"))?,
            name: name.ok_or_else(|| CliError::new(2, "--name is required"))?,
            ipv4_servers,
            ipv6_servers,
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct ProfileDeleteConfig {
    store: String,
    id: String,
}

impl ProfileDeleteConfig {
    fn parse(args: impl IntoIterator<Item = String>) -> Result<Self, CliError> {
        let mut store = None;
        let mut id = None;
        let mut args = args.into_iter();
        while let Some(arg) = args.next() {
            match arg.as_str() {
                "--store" => store = Some(next_arg(&mut args, "--store")?),
                "--id" => id = Some(next_arg(&mut args, "--id")?),
                _ => return Err(CliError::new(2, format!("unknown argument: {arg}"))),
            }
        }
        Ok(Self {
            store: store.ok_or_else(|| CliError::new(2, "--store is required"))?,
            id: id.ok_or_else(|| CliError::new(2, "--id is required"))?,
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct PlanConfig {
    store: String,
    package_kind: LinuxPackageKind,
    mode: BenchmarkMode,
    profile_ids: Vec<String>,
    resolver_address_family: ResolverAddressFamily,
    record_family: DnsRecordFamily,
    suite_id: Option<String>,
    domains: Vec<String>,
    catalog_vietnam: bool,
    network_manager_available: bool,
    systemd_resolved_available: bool,
    polkit_available: bool,
    system_resolver_probe_available: bool,
}

impl PlanConfig {
    fn parse(args: impl IntoIterator<Item = String>) -> Result<Self, CliError> {
        let mut config = Self {
            store: String::new(),
            package_kind: LinuxPackageKind::Flatpak,
            mode: BenchmarkMode::DnsAndTcp,
            profile_ids: Vec::new(),
            resolver_address_family: ResolverAddressFamily::Auto,
            record_family: DnsRecordFamily::AAndAaaa,
            suite_id: None,
            domains: Vec::new(),
            catalog_vietnam: false,
            network_manager_available: false,
            systemd_resolved_available: false,
            polkit_available: false,
            system_resolver_probe_available: false,
        };
        let mut args = args.into_iter();
        while let Some(arg) = args.next() {
            match arg.as_str() {
                "--store" => config.store = next_arg(&mut args, "--store")?,
                "--package" => {
                    config.package_kind = parse_package_kind(&next_arg(&mut args, "--package")?)?
                }
                "--mode" => config.mode = parse_mode(&next_arg(&mut args, "--mode")?)?,
                "--profile-id" => config
                    .profile_ids
                    .push(next_arg(&mut args, "--profile-id")?),
                "--resolver-family" => {
                    config.resolver_address_family =
                        parse_resolver_family(&next_arg(&mut args, "--resolver-family")?)?
                }
                "--record-family" => {
                    config.record_family =
                        parse_record_family(&next_arg(&mut args, "--record-family")?)?
                }
                "--suite-id" => config.suite_id = Some(next_arg(&mut args, "--suite-id")?),
                "--domain" => config.domains.push(next_arg(&mut args, "--domain")?),
                "--catalog-vietnam" => config.catalog_vietnam = true,
                "--network-manager" => config.network_manager_available = true,
                "--systemd-resolved" => config.systemd_resolved_available = true,
                "--polkit" => config.polkit_available = true,
                "--system-resolver-probe" => config.system_resolver_probe_available = true,
                _ => return Err(CliError::new(2, format!("unknown argument: {arg}"))),
            }
        }
        if config.store.is_empty() {
            return Err(CliError::new(2, "--store is required"));
        }
        Ok(config)
    }

    fn to_probe(&self) -> LinuxEnvironmentProbe {
        LinuxEnvironmentProbe {
            package_kind: self.package_kind,
            network_manager_available: self.network_manager_available,
            systemd_resolved_available: self.systemd_resolved_available,
            polkit_available: self.polkit_available,
            system_resolver_probe_available: self.system_resolver_probe_available,
        }
    }
}

impl CliConfig {
    fn parse(args: impl IntoIterator<Item = String>) -> Result<Self, CliError> {
        let mut config = Self {
            package_kind: LinuxPackageKind::Flatpak,
            mode: BenchmarkMode::DnsAndTcp,
            network_manager_available: false,
            systemd_resolved_available: false,
            polkit_available: false,
            system_resolver_probe_available: false,
        };
        let mut args = args.into_iter();

        while let Some(arg) = args.next() {
            match arg.as_str() {
                "--package" => {
                    let value = next_arg(&mut args, "--package")?;
                    config.package_kind = parse_package_kind(&value)?;
                }
                "--mode" => {
                    let value = next_arg(&mut args, "--mode")?;
                    config.mode = parse_mode(&value)?;
                }
                "--network-manager" => config.network_manager_available = true,
                "--systemd-resolved" => config.systemd_resolved_available = true,
                "--polkit" => config.polkit_available = true,
                "--system-resolver-probe" => config.system_resolver_probe_available = true,
                "--help" | "-h" => {
                    return Err(CliError::new(
                        0,
                        "Usage: dnspilot-linux-shell --package flatpak|snap|deb|rpm --mode dns-only|dns-tcp|system-resolver [--network-manager] [--systemd-resolved] [--polkit] [--system-resolver-probe]",
                    ));
                }
                _ => return Err(CliError::new(2, format!("unknown argument: {arg}"))),
            }
        }

        Ok(config)
    }

    fn to_probe(&self) -> LinuxEnvironmentProbe {
        LinuxEnvironmentProbe {
            package_kind: self.package_kind,
            network_manager_available: self.network_manager_available,
            systemd_resolved_available: self.systemd_resolved_available,
            polkit_available: self.polkit_available,
            system_resolver_probe_available: self.system_resolver_probe_available,
        }
    }

    fn mode_cli_label(&self) -> &'static str {
        match self.mode {
            BenchmarkMode::DnsOnly => "dns-only",
            BenchmarkMode::DnsAndTcp => "dns-tcp",
            BenchmarkMode::CurrentSystemResolver => "system-resolver",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct CliError {
    exit_code: i32,
    message: String,
}

impl CliError {
    fn new(exit_code: i32, message: impl Into<String>) -> Self {
        Self {
            exit_code,
            message: message.into(),
        }
    }
}

fn next_arg(args: &mut impl Iterator<Item = String>, flag: &str) -> Result<String, CliError> {
    args.next()
        .ok_or_else(|| CliError::new(2, format!("{flag} requires a value")))
}

fn parse_package_kind(value: &str) -> Result<LinuxPackageKind, CliError> {
    match value {
        "flatpak" => Ok(LinuxPackageKind::Flatpak),
        "snap" => Ok(LinuxPackageKind::Snap),
        "deb" => Ok(LinuxPackageKind::Deb),
        "rpm" => Ok(LinuxPackageKind::Rpm),
        _ => Err(CliError::new(2, format!("unknown package: {value}"))),
    }
}

fn parse_mode(value: &str) -> Result<BenchmarkMode, CliError> {
    match value {
        "dns-only" => Ok(BenchmarkMode::DnsOnly),
        "dns-tcp" => Ok(BenchmarkMode::DnsAndTcp),
        "system-resolver" => Ok(BenchmarkMode::CurrentSystemResolver),
        _ => Err(CliError::new(2, format!("unknown mode: {value}"))),
    }
}

fn parse_resolver_family(value: &str) -> Result<ResolverAddressFamily, CliError> {
    match value {
        "auto" => Ok(ResolverAddressFamily::Auto),
        "ipv4" => Ok(ResolverAddressFamily::Ipv4Only),
        "ipv6" => Ok(ResolverAddressFamily::Ipv6Only),
        _ => Err(CliError::new(
            2,
            format!("unknown resolver family: {value}"),
        )),
    }
}

fn parse_record_family(value: &str) -> Result<DnsRecordFamily, CliError> {
    match value {
        "both" | "a+aaaa" => Ok(DnsRecordFamily::AAndAaaa),
        "a" => Ok(DnsRecordFamily::AOnly),
        "aaaa" => Ok(DnsRecordFamily::AaaaOnly),
        _ => Err(CliError::new(2, format!("unknown record family: {value}"))),
    }
}

fn profile_to_draft(profile: PlainDnsProfile) -> PlainDnsProfileDraft {
    PlainDnsProfileDraft {
        id: profile.id,
        name: profile.name,
        ipv4_servers: profile.ipv4_servers,
        ipv6_servers: profile.ipv6_servers,
    }
}

fn completed_mock_process(mode: BenchmarkMode) -> LinuxBenchmarkProcessViewModel {
    let resolvers = match mode {
        BenchmarkMode::CurrentSystemResolver => vec![("system", "Current system resolver")],
        BenchmarkMode::DnsOnly | BenchmarkMode::DnsAndTcp => {
            vec![("cloudflare", "Cloudflare"), ("quad9", "Quad9")]
        }
    };
    let mut process = LinuxBenchmarkProcessViewModel::new(mode, resolvers);
    let step_ids = process.steps.iter().map(|step| step.id).collect::<Vec<_>>();
    for step_id in step_ids {
        process.start_step(step_id);
        process.complete_step(step_id, "mocked validation; no DNS mutation");
    }
    let resolver_ids = process
        .resolvers
        .iter()
        .map(|resolver| resolver.id.clone())
        .collect::<Vec<_>>();
    for resolver_id in resolver_ids {
        process.complete_resolver(&resolver_id, "mocked validation; no DNS mutation");
    }
    process
}
