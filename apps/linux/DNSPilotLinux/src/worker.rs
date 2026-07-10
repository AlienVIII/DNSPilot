use crate::benchmark::{
    run_benchmark_with_runner, CoreCliRunner, LinuxBenchmarkPlan, LinuxBenchmarkRunResult,
};
use crate::capabilities::LinuxCapabilityViewModel;
use std::fmt;
use std::sync::mpsc::{self, Receiver, TryRecvError};
use std::thread;

#[derive(Debug)]
pub enum BenchmarkWorkerPoll {
    Running,
    Finished(LinuxBenchmarkRunResult),
    Disconnected,
}

pub struct BenchmarkWorker {
    receiver: Receiver<LinuxBenchmarkRunResult>,
}

impl BenchmarkWorker {
    pub fn poll(&self) -> BenchmarkWorkerPoll {
        match self.receiver.try_recv() {
            Ok(result) => BenchmarkWorkerPoll::Finished(result),
            Err(TryRecvError::Empty) => BenchmarkWorkerPoll::Running,
            Err(TryRecvError::Disconnected) => BenchmarkWorkerPoll::Disconnected,
        }
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

pub fn spawn_benchmark_worker<R>(
    program: String,
    distro: String,
    capability: LinuxCapabilityViewModel,
    plan: LinuxBenchmarkPlan,
    runner: R,
) -> Result<BenchmarkWorker, BenchmarkWorkerStartError>
where
    R: CoreCliRunner + Send + 'static,
{
    let (sender, receiver) = mpsc::sync_channel(1);
    thread::Builder::new()
        .name("dnspilot-benchmark".to_string())
        .spawn(move || {
            let result = run_benchmark_with_runner(program, distro, capability, plan, &runner);
            let _ = sender.send(result);
        })
        .map_err(|error| BenchmarkWorkerStartError {
            message: format!("Could not start benchmark worker: {error}"),
        })?;

    Ok(BenchmarkWorker { receiver })
}
