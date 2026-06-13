use crate::dns_wire::{build_query, parse_response, DnsResponse, DnsWireError, RecordType};
use std::io;
use std::net::{SocketAddr, UdpSocket};
use std::time::{Duration, Instant};

#[derive(Debug)]
pub struct UdpLookupResult {
    pub response: DnsResponse,
    pub elapsed: Duration,
}

#[derive(Debug, thiserror::Error)]
pub enum DnsResolverError {
    #[error("DNS query timed out")]
    Timeout,
    #[error("DNS response transaction ID mismatch: expected {expected:#06x}, got {actual:#06x}")]
    TransactionMismatch { expected: u16, actual: u16 },
    #[error("DNS resolver returned response code {0}")]
    ResponseCode(u8),
    #[error(transparent)]
    Wire(#[from] DnsWireError),
    #[error(transparent)]
    Io(#[from] io::Error),
}

pub fn query_udp_once(
    resolver: SocketAddr,
    domain: &str,
    record_type: RecordType,
    timeout: Duration,
    transaction_id: u16,
) -> Result<UdpLookupResult, DnsResolverError> {
    let query = build_query(transaction_id, domain, record_type)?;
    let bind_addr = if resolver.is_ipv4() {
        "0.0.0.0:0"
    } else {
        "[::]:0"
    };
    let socket = UdpSocket::bind(bind_addr)?;
    socket.set_read_timeout(Some(timeout))?;
    socket.set_write_timeout(Some(timeout))?;

    let started = Instant::now();
    socket.send_to(&query, resolver)?;

    let mut buffer = [0_u8; 1232];
    let (length, _) = match socket.recv_from(&mut buffer) {
        Ok(received) => received,
        Err(error)
            if matches!(
                error.kind(),
                io::ErrorKind::WouldBlock | io::ErrorKind::TimedOut
            ) =>
        {
            return Err(DnsResolverError::Timeout);
        }
        Err(error) => return Err(DnsResolverError::Io(error)),
    };

    let elapsed = started.elapsed();
    let response = parse_response(&buffer[..length])?;

    if response.transaction_id != transaction_id {
        return Err(DnsResolverError::TransactionMismatch {
            expected: transaction_id,
            actual: response.transaction_id,
        });
    }

    if response.response_code != 0 {
        return Err(DnsResolverError::ResponseCode(response.response_code));
    }

    Ok(UdpLookupResult { response, elapsed })
}
