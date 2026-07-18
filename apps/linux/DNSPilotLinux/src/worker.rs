use crate::benchmark::{
    build_core_cli_command, parse_progress_jsonl, CoreCliCommand, LinuxBenchmarkPlan,
    LinuxBenchmarkRunResult,
};
use crate::capabilities::{available_benchmark_modes, LinuxCapabilityViewModel};
use crate::diagnostics::LinuxDiagnosticReport;
use crate::process::{LinuxBenchmarkProcessViewModel, ProcessStepId};
use std::fmt;
use std::io::{BufRead, BufReader};
use std::os::unix::process::CommandExt;
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{self, Receiver, RecvTimeoutError, TryRecvError};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

const CANCELLATION_DETAIL: &str = "Benchmark cancelled";

#[derive(Debug)]
pub enum BenchmarkWorkerPoll {
    Running,
    Progress(LinuxBenchmarkProcessViewModel),
    Finished(LinuxBenchmarkRunResult),
    Disconnected,
}

#[derive(Debug)]
enum BenchmarkWorkerEvent {
    Progress(LinuxBenchmarkProcessViewModel),
    Finished(LinuxBenchmarkRunResult),
}

pub struct BenchmarkWorker {
    receiver: Receiver<BenchmarkWorkerEvent>,
    cancelled: Arc<AtomicBool>,
}

impl BenchmarkWorker {
    pub fn poll(&self) -> BenchmarkWorkerPoll {
        match self.receiver.try_recv() {
            Ok(BenchmarkWorkerEvent::Progress(process)) => BenchmarkWorkerPoll::Progress(process),
            Ok(BenchmarkWorkerEvent::Finished(result)) => BenchmarkWorkerPoll::Finished(result),
            Err(TryRecvError::Empty) => BenchmarkWorkerPoll::Running,
            Err(TryRecvError::Disconnected) => BenchmarkWorkerPoll::Disconnected,
        }
    }

    pub fn cancel(&self) {
        self.cancelled.store(true, Ordering::Release);
    }
}

#[derive(Debug)]
pub struct BenchmarkWorkerStartError {
    message: String,
}

impl fmt::Display for BenchmarkWorkerStartError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{}", self.message)
    }
}

impl std::error::Error for BenchmarkWorkerStartError {}

pub fn spawn_benchmark_worker(
    program: String,
    distro: String,
    capability: LinuxCapabilityViewModel,
    plan: LinuxBenchmarkPlan,
) -> Result<BenchmarkWorker, BenchmarkWorkerStartError> {
    let (sender, receiver) = mpsc::channel();
    let cancelled = Arc::new(AtomicBool::new(false));
    let worker_cancelled = Arc::clone(&cancelled);
    thread::Builder::new()
        .name("dnspilot-benchmark".to_string())
        .spawn(move || {
            let result = run_streaming_benchmark(
                program,
                distro,
                capability,
                plan,
                worker_cancelled,
                &sender,
            );
            let _ = sender.send(BenchmarkWorkerEvent::Finished(result));
        })
        .map_err(|error| BenchmarkWorkerStartError {
            message: format!("Could not start benchmark worker: {error}"),
        })?;

    Ok(BenchmarkWorker {
        receiver,
        cancelled,
    })
}

fn run_streaming_benchmark(
    program: String,
    distro: String,
    capability: LinuxCapabilityViewModel,
    plan: LinuxBenchmarkPlan,
    cancelled: Arc<AtomicBool>,
    events: &mpsc::Sender<BenchmarkWorkerEvent>,
) -> LinuxBenchmarkRunResult {
    let mut process = crate::benchmark::benchmark_process_for_plan(&plan);
    process.start_step(ProcessStepId::DetectCapabilities);
    process.complete_step(
        ProcessStepId::DetectCapabilities,
        "capability payload loaded",
    );

    if !available_benchmark_modes(&capability).contains(&plan.mode) {
        process.fail_unfinished("benchmark mode not supported by current capabilities");
        return completed_result(
            distro,
            capability,
            None,
            process,
            None,
            Some("benchmark mode not supported by current capabilities".to_string()),
        );
    }

    process.start_step(ProcessStepId::PrepareBenchmark);
    let command = build_core_cli_command(program, &plan);
    process.complete_step(ProcessStepId::PrepareBenchmark, "core CLI command prepared");
    for step in run_steps(plan.mode) {
        process.start_step(step);
    }
    for resolver in &mut process.resolvers {
        resolver.status = crate::process::ProcessStatus::Running;
    }
    let _ = events.send(BenchmarkWorkerEvent::Progress(process.clone()));

    let mut child_command = Command::new(&command.program);
    child_command
        .args(&command.args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .process_group(0);
    let mut child = match child_command.spawn() {
        Ok(child) => child,
        Err(error) => {
            let detail = format!("Could not start Core CLI: {error}");
            process.fail_unfinished(&detail);
            return completed_result(
                distro,
                capability,
                Some(command),
                process,
                None,
                Some(detail),
            );
        }
    };

    let stdout = child.stdout.take().expect("stdout is piped");
    let stderr = child.stderr.take().expect("stderr is piped");
    let (line_sender, line_receiver) = mpsc::channel();
    let stdout_reader = spawn_line_reader(stdout, StreamKind::Stdout, line_sender.clone());
    let stderr_reader = spawn_line_reader(stderr, StreamKind::Stderr, line_sender.clone());
    drop(line_sender);

    let mut stdout_payload = String::new();
    let mut stderr_payload = String::new();
    let mut cancellation_sent = false;
    let mut cancellation_started_at = None;
    let exit_status = loop {
        if cancelled.load(Ordering::Acquire) && !cancellation_sent {
            cancellation_sent = true;
            cancellation_started_at = Some(Instant::now());
            let _ = signal_process_group(child.id(), libc::SIGTERM);
        }
        if cancellation_started_at
            .is_some_and(|started_at| started_at.elapsed() >= Duration::from_millis(500))
        {
            let _ = signal_process_group(child.id(), libc::SIGKILL);
            cancellation_started_at = None;
        }

        match line_receiver.recv_timeout(Duration::from_millis(20)) {
            Ok(line) => apply_stream_line(
                &mut process,
                events,
                line,
                &mut stdout_payload,
                &mut stderr_payload,
            ),
            Err(RecvTimeoutError::Timeout) => {}
            Err(RecvTimeoutError::Disconnected) => {}
        }

        if let Ok(Some(status)) = child.try_wait() {
            break status;
        }
    };

    let _ = stdout_reader.join();
    let _ = stderr_reader.join();
    while let Ok(line) = line_receiver.try_recv() {
        apply_stream_line(
            &mut process,
            events,
            line,
            &mut stdout_payload,
            &mut stderr_payload,
        );
    }

    let error = if cancellation_sent {
        process.fail_unfinished(CANCELLATION_DETAIL);
        Some(CANCELLATION_DETAIL.to_string())
    } else if exit_status.success() {
        for step in run_steps(plan.mode) {
            process.complete_step(step, "core CLI completed");
        }
        process.complete_unfinished_resolvers("core CLI completed");
        None
    } else {
        let detail = if stderr_payload.trim().is_empty() {
            format!("core CLI exited with {exit_status}")
        } else {
            stderr_payload.trim().to_string()
        };
        process.fail_unfinished(&detail);
        Some(detail)
    };

    let mut result = completed_result(
        distro,
        capability,
        Some(command),
        process,
        error.is_none().then_some(stdout_payload),
        error,
    );
    if !stderr_payload.trim().is_empty() {
        result.debug_report.push_str("\n\nCore CLI stderr:\n");
        result.debug_report.push_str(stderr_payload.trim());
    }
    result
}

fn signal_process_group(process_id: u32, signal: libc::c_int) -> std::io::Result<()> {
    let result = unsafe { libc::kill(-(process_id as libc::pid_t), signal) };
    if result == 0 {
        Ok(())
    } else {
        Err(std::io::Error::last_os_error())
    }
}

#[derive(Debug, Clone, Copy)]
enum StreamKind {
    Stdout,
    Stderr,
}

#[derive(Debug)]
struct StreamLine {
    kind: StreamKind,
    text: String,
}

fn spawn_line_reader(
    stream: impl std::io::Read + Send + 'static,
    kind: StreamKind,
    sender: mpsc::Sender<StreamLine>,
) -> thread::JoinHandle<()> {
    thread::spawn(move || {
        for line in BufReader::new(stream).lines() {
            match line {
                Ok(text) => {
                    if sender.send(StreamLine { kind, text }).is_err() {
                        return;
                    }
                }
                Err(_) => return,
            }
        }
    })
}

fn apply_stream_line(
    process: &mut LinuxBenchmarkProcessViewModel,
    events: &mpsc::Sender<BenchmarkWorkerEvent>,
    line: StreamLine,
    stdout_payload: &mut String,
    stderr_payload: &mut String,
) {
    match line.kind {
        StreamKind::Stdout => {
            stdout_payload.push_str(&line.text);
            stdout_payload.push('\n');
        }
        StreamKind::Stderr => {
            stderr_payload.push_str(&line.text);
            stderr_payload.push('\n');
            let mut updated = false;
            for event in parse_progress_jsonl(&line.text) {
                match event.status {
                    crate::benchmark::CoreCliProgressStatus::Running => {
                        process.start_resolver(&event.resolver_id)
                    }
                    crate::benchmark::CoreCliProgressStatus::Success => {
                        process.complete_resolver(&event.resolver_id, event.detail)
                    }
                    crate::benchmark::CoreCliProgressStatus::Failed => {
                        process.fail_resolver(&event.resolver_id, event.detail)
                    }
                }
                updated = true;
            }
            if updated {
                let _ = events.send(BenchmarkWorkerEvent::Progress(process.clone()));
            }
        }
    }
}

fn completed_result(
    distro: String,
    capability: LinuxCapabilityViewModel,
    command: Option<CoreCliCommand>,
    mut process: LinuxBenchmarkProcessViewModel,
    final_payload: Option<String>,
    error: Option<String>,
) -> LinuxBenchmarkRunResult {
    process.start_step(ProcessStepId::BuildDiagnostics);
    process.complete_step(ProcessStepId::BuildDiagnostics, "debug report rendered");
    let debug_report =
        LinuxDiagnosticReport::new(distro, capability, process.clone()).to_copyable_text();
    LinuxBenchmarkRunResult {
        command,
        process,
        final_payload,
        error,
        debug_report,
    }
}

fn run_steps(mode: crate::capabilities::BenchmarkMode) -> Vec<ProcessStepId> {
    match mode {
        crate::capabilities::BenchmarkMode::DnsOnly => vec![ProcessStepId::RunDnsBenchmark],
        crate::capabilities::BenchmarkMode::DnsAndTcp => {
            vec![ProcessStepId::RunDnsBenchmark, ProcessStepId::RunTcpProbe]
        }
        crate::capabilities::BenchmarkMode::CurrentSystemResolver => {
            vec![ProcessStepId::ValidateSystemResolver]
        }
    }
}
