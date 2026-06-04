use rustls::pki_types::ServerName;
use rustls::{ClientConfig, ClientConnection, RootCertStore};
use std::io;
use std::net::TcpStream;
use std::sync::Arc;
use std::net::SocketAddr;
use std::time::{Duration, Instant};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TlsHandshakeTarget {
    pub domain: String,
    pub server_name: String,
    pub endpoint: SocketAddr,
}

#[derive(Debug, Clone)]
pub struct TlsProbeConfig {
    pub targets: Vec<TlsHandshakeTarget>,
    pub attempts_per_target: usize,
    pub timeout: Duration,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TlsProbeRun {
    pub median_tls_handshake_latency_ms: f64,
    pub p95_tls_handshake_latency_ms: f64,
    pub failure_rate: f64,
    pub timeout_rate: f64,
    pub certificate_failure_rate: f64,
    pub samples: Vec<TlsProbeSample>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TlsProbeSample {
    pub domain: String,
    pub server_name: String,
    pub endpoint: SocketAddr,
    pub elapsed: Option<Duration>,
    pub outcome: TlsProbeOutcome,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TlsProbeOutcome {
    Success,
    Timeout,
    CertificateFailure,
    HandshakeFailure,
}

#[derive(Debug, thiserror::Error)]
pub enum TlsProbeError {
    #[error("TLS handshake timed out")]
    Timeout,
    #[error("TLS certificate rejected")]
    CertificateRejected,
    #[error("TLS handshake failed: {0}")]
    HandshakeFailed(String),
}

pub fn default_tls_client_config() -> Arc<ClientConfig> {
    let root_store = RootCertStore::from_iter(webpki_roots::TLS_SERVER_ROOTS.iter().cloned());
    Arc::new(
        ClientConfig::builder()
            .with_root_certificates(root_store)
            .with_no_client_auth(),
    )
}

pub fn probe_tls_handshake_once(
    target: &TlsHandshakeTarget,
    timeout: Duration,
) -> Result<Duration, TlsProbeError> {
    probe_tls_handshake_once_with_config(target, timeout, default_tls_client_config())
}

pub fn probe_tls_handshake_once_with_config(
    target: &TlsHandshakeTarget,
    timeout: Duration,
    client_config: Arc<ClientConfig>,
) -> Result<Duration, TlsProbeError> {
    let started = Instant::now();
    let mut tcp = TcpStream::connect_timeout(&target.endpoint, timeout).map_err(map_io_error)?;
    tcp.set_read_timeout(Some(timeout)).map_err(map_io_error)?;
    tcp.set_write_timeout(Some(timeout)).map_err(map_io_error)?;

    let server_name = ServerName::try_from(target.server_name.clone())
        .map_err(|_| TlsProbeError::HandshakeFailed("invalid SNI server name".into()))?;
    let mut connection = ClientConnection::new(client_config, server_name)
        .map_err(|error| map_rustls_error(&error))?;

    while connection.is_handshaking() {
        connection
            .complete_io(&mut tcp)
            .map_err(map_tls_io_error)?;
    }

    Ok(started.elapsed())
}

pub fn run_tls_handshake_probes(config: &TlsProbeConfig) -> TlsProbeRun {
    let client_config = default_tls_client_config();
    run_tls_handshake_probes_with_handshaker(config, |target| {
        probe_tls_handshake_once_with_config(target, config.timeout, client_config.clone())
    })
}

pub fn run_tls_handshake_probes_with_handshaker<F>(
    config: &TlsProbeConfig,
    mut handshaker: F,
) -> TlsProbeRun
where
    F: FnMut(&TlsHandshakeTarget) -> Result<Duration, TlsProbeError>,
{
    let mut samples = Vec::new();

    for target in &config.targets {
        for _ in 0..config.attempts_per_target {
            let sample = match handshaker(target) {
                Ok(elapsed) => TlsProbeSample {
                    domain: target.domain.clone(),
                    server_name: target.server_name.clone(),
                    endpoint: target.endpoint,
                    elapsed: Some(elapsed),
                    outcome: TlsProbeOutcome::Success,
                },
                Err(TlsProbeError::Timeout) => TlsProbeSample {
                    domain: target.domain.clone(),
                    server_name: target.server_name.clone(),
                    endpoint: target.endpoint,
                    elapsed: None,
                    outcome: TlsProbeOutcome::Timeout,
                },
                Err(TlsProbeError::CertificateRejected) => TlsProbeSample {
                    domain: target.domain.clone(),
                    server_name: target.server_name.clone(),
                    endpoint: target.endpoint,
                    elapsed: None,
                    outcome: TlsProbeOutcome::CertificateFailure,
                },
                Err(TlsProbeError::HandshakeFailed(_)) => TlsProbeSample {
                    domain: target.domain.clone(),
                    server_name: target.server_name.clone(),
                    endpoint: target.endpoint,
                    elapsed: None,
                    outcome: TlsProbeOutcome::HandshakeFailure,
                },
            };
            samples.push(sample);
        }
    }

    summarize(samples)
}

fn summarize(samples: Vec<TlsProbeSample>) -> TlsProbeRun {
    let total = samples.len() as f64;
    let successful_latencies: Vec<f64> = samples
        .iter()
        .filter_map(|sample| sample.elapsed.map(duration_ms))
        .collect();
    let failure_count = samples
        .iter()
        .filter(|sample| sample.outcome != TlsProbeOutcome::Success)
        .count() as f64;
    let timeout_count = samples
        .iter()
        .filter(|sample| sample.outcome == TlsProbeOutcome::Timeout)
        .count() as f64;
    let certificate_failure_count = samples
        .iter()
        .filter(|sample| sample.outcome == TlsProbeOutcome::CertificateFailure)
        .count() as f64;

    TlsProbeRun {
        median_tls_handshake_latency_ms: median(&successful_latencies),
        p95_tls_handshake_latency_ms: percentile_95(&successful_latencies),
        failure_rate: rate(failure_count, total),
        timeout_rate: rate(timeout_count, total),
        certificate_failure_rate: rate(certificate_failure_count, total),
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

fn map_tls_io_error(error: io::Error) -> TlsProbeError {
    if let Some(rustls_error) = error
        .get_ref()
        .and_then(|inner| inner.downcast_ref::<rustls::Error>())
    {
        return map_rustls_error(rustls_error);
    }

    map_io_error(error)
}

fn map_rustls_error(error: &rustls::Error) -> TlsProbeError {
    match error {
        rustls::Error::InvalidCertificate(_) | rustls::Error::NoCertificatesPresented => {
            TlsProbeError::CertificateRejected
        }
        _ => TlsProbeError::HandshakeFailed(error.to_string()),
    }
}

fn map_io_error(error: io::Error) -> TlsProbeError {
    if matches!(
        error.kind(),
        io::ErrorKind::TimedOut | io::ErrorKind::WouldBlock
    ) {
        TlsProbeError::Timeout
    } else {
        TlsProbeError::HandshakeFailed(error.to_string())
    }
}
