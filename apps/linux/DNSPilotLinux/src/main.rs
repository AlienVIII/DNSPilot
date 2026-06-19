use dnspilot_linux_shell::capabilities::{
    available_benchmark_modes, capability_view_model, BenchmarkMode, LinuxEnvironmentProbe,
    LinuxPackageKind,
};
use dnspilot_linux_shell::diagnostics::LinuxDiagnosticReport;
use dnspilot_linux_shell::process::LinuxBenchmarkProcessViewModel;
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

#[derive(Debug, Clone, PartialEq, Eq)]
struct CliConfig {
    package_kind: LinuxPackageKind,
    mode: BenchmarkMode,
    network_manager_available: bool,
    systemd_resolved_available: bool,
    polkit_available: bool,
    system_resolver_probe_available: bool,
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
