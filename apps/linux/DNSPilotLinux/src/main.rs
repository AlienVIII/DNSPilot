use dnspilot_linux_shell::app::LinuxAppSession;
use dnspilot_linux_shell::benchmark::{
    build_core_cli_command, run_benchmark_with_runner, ProcessCoreCliRunner,
};
use dnspilot_linux_shell::capabilities::{
    available_benchmark_modes, capability_view_model, BenchmarkMode, LinuxEnvironmentProbe,
    LinuxPackageKind,
};
use dnspilot_linux_shell::core_adapter::{
    CoreCliAdapter, CoreCliAdapterError, ProcessCoreCliCommandRunner,
};
use dnspilot_linux_shell::detect::{
    detect_linux_environment, detect_linux_environment_from_snapshot, LinuxDetectionSnapshot,
};
use dnspilot_linux_shell::diagnostics::LinuxDiagnosticReport;
use dnspilot_linux_shell::executable::resolve_core_cli;
use dnspilot_linux_shell::i18n::Language;
use dnspilot_linux_shell::native_app::{build_native_app_model, render_native_app_model};
use dnspilot_linux_shell::native_power::{
    build_native_apply_plan, render_native_apply_plan, NativeApplyError,
};
use dnspilot_linux_shell::permissions::{permission_plan, render_permission_plan};
use dnspilot_linux_shell::process::LinuxBenchmarkProcessViewModel;
use dnspilot_linux_shell::profiles::{CustomProfileStore, PlainDnsProfile, PlainDnsProfileDraft};
use dnspilot_linux_shell::publish::{publish_check, render_publish_check};
use dnspilot_linux_shell::readiness::{linux_release_readiness, render_readiness_report};
use dnspilot_linux_shell::settings::{
    build_guided_settings_plan, native_power_path_plan, render_guided_settings_plan,
    DnsRecordFamily, ResolverAddressFamily,
};
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
        Some("profile-edit") => run_profile_edit(args.into_iter().skip(1)),
        Some("profile-list") => run_profile_list(args.into_iter().skip(1)),
        Some("profile-delete") => run_profile_delete(args.into_iter().skip(1)),
        Some("plan") => run_plan(args.into_iter().skip(1)),
        Some("run") => run_execute(args.into_iter().skip(1)),
        Some("guide") => run_guide(args.into_iter().skip(1)),
        Some("detect") => run_detect(args.into_iter().skip(1)),
        Some("permissions") => run_permissions(args.into_iter().skip(1)),
        Some("app-model") => run_app_model(args.into_iter().skip(1)),
        Some("publish-check") => run_publish_check(args.into_iter().skip(1)),
        Some("apply-plan") => run_apply_plan(args.into_iter().skip(1)),
        Some("readiness") => Ok(render_readiness_report(&linux_release_readiness())),
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
    let mut adapter = core_adapter(&config.store)?;
    let loaded = load_plain_profiles(&mut adapter)?;
    let id = config.id.clone();
    let profile = profile_from_config(&config);
    validate_profile(&loaded, &profile, false)?;
    adapter
        .save_plain_profile(&profile, false)
        .map_err(core_adapter_error)?;
    Ok(format!("Saved profile {id}"))
}

fn run_profile_edit(args: impl IntoIterator<Item = String>) -> Result<String, CliError> {
    let config = ProfileAddConfig::parse(args)?;
    let mut adapter = core_adapter(&config.store)?;
    let loaded = load_plain_profiles(&mut adapter)?;
    let id = config.id.clone();
    let profile = profile_from_config(&config);
    validate_profile(&loaded, &profile, true)?;
    adapter
        .save_plain_profile(&profile, true)
        .map_err(core_adapter_error)?;
    Ok(format!("Updated profile {id}"))
}

fn run_profile_list(args: impl IntoIterator<Item = String>) -> Result<String, CliError> {
    let config = StoreConfig::parse(args)?;
    let mut adapter = core_adapter(&config.store)?;
    let profiles = load_plain_profiles(&mut adapter)?;
    if profiles.is_empty() {
        return Ok("No DNS profiles".to_string());
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
    let mut adapter = core_adapter(&config.store)?;
    adapter
        .delete_profile(&config.id)
        .map_err(core_adapter_error)?;
    Ok(format!("Deleted profile {}", config.id))
}

fn run_plan(args: impl IntoIterator<Item = String>) -> Result<String, CliError> {
    let config = PlanConfig::parse(args)?;
    let (_, plan) = build_plan_from_config(&config)?;
    let command = build_core_cli_command("dnspilot-cli", &plan);
    Ok(format!(
        "Core command:\n{} {}",
        command.program,
        command.args.join(" ")
    ))
}

fn run_execute(args: impl IntoIterator<Item = String>) -> Result<String, CliError> {
    let (core_cli, plan_args) = split_core_cli_arg(args)?;
    let config = PlanConfig::parse(plan_args)?;
    let (capability, plan) = build_plan_from_config(&config)?;
    let runner = ProcessCoreCliRunner;
    let result = run_benchmark_with_runner(core_cli, "mocked-linux", capability, plan, &runner);
    let mut output = result.debug_report;
    if let Some(payload) = result.final_payload {
        output.push_str("\n\nFinal payload:\n");
        output.push_str(&payload);
    }
    if let Some(error) = result.error {
        return Err(CliError::new(2, format!("{output}\n\nRun error: {error}")));
    }
    Ok(output)
}

fn run_guide(args: impl IntoIterator<Item = String>) -> Result<String, CliError> {
    let config = PlanConfig::parse(args)?;
    let mut adapter = core_adapter(&config.store)?;
    let profiles = load_plain_profiles(&mut adapter)?;
    let capability = capability_view_model(config.to_probe());

    if capability.guided_settings_only {
        let profile_id = config
            .profile_ids
            .first()
            .ok_or_else(|| CliError::new(2, "--profile-id is required for guided settings"))?;
        let profile = profiles
            .iter()
            .find(|profile| profile.id == *profile_id)
            .ok_or_else(|| CliError::new(2, format!("Profile {profile_id} not found")))?;
        let plan = build_guided_settings_plan(
            &capability,
            profile,
            config.resolver_address_family,
            config.language,
        )
        .map_err(|error| CliError::new(2, format!("{error:?}")))?;
        return Ok(render_guided_settings_plan(&plan));
    }

    if capability.can_apply_real_dns {
        let plan = native_power_path_plan();
        let mut lines = vec![plan.title.to_string()];
        for (index, step) in plan.steps.iter().enumerate() {
            lines.push(format!("{}. {step}", index + 1));
        }
        return Ok(lines.join("\n"));
    }

    Ok(format!(
        "Native Power unavailable\nPackage: {}\n{}",
        capability.package_kind.label(),
        capability.notes.join("\n")
    ))
}

fn run_detect(args: impl IntoIterator<Item = String>) -> Result<String, CliError> {
    let config = DetectConfig::parse(args)?;
    let probe = if config.has_mock_inputs {
        detect_linux_environment_from_snapshot(&config.snapshot)
    } else {
        detect_linux_environment()
    };
    let capability = capability_view_model(probe);
    let process = completed_mock_process(BenchmarkMode::DnsOnly);
    Ok(LinuxDiagnosticReport::new("detected-linux", capability, process).to_copyable_text())
}

fn run_permissions(args: impl IntoIterator<Item = String>) -> Result<String, CliError> {
    let config = SurfaceConfig::parse(args)?;
    let capability = capability_view_model(config.to_probe());
    let plan = permission_plan(&capability, config.language);
    Ok(render_permission_plan(&plan))
}

fn run_app_model(args: impl IntoIterator<Item = String>) -> Result<String, CliError> {
    let config = SurfaceConfig::parse(args)?;
    let capability = capability_view_model(config.to_probe());
    let model = build_native_app_model(&capability, config.language);
    Ok(render_native_app_model(&model))
}

fn run_publish_check(args: impl IntoIterator<Item = String>) -> Result<String, CliError> {
    let config = PublishCheckConfig::parse(args)?;
    match config.package_selection {
        PublishPackageSelection::One(package_kind) => {
            let capability = capability_view_model(config.to_probe(package_kind));
            let check = publish_check(&capability, config.language);
            Ok(render_publish_check(&check))
        }
        PublishPackageSelection::All => Ok([
            LinuxPackageKind::Flatpak,
            LinuxPackageKind::Snap,
            LinuxPackageKind::Deb,
            LinuxPackageKind::Rpm,
        ]
        .into_iter()
        .map(|package_kind| {
            let capability = capability_view_model(config.to_probe(package_kind));
            render_publish_check(&publish_check(&capability, config.language))
        })
        .collect::<Vec<_>>()
        .join("\n\n")),
    }
}

fn run_apply_plan(args: impl IntoIterator<Item = String>) -> Result<String, CliError> {
    let config = PlanConfig::parse(args)?;
    if config.profile_ids.len() != 1 {
        return Err(CliError::new(
            2,
            "apply-plan requires exactly one --profile-id",
        ));
    }

    let mut adapter = core_adapter(&config.store)?;
    let profiles = load_plain_profiles(&mut adapter)?;
    let profile_id = &config.profile_ids[0];
    let profile = profiles
        .iter()
        .find(|profile| profile.id == *profile_id)
        .ok_or_else(|| CliError::new(2, format!("Profile {profile_id} not found")))?;
    let capability = capability_view_model(config.to_probe());
    let plan = build_native_apply_plan(&capability, profile, config.resolver_address_family)
        .map_err(|error| {
            let message = match error {
                NativeApplyError::PowerExecutionUnavailable => {
                    "Native DNS apply is unavailable in this build. Use guided settings in a store package, or wait for the separately verified native Power service."
                }
                _ => return CliError::new(2, format!("{error:?}")),
            };
            CliError::new(2, message)
        })?;
    Ok(render_native_apply_plan(&plan))
}

fn build_plan_from_config(
    config: &PlanConfig,
) -> Result<
    (
        dnspilot_linux_shell::capabilities::LinuxCapabilityViewModel,
        dnspilot_linux_shell::benchmark::LinuxBenchmarkPlan,
    ),
    CliError,
> {
    let mut adapter = core_adapter(&config.store)?;
    let profiles = load_plain_profiles(&mut adapter)?;
    let suites = dnspilot_linux_shell::suites::suite_catalog_from_core(
        adapter.load_suites().map_err(core_adapter_error)?,
    );
    let capability = capability_view_model(config.to_probe());
    let mut session = LinuxAppSession::new(capability.clone(), suites, profiles);
    session
        .select_mode(config.mode)
        .map_err(|error| CliError::new(2, error))?;
    if !config.profile_ids.is_empty() {
        session.set_selected_profiles(config.profile_ids.clone());
    }
    session.resolver_address_family = config.resolver_address_family;
    session.record_family = config.record_family;
    session.selected_suite_id = config.suite_id.clone();
    session.set_custom_domains(config.domains.clone());

    let mut plan = session
        .build_plan()
        .map_err(|issues| CliError::new(2, issues.join("; ")))?;
    plan.profile_db = Some(config.store.clone());
    plan.suite_db = Some(config.store.clone());
    plan.history_db = Some(config.store.clone());
    Ok((capability, plan))
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
    network_manager_available: bool,
    systemd_resolved_available: bool,
    polkit_available: bool,
    system_resolver_probe_available: bool,
    language: Language,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct DetectConfig {
    snapshot: LinuxDetectionSnapshot,
    has_mock_inputs: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct SurfaceConfig {
    package_kind: LinuxPackageKind,
    network_manager_available: bool,
    systemd_resolved_available: bool,
    polkit_available: bool,
    system_resolver_probe_available: bool,
    language: Language,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum PublishPackageSelection {
    One(LinuxPackageKind),
    All,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct PublishCheckConfig {
    package_selection: PublishPackageSelection,
    network_manager_available: bool,
    systemd_resolved_available: bool,
    polkit_available: bool,
    system_resolver_probe_available: bool,
    language: Language,
}

impl DetectConfig {
    fn parse(args: impl IntoIterator<Item = String>) -> Result<Self, CliError> {
        let mut snapshot = LinuxDetectionSnapshot::empty();
        let mut has_mock_inputs = false;
        let mut args = args.into_iter();
        while let Some(arg) = args.next() {
            match arg.as_str() {
                "--mock-env" => {
                    let pair = next_arg(&mut args, "--mock-env")?;
                    let (key, value) = pair
                        .split_once('=')
                        .ok_or_else(|| CliError::new(2, "--mock-env must use KEY=VALUE"))?;
                    snapshot = snapshot.with_env(key, value);
                    has_mock_inputs = true;
                }
                "--mock-path" => {
                    snapshot = snapshot.with_path(next_arg(&mut args, "--mock-path")?);
                    has_mock_inputs = true;
                }
                "--mock-command" => {
                    snapshot = snapshot.with_command(next_arg(&mut args, "--mock-command")?);
                    has_mock_inputs = true;
                }
                _ => return Err(CliError::new(2, format!("unknown argument: {arg}"))),
            }
        }
        Ok(Self {
            snapshot,
            has_mock_inputs,
        })
    }
}

impl SurfaceConfig {
    fn parse(args: impl IntoIterator<Item = String>) -> Result<Self, CliError> {
        let mut config = Self {
            package_kind: LinuxPackageKind::Flatpak,
            network_manager_available: false,
            systemd_resolved_available: false,
            polkit_available: false,
            system_resolver_probe_available: false,
            language: Language::English,
        };
        let mut args = args.into_iter();
        while let Some(arg) = args.next() {
            match arg.as_str() {
                "--package" => {
                    config.package_kind = parse_package_kind(&next_arg(&mut args, "--package")?)?
                }
                "--network-manager" => config.network_manager_available = true,
                "--systemd-resolved" => config.systemd_resolved_available = true,
                "--polkit" => config.polkit_available = true,
                "--system-resolver-probe" => config.system_resolver_probe_available = true,
                "--lang" => {
                    let value = next_arg(&mut args, "--lang")?;
                    config.language = Language::parse(&value)
                        .ok_or_else(|| CliError::new(2, format!("unknown language: {value}")))?;
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
}

impl PublishCheckConfig {
    fn parse(args: impl IntoIterator<Item = String>) -> Result<Self, CliError> {
        let mut config = Self {
            package_selection: PublishPackageSelection::One(LinuxPackageKind::Flatpak),
            network_manager_available: false,
            systemd_resolved_available: false,
            polkit_available: false,
            system_resolver_probe_available: false,
            language: Language::English,
        };
        let mut args = args.into_iter();
        while let Some(arg) = args.next() {
            match arg.as_str() {
                "--package" => {
                    config.package_selection =
                        parse_publish_package_selection(&next_arg(&mut args, "--package")?)?
                }
                "--network-manager" => config.network_manager_available = true,
                "--systemd-resolved" => config.systemd_resolved_available = true,
                "--polkit" => config.polkit_available = true,
                "--system-resolver-probe" => config.system_resolver_probe_available = true,
                "--lang" => {
                    let value = next_arg(&mut args, "--lang")?;
                    config.language = Language::parse(&value)
                        .ok_or_else(|| CliError::new(2, format!("unknown language: {value}")))?;
                }
                _ => return Err(CliError::new(2, format!("unknown argument: {arg}"))),
            }
        }
        Ok(config)
    }

    fn to_probe(&self, package_kind: LinuxPackageKind) -> LinuxEnvironmentProbe {
        LinuxEnvironmentProbe {
            package_kind,
            network_manager_available: self.network_manager_available,
            systemd_resolved_available: self.systemd_resolved_available,
            polkit_available: self.polkit_available,
            system_resolver_probe_available: self.system_resolver_probe_available,
        }
    }
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
            network_manager_available: false,
            systemd_resolved_available: false,
            polkit_available: false,
            system_resolver_probe_available: false,
            language: Language::English,
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
                "--network-manager" => config.network_manager_available = true,
                "--systemd-resolved" => config.systemd_resolved_available = true,
                "--polkit" => config.polkit_available = true,
                "--system-resolver-probe" => config.system_resolver_probe_available = true,
                "--lang" => {
                    let value = next_arg(&mut args, "--lang")?;
                    config.language = Language::parse(&value)
                        .ok_or_else(|| CliError::new(2, format!("unknown language: {value}")))?;
                }
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

fn parse_publish_package_selection(value: &str) -> Result<PublishPackageSelection, CliError> {
    if value == "all" {
        return Ok(PublishPackageSelection::All);
    }
    parse_package_kind(value).map(PublishPackageSelection::One)
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

fn split_core_cli_arg(
    args: impl IntoIterator<Item = String>,
) -> Result<(String, Vec<String>), CliError> {
    let mut core_cli = None;
    let mut plan_args = Vec::new();
    let mut args = args.into_iter();
    while let Some(arg) = args.next() {
        if arg == "--core-cli" {
            core_cli = Some(next_arg(&mut args, "--core-cli")?);
        } else {
            plan_args.push(arg);
        }
    }
    Ok((
        core_cli.ok_or_else(|| CliError::new(2, "--core-cli is required"))?,
        plan_args,
    ))
}

fn core_adapter(
    database_path: &str,
) -> Result<CoreCliAdapter<ProcessCoreCliCommandRunner>, CliError> {
    let resolution = resolve_core_cli().map_err(|error| CliError::new(2, error.to_string()))?;
    Ok(CoreCliAdapter::new(
        resolution.path.to_string_lossy(),
        database_path,
        ProcessCoreCliCommandRunner,
    ))
}

fn load_plain_profiles(
    adapter: &mut CoreCliAdapter<ProcessCoreCliCommandRunner>,
) -> Result<Vec<PlainDnsProfile>, CliError> {
    adapter
        .load_profiles()
        .map(|profiles| profiles.into_iter().map(Into::into).collect())
        .map_err(core_adapter_error)
}

fn core_adapter_error(error: CoreCliAdapterError) -> CliError {
    CliError::new(2, format!("Core CLI error: {error:?}"))
}

fn profile_from_config(config: &ProfileAddConfig) -> PlainDnsProfile {
    PlainDnsProfile {
        id: config.id.clone(),
        name: config.name.clone(),
        ipv4_servers: config.ipv4_servers.clone(),
        ipv6_servers: config.ipv6_servers.clone(),
    }
}

fn validate_profile(
    existing_profiles: &[PlainDnsProfile],
    profile: &PlainDnsProfile,
    update: bool,
) -> Result<(), CliError> {
    let mut store = CustomProfileStore::new();
    for existing in existing_profiles {
        store
            .add(profile_to_draft(existing))
            .map_err(|error| CliError::new(2, format!("{error:?}")))?;
    }
    let draft = profile_to_draft(profile);
    let result = if update {
        store.edit(draft)
    } else {
        store.add(draft)
    };
    result.map_err(|error| CliError::new(2, format!("{error:?}")))
}

fn profile_to_draft(profile: &PlainDnsProfile) -> PlainDnsProfileDraft {
    PlainDnsProfileDraft {
        id: profile.id.clone(),
        name: profile.name.clone(),
        ipv4_servers: profile.ipv4_servers.clone(),
        ipv6_servers: profile.ipv6_servers.clone(),
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
