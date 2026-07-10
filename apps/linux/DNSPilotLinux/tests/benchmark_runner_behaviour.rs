use std::cell::RefCell;

use dnspilot_linux_shell::benchmark::{
    benchmark_process_for_plan, benchmark_running_process_for_plan, build_core_cli_command,
    parse_progress_jsonl, run_benchmark_with_runner, CoreCliCommand, CoreCliProgressStatus,
    CoreCliRunOutput, CoreCliRunner, LinuxBenchmarkPlan, ProcessCoreCliRunner, ResolverSelection,
};
use dnspilot_linux_shell::capabilities::{
    capability_view_model, BenchmarkMode, LinuxEnvironmentProbe, LinuxPackageKind,
};
use dnspilot_linux_shell::process::{ProcessStatus, ProcessStepId};
use dnspilot_linux_shell::settings::DnsRecordFamily;

fn probe(package_kind: LinuxPackageKind) -> LinuxEnvironmentProbe {
    LinuxEnvironmentProbe {
        package_kind,
        network_manager_available: false,
        systemd_resolved_available: false,
        polkit_available: false,
        system_resolver_probe_available: false,
    }
}

fn resolver(id: &str, label: &str, resolver_spec: &str) -> ResolverSelection {
    ResolverSelection {
        id: id.to_string(),
        label: label.to_string(),
        resolver_spec: resolver_spec.to_string(),
    }
}

fn plan(mode: BenchmarkMode) -> LinuxBenchmarkPlan {
    LinuxBenchmarkPlan {
        mode,
        package_platform: "linux-flatpak".to_string(),
        resolvers: vec![
            resolver("cloudflare", "Cloudflare", "cloudflare=1.1.1.1"),
            resolver("quad9", "Quad9", "quad9=9.9.9.9"),
        ],
        domains: vec!["github.com".to_string(), "microsoft.com".to_string()],
        suite_id: Some("developer".to_string()),
        suite_db: Some("/tmp/suites.sqlite".to_string()),
        profile_db: Some("/tmp/profiles.sqlite".to_string()),
        attempts: 2,
        record_family: DnsRecordFamily::AOnly,
    }
}

#[test]
fn dns_only_plan_builds_compare_command_with_progress_and_family_controls() {
    let command = build_core_cli_command("dnspilot-cli", &plan(BenchmarkMode::DnsOnly));

    assert_eq!(command.program, "dnspilot-cli");
    assert_eq!(command.args[0], "compare");
    assert!(command
        .args
        .windows(2)
        .any(|args| args == ["--resolver", "cloudflare=1.1.1.1"]));
    assert!(command
        .args
        .windows(2)
        .any(|args| args == ["--resolver", "quad9=9.9.9.9"]));
    assert!(command
        .args
        .windows(2)
        .any(|args| args == ["--domain", "github.com"]));
    assert!(command
        .args
        .windows(2)
        .any(|args| args == ["--domain", "microsoft.com"]));
    assert!(command
        .args
        .windows(2)
        .any(|args| args == ["--suite-id", "developer"]));
    assert!(command
        .args
        .windows(2)
        .any(|args| args == ["--suite-db", "/tmp/suites.sqlite"]));
    assert!(command
        .args
        .windows(2)
        .any(|args| args == ["--profile-db", "/tmp/profiles.sqlite"]));
    assert!(command
        .args
        .windows(2)
        .any(|args| args == ["--attempts", "2"]));
    assert!(command
        .args
        .windows(2)
        .any(|args| args == ["--ip-family", "ipv4-only"]));
    assert!(command.args.contains(&"--progress-jsonl".to_string()));
}

#[test]
fn dns_tcp_plan_builds_path_compare_command() {
    let command = build_core_cli_command("dnspilot-cli", &plan(BenchmarkMode::DnsAndTcp));

    assert_eq!(command.args[0], "path-compare");
    assert!(command.args.contains(&"--progress-jsonl".to_string()));
    assert!(command
        .args
        .windows(2)
        .any(|args| args == ["--ip-family", "ipv4-only"]));
}

#[test]
fn system_resolver_plan_builds_system_benchmark_command_without_resolver_specs() {
    let mut plan = plan(BenchmarkMode::CurrentSystemResolver);
    plan.package_platform = "linux-native-power".to_string();
    plan.resolvers.clear();
    plan.record_family = DnsRecordFamily::AAndAaaa;

    let command = build_core_cli_command("dnspilot-cli", &plan);

    assert_eq!(command.args[0], "system-benchmark");
    assert!(command
        .args
        .windows(2)
        .any(|args| args == ["--platform", "linux-native-power"]));
    assert!(!command.args.contains(&"--resolver".to_string()));
    assert!(command
        .args
        .windows(2)
        .any(|args| args == ["--ip-family", "both"]));
    assert!(command.args.contains(&"--progress-jsonl".to_string()));
}

#[test]
fn benchmark_process_preview_builds_idle_rows_from_plan() {
    let process = benchmark_process_for_plan(&plan(BenchmarkMode::DnsAndTcp));

    assert_eq!(process.mode, BenchmarkMode::DnsAndTcp);
    assert_eq!(process.resolvers[0].label, "Cloudflare");
    assert!(process
        .steps
        .iter()
        .all(|step| step.status == ProcessStatus::Idle));
    assert!(process
        .resolvers
        .iter()
        .all(|resolver| resolver.status == ProcessStatus::Idle));

    let mut system_plan = plan(BenchmarkMode::CurrentSystemResolver);
    system_plan.resolvers.clear();
    let system_process = benchmark_process_for_plan(&system_plan);

    assert_eq!(system_process.resolvers.len(), 1);
    assert_eq!(system_process.resolvers[0].id, "system-dns");
    assert_eq!(system_process.resolvers[0].label, "Current system resolver");
}

#[test]
fn running_process_marks_active_steps_and_resolvers_without_finishing_diagnostics() {
    let process = benchmark_running_process_for_plan(&plan(BenchmarkMode::DnsAndTcp));

    assert_eq!(
        process.step_status(ProcessStepId::DetectCapabilities),
        Some(ProcessStatus::Success)
    );
    assert_eq!(
        process.step_status(ProcessStepId::PrepareBenchmark),
        Some(ProcessStatus::Success)
    );
    assert_eq!(
        process.step_status(ProcessStepId::RunDnsBenchmark),
        Some(ProcessStatus::Running)
    );
    assert_eq!(
        process.step_status(ProcessStepId::RunTcpProbe),
        Some(ProcessStatus::Running)
    );
    assert_eq!(
        process.step_status(ProcessStepId::BuildDiagnostics),
        Some(ProcessStatus::Idle)
    );
    assert!(process
        .resolvers
        .iter()
        .all(|resolver| resolver.status == ProcessStatus::Running));
}

#[test]
fn progress_jsonl_parser_maps_running_success_and_failure_events() {
    let events = parse_progress_jsonl(
        r#"
{"event":"resolver_started","resolver_id":"cloudflare","resolver_label":"Cloudflare"}
ignored stderr line
{"event":"resolver_finished","resolver_id":"cloudflare","elapsed_ms":42}
{"event":"resolver_failed","resolver_id":"quad9","error":"DNS timeout"}
"#,
    );

    assert_eq!(events.len(), 3);
    assert_eq!(events[0].resolver_id, "cloudflare");
    assert_eq!(events[0].status, CoreCliProgressStatus::Running);
    assert_eq!(events[1].status, CoreCliProgressStatus::Success);
    assert!(events[1].detail.contains("42 ms"));
    assert_eq!(events[2].resolver_id, "quad9");
    assert_eq!(events[2].status, CoreCliProgressStatus::Failed);
    assert_eq!(events[2].detail, "DNS timeout");
}

#[test]
fn coordinator_updates_process_from_runner_progress_and_debug_report() {
    let capability = capability_view_model(probe(LinuxPackageKind::Flatpak));
    let runner = FakeRunner::success(
        r#"{"schema_version":1,"recommendation":{"profile_id":"cloudflare"}}"#,
        r#"
{"event":"resolver_started","resolver_id":"cloudflare"}
{"event":"resolver_finished","resolver_id":"cloudflare","elapsed_ms":12}
{"event":"resolver_failed","resolver_id":"quad9","error":"DNS timeout"}
"#,
    );

    let result = run_benchmark_with_runner(
        "dnspilot-cli",
        "Fedora Silverblue",
        capability,
        plan(BenchmarkMode::DnsAndTcp),
        &runner,
    );

    assert!(result.error.is_none());
    assert_eq!(runner.commands.borrow().len(), 1);
    assert_eq!(result.command.as_ref().unwrap().args[0], "path-compare");
    assert_eq!(
        result.process.step_status(ProcessStepId::RunDnsBenchmark),
        Some(ProcessStatus::Success)
    );
    assert_eq!(
        result.process.step_status(ProcessStepId::RunTcpProbe),
        Some(ProcessStatus::Success)
    );
    assert_eq!(result.process.resolvers[0].status, ProcessStatus::Success);
    assert_eq!(result.process.resolvers[1].status, ProcessStatus::Failed);
    assert!(result.final_payload.unwrap().contains("recommendation"));
    assert!(result.debug_report.contains("Distro: Fedora Silverblue"));
    assert!(result.debug_report.contains("Cloudflare: success - 12 ms"));
    assert!(result.debug_report.contains("Quad9: failed - DNS timeout"));
}

#[test]
fn coordinator_rejects_unsupported_mode_before_invoking_runner() {
    let capability = capability_view_model(probe(LinuxPackageKind::Flatpak));
    let runner = FakeRunner::success("{}", "");

    let result = run_benchmark_with_runner(
        "dnspilot-cli",
        "Ubuntu",
        capability,
        plan(BenchmarkMode::CurrentSystemResolver),
        &runner,
    );

    assert_eq!(runner.commands.borrow().len(), 0);
    assert!(result.command.is_none());
    assert!(result.error.unwrap().contains("not supported"));
    assert_eq!(result.process.overall_status(), ProcessStatus::Failed);
    assert!(result
        .debug_report
        .contains("Validate current resolver: failed"));
}

#[test]
fn coordinator_marks_run_step_failed_when_core_cli_exits_nonzero() {
    let mut capability_probe = probe(LinuxPackageKind::Deb);
    capability_probe.system_resolver_probe_available = true;
    let capability = capability_view_model(capability_probe);
    let runner = FakeRunner::failure("resolver stack unavailable");

    let result = run_benchmark_with_runner(
        "dnspilot-cli",
        "Ubuntu",
        capability,
        plan(BenchmarkMode::CurrentSystemResolver),
        &runner,
    );

    assert_eq!(runner.commands.borrow().len(), 1);
    assert!(result.final_payload.is_none());
    assert!(result.error.unwrap().contains("resolver stack unavailable"));
    assert_eq!(
        result
            .process
            .step_status(ProcessStepId::ValidateSystemResolver),
        Some(ProcessStatus::Failed)
    );
}

#[test]
fn coordinator_completes_resolvers_when_success_output_has_no_progress_events() {
    let capability = capability_view_model(probe(LinuxPackageKind::Flatpak));
    let runner = FakeRunner::success("{}", "");

    let result = run_benchmark_with_runner(
        "dnspilot-cli",
        "Ubuntu",
        capability,
        plan(BenchmarkMode::DnsOnly),
        &runner,
    );

    assert_eq!(result.process.overall_status(), ProcessStatus::Success);
    assert!(result
        .process
        .resolvers
        .iter()
        .all(|resolver| resolver.status == ProcessStatus::Success));
}

#[test]
fn coordinator_failure_leaves_no_running_or_idle_run_rows() {
    let capability = capability_view_model(probe(LinuxPackageKind::Flatpak));
    let runner = FakeRunner::failure("engine failed");

    let result = run_benchmark_with_runner(
        "dnspilot-cli",
        "Ubuntu",
        capability,
        plan(BenchmarkMode::DnsAndTcp),
        &runner,
    );

    assert!(result
        .process
        .steps
        .iter()
        .filter(|step| {
            matches!(
                step.id,
                ProcessStepId::RunDnsBenchmark | ProcessStepId::RunTcpProbe
            )
        })
        .all(|step| step.status == ProcessStatus::Failed));
    assert!(result
        .process
        .resolvers
        .iter()
        .all(|resolver| resolver.status == ProcessStatus::Failed));
}

#[test]
fn process_core_cli_runner_captures_stdout_stderr_and_exit_code() {
    let runner = ProcessCoreCliRunner;
    let output = runner.run(&CoreCliCommand {
        program: "/bin/sh".to_string(),
        args: vec![
            "-c".to_string(),
            "echo final-payload; echo progress-event >&2; exit 7".to_string(),
        ],
    });

    assert_eq!(output.exit_code, 7);
    assert_eq!(output.stdout.trim(), "final-payload");
    assert_eq!(output.stderr.trim(), "progress-event");
}

struct FakeRunner {
    output: CoreCliRunOutput,
    commands: RefCell<Vec<CoreCliCommand>>,
}

impl FakeRunner {
    fn success(stdout: &str, stderr: &str) -> Self {
        Self {
            output: CoreCliRunOutput {
                exit_code: 0,
                stdout: stdout.to_string(),
                stderr: stderr.to_string(),
            },
            commands: RefCell::new(Vec::new()),
        }
    }

    fn failure(stderr: &str) -> Self {
        Self {
            output: CoreCliRunOutput {
                exit_code: 1,
                stdout: String::new(),
                stderr: stderr.to_string(),
            },
            commands: RefCell::new(Vec::new()),
        }
    }
}

impl CoreCliRunner for FakeRunner {
    fn run(&self, command: &CoreCliCommand) -> CoreCliRunOutput {
        self.commands.borrow_mut().push(command.clone());
        self.output.clone()
    }
}
