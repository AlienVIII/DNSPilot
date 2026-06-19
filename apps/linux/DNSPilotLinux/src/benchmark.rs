use crate::capabilities::{available_benchmark_modes, BenchmarkMode, LinuxCapabilityViewModel};
use crate::diagnostics::LinuxDiagnosticReport;
use crate::process::{LinuxBenchmarkProcessViewModel, ProcessStepId};
use crate::settings::DnsRecordFamily;
use serde_json::Value;
use std::process::Command;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ResolverSelection {
    pub id: String,
    pub label: String,
    pub resolver_spec: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LinuxBenchmarkPlan {
    pub mode: BenchmarkMode,
    pub package_platform: String,
    pub resolvers: Vec<ResolverSelection>,
    pub domains: Vec<String>,
    pub suite_id: Option<String>,
    pub suite_db: Option<String>,
    pub profile_db: Option<String>,
    pub attempts: u16,
    pub record_family: DnsRecordFamily,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CoreCliCommand {
    pub program: String,
    pub args: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CoreCliRunOutput {
    pub exit_code: i32,
    pub stdout: String,
    pub stderr: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CoreCliProgressStatus {
    Running,
    Success,
    Failed,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CoreCliProgressEvent {
    pub resolver_id: String,
    pub status: CoreCliProgressStatus,
    pub detail: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LinuxBenchmarkRunResult {
    pub command: Option<CoreCliCommand>,
    pub process: LinuxBenchmarkProcessViewModel,
    pub final_payload: Option<String>,
    pub error: Option<String>,
    pub debug_report: String,
}

pub trait CoreCliRunner {
    fn run(&self, command: &CoreCliCommand) -> CoreCliRunOutput;
}

#[derive(Debug, Default, Clone, Copy, PartialEq, Eq)]
pub struct ProcessCoreCliRunner;

impl CoreCliRunner for ProcessCoreCliRunner {
    fn run(&self, command: &CoreCliCommand) -> CoreCliRunOutput {
        match Command::new(&command.program).args(&command.args).output() {
            Ok(output) => CoreCliRunOutput {
                exit_code: output.status.code().unwrap_or(1),
                stdout: String::from_utf8_lossy(&output.stdout).to_string(),
                stderr: String::from_utf8_lossy(&output.stderr).to_string(),
            },
            Err(error) => CoreCliRunOutput {
                exit_code: 1,
                stdout: String::new(),
                stderr: error.to_string(),
            },
        }
    }
}

pub fn build_core_cli_command(
    program: impl Into<String>,
    plan: &LinuxBenchmarkPlan,
) -> CoreCliCommand {
    let mut args = match plan.mode {
        BenchmarkMode::DnsOnly => vec!["compare".to_string()],
        BenchmarkMode::DnsAndTcp => vec!["path-compare".to_string()],
        BenchmarkMode::CurrentSystemResolver => vec!["system-benchmark".to_string()],
    };

    match plan.mode {
        BenchmarkMode::DnsOnly | BenchmarkMode::DnsAndTcp => {
            for resolver in &plan.resolvers {
                push_pair(&mut args, "--resolver", &resolver.resolver_spec);
            }
            if let Some(profile_db) = &plan.profile_db {
                push_pair(&mut args, "--profile-db", profile_db);
            }
            push_common_benchmark_args(&mut args, plan);
            args.push("--progress-jsonl".to_string());
        }
        BenchmarkMode::CurrentSystemResolver => {
            push_pair(&mut args, "--platform", &plan.package_platform);
            push_common_benchmark_args(&mut args, plan);
        }
    }

    CoreCliCommand {
        program: program.into(),
        args,
    }
}

pub fn parse_progress_jsonl(stderr: &str) -> Vec<CoreCliProgressEvent> {
    stderr
        .lines()
        .filter_map(|line| parse_progress_line(line.trim()))
        .collect()
}

pub fn run_benchmark_with_runner(
    program: impl Into<String>,
    distro: impl Into<String>,
    capability: LinuxCapabilityViewModel,
    plan: LinuxBenchmarkPlan,
    runner: &dyn CoreCliRunner,
) -> LinuxBenchmarkRunResult {
    let mut process = process_for_plan(&plan);
    process.start_step(ProcessStepId::DetectCapabilities);
    process.complete_step(
        ProcessStepId::DetectCapabilities,
        "capability payload loaded",
    );

    if !available_benchmark_modes(&capability).contains(&plan.mode) {
        let failed_step = primary_run_step(plan.mode);
        process.fail_step(
            failed_step,
            "benchmark mode not supported by current capabilities",
        );
        let debug_report =
            LinuxDiagnosticReport::new(distro, capability, process.clone()).to_copyable_text();
        return LinuxBenchmarkRunResult {
            command: None,
            process,
            final_payload: None,
            error: Some("benchmark mode not supported by current capabilities".to_string()),
            debug_report,
        };
    }

    process.start_step(ProcessStepId::PrepareBenchmark);
    let command = build_core_cli_command(program, &plan);
    process.complete_step(ProcessStepId::PrepareBenchmark, "core CLI command prepared");

    for step in run_steps(plan.mode) {
        process.start_step(step);
    }
    let output = runner.run(&command);
    for event in parse_progress_jsonl(&output.stderr) {
        match event.status {
            CoreCliProgressStatus::Running => {}
            CoreCliProgressStatus::Success => {
                process.complete_resolver(&event.resolver_id, event.detail);
            }
            CoreCliProgressStatus::Failed => {
                process.fail_resolver(&event.resolver_id, event.detail);
            }
        }
    }

    let error = if output.exit_code == 0 {
        for step in run_steps(plan.mode) {
            process.complete_step(step, "core CLI completed");
        }
        None
    } else {
        let detail = if output.stderr.trim().is_empty() {
            format!("core CLI exited with {}", output.exit_code)
        } else {
            output.stderr.trim().to_string()
        };
        process.fail_step(primary_run_step(plan.mode), detail.clone());
        Some(detail)
    };

    process.start_step(ProcessStepId::BuildDiagnostics);
    process.complete_step(ProcessStepId::BuildDiagnostics, "debug report rendered");
    let debug_report =
        LinuxDiagnosticReport::new(distro, capability, process.clone()).to_copyable_text();

    LinuxBenchmarkRunResult {
        command: Some(command),
        process,
        final_payload: (output.exit_code == 0).then_some(output.stdout),
        error,
        debug_report,
    }
}

fn push_common_benchmark_args(args: &mut Vec<String>, plan: &LinuxBenchmarkPlan) {
    for domain in &plan.domains {
        push_pair(args, "--domain", domain);
    }
    if let Some(suite_db) = &plan.suite_db {
        push_pair(args, "--suite-db", suite_db);
    }
    if let Some(suite_id) = &plan.suite_id {
        push_pair(args, "--suite-id", suite_id);
    }
    push_pair(args, "--attempts", &plan.attempts.to_string());
    push_pair(
        args,
        "--ip-family",
        record_family_cli_value(plan.record_family),
    );
}

fn push_pair(args: &mut Vec<String>, name: &str, value: &str) {
    args.push(name.to_string());
    args.push(value.to_string());
}

fn record_family_cli_value(record_family: DnsRecordFamily) -> &'static str {
    match record_family {
        DnsRecordFamily::AAndAaaa => "both",
        DnsRecordFamily::AOnly => "ipv4-only",
        DnsRecordFamily::AaaaOnly => "ipv6-only",
    }
}

fn parse_progress_line(line: &str) -> Option<CoreCliProgressEvent> {
    if line.is_empty() {
        return None;
    }
    let value = serde_json::from_str::<Value>(line).ok()?;
    let event = value.get("event")?.as_str()?;
    let resolver_id = value
        .get("resolver_id")
        .or_else(|| value.get("profile_id"))?
        .as_str()?
        .to_string();

    match event {
        "resolver_started" => Some(CoreCliProgressEvent {
            resolver_id,
            status: CoreCliProgressStatus::Running,
            detail: "running".to_string(),
        }),
        "resolver_finished" => Some(CoreCliProgressEvent {
            resolver_id,
            status: CoreCliProgressStatus::Success,
            detail: value
                .get("elapsed_ms")
                .and_then(Value::as_u64)
                .map(|elapsed| format!("{elapsed} ms"))
                .unwrap_or_else(|| "finished".to_string()),
        }),
        "resolver_failed" => Some(CoreCliProgressEvent {
            resolver_id,
            status: CoreCliProgressStatus::Failed,
            detail: value
                .get("error")
                .and_then(Value::as_str)
                .unwrap_or("failed")
                .to_string(),
        }),
        _ => None,
    }
}

fn process_for_plan(plan: &LinuxBenchmarkPlan) -> LinuxBenchmarkProcessViewModel {
    let resolvers =
        if plan.mode == BenchmarkMode::CurrentSystemResolver && plan.resolvers.is_empty() {
            vec![("system", "Current system resolver")]
        } else {
            plan.resolvers
                .iter()
                .map(|resolver| (resolver.id.as_str(), resolver.label.as_str()))
                .collect()
        };
    LinuxBenchmarkProcessViewModel::new(plan.mode, resolvers)
}

fn run_steps(mode: BenchmarkMode) -> Vec<ProcessStepId> {
    match mode {
        BenchmarkMode::DnsOnly => vec![ProcessStepId::RunDnsBenchmark],
        BenchmarkMode::DnsAndTcp => {
            vec![ProcessStepId::RunDnsBenchmark, ProcessStepId::RunTcpProbe]
        }
        BenchmarkMode::CurrentSystemResolver => vec![ProcessStepId::ValidateSystemResolver],
    }
}

fn primary_run_step(mode: BenchmarkMode) -> ProcessStepId {
    match mode {
        BenchmarkMode::DnsOnly | BenchmarkMode::DnsAndTcp => ProcessStepId::RunDnsBenchmark,
        BenchmarkMode::CurrentSystemResolver => ProcessStepId::ValidateSystemResolver,
    }
}
