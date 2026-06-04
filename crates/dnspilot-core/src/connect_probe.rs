use std::io;
use std::net::{SocketAddr, TcpStream};
use std::time::{Duration, Instant};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TcpConnectTarget {
    pub domain: String,
    pub endpoint: SocketAddr,
}

#[derive(Debug, Clone)]
pub struct ConnectProbeConfig {
    pub targets: Vec<TcpConnectTarget>,
    pub attempts_per_target: usize,
    pub timeout: Duration,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ConnectProbeRun {
    pub median_connect_latency_ms: f64,
    pub p95_connect_latency_ms: f64,
    pub failure_rate: f64,
    pub timeout_rate: f64,
    pub samples: Vec<ConnectProbeSample>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ConnectProbeSample {
    pub domain: String,
    pub endpoint: SocketAddr,
    pub elapsed: Option<Duration>,
    pub outcome: ConnectProbeOutcome,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConnectProbeOutcome {
    Success,
    Timeout,
    Failure,
}

#[derive(Debug, thiserror::Error)]
pub enum ConnectProbeError {
    #[error("TCP connect timed out")]
    Timeout,
    #[error(transparent)]
    Io(#[from] io::Error),
}

pub fn probe_tcp_connect_once(
    target: &TcpConnectTarget,
    timeout: Duration,
) -> Result<Duration, ConnectProbeError> {
    let started = Instant::now();
    match TcpStream::connect_timeout(&target.endpoint, timeout) {
        Ok(stream) => {
            drop(stream);
            Ok(started.elapsed())
        }
        Err(error)
            if matches!(
                error.kind(),
                io::ErrorKind::TimedOut | io::ErrorKind::WouldBlock
            ) =>
        {
            Err(ConnectProbeError::Timeout)
        }
        Err(error) => Err(ConnectProbeError::Io(error)),
    }
}

pub fn run_tcp_connect_probes(config: &ConnectProbeConfig) -> ConnectProbeRun {
    run_tcp_connect_probes_with_connector(config, |target| {
        probe_tcp_connect_once(target, config.timeout)
    })
}

pub fn run_tcp_connect_probes_with_connector<F>(
    config: &ConnectProbeConfig,
    mut connector: F,
) -> ConnectProbeRun
where
    F: FnMut(&TcpConnectTarget) -> Result<Duration, ConnectProbeError>,
{
    let mut samples = Vec::new();

    for target in &config.targets {
        for _ in 0..config.attempts_per_target {
            let sample = match connector(target) {
                Ok(elapsed) => ConnectProbeSample {
                    domain: target.domain.clone(),
                    endpoint: target.endpoint,
                    elapsed: Some(elapsed),
                    outcome: ConnectProbeOutcome::Success,
                },
                Err(ConnectProbeError::Timeout) => ConnectProbeSample {
                    domain: target.domain.clone(),
                    endpoint: target.endpoint,
                    elapsed: None,
                    outcome: ConnectProbeOutcome::Timeout,
                },
                Err(_) => ConnectProbeSample {
                    domain: target.domain.clone(),
                    endpoint: target.endpoint,
                    elapsed: None,
                    outcome: ConnectProbeOutcome::Failure,
                },
            };
            samples.push(sample);
        }
    }

    summarize(samples)
}

fn summarize(samples: Vec<ConnectProbeSample>) -> ConnectProbeRun {
    let total = samples.len() as f64;
    let successful_latencies: Vec<f64> = samples
        .iter()
        .filter_map(|sample| sample.elapsed.map(duration_ms))
        .collect();
    let failure_count = samples
        .iter()
        .filter(|sample| sample.outcome != ConnectProbeOutcome::Success)
        .count() as f64;
    let timeout_count = samples
        .iter()
        .filter(|sample| sample.outcome == ConnectProbeOutcome::Timeout)
        .count() as f64;

    ConnectProbeRun {
        median_connect_latency_ms: median(&successful_latencies),
        p95_connect_latency_ms: percentile_95(&successful_latencies),
        failure_rate: rate(failure_count, total),
        timeout_rate: rate(timeout_count, total),
        samples,
    }
}

fn median(values: &[f64]) -> f64 {
    let sorted = sorted_finite(values);
    if sorted.is_empty() {
        return f64::INFINITY;
    }

    let middle = sorted.len() / 2;
    if sorted.len() % 2 == 0 {
        (sorted[middle - 1] + sorted[middle]) / 2.0
    } else {
        sorted[middle]
    }
}

fn percentile_95(values: &[f64]) -> f64 {
    let sorted = sorted_finite(values);
    if sorted.is_empty() {
        return f64::INFINITY;
    }

    let rank = ((sorted.len() as f64) * 0.95).ceil() as usize;
    let index = rank.saturating_sub(1).min(sorted.len() - 1);
    sorted[index]
}

fn sorted_finite(values: &[f64]) -> Vec<f64> {
    let mut sorted: Vec<f64> = values
        .iter()
        .copied()
        .filter(|value| value.is_finite())
        .collect();
    sorted.sort_by(f64::total_cmp);
    sorted
}

fn duration_ms(duration: Duration) -> f64 {
    duration.as_secs_f64() * 1000.0
}

fn rate(numerator: f64, denominator: f64) -> f64 {
    if denominator == 0.0 {
        0.0
    } else {
        numerator / denominator
    }
}

