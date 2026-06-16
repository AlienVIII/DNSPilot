use crate::dns_benchmark::{run_dns_benchmark_with_lookup, DnsBenchmarkConfig, DnsBenchmarkRun};
use crate::dns_resolver::DnsResolverError;
use crate::dns_wire::RecordType;
use std::io;
use std::net::{IpAddr, ToSocketAddrs};
use std::sync::mpsc;
use std::thread;
use std::time::{Duration, Instant};

pub fn run_system_dns_benchmark(config: &DnsBenchmarkConfig) -> DnsBenchmarkRun {
    run_dns_benchmark_with_lookup(config, |domain, record_type, _transaction_id| {
        query_system_dns_once(domain, record_type, config.timeout)
    })
}

pub fn query_system_dns_once(
    domain: &str,
    record_type: RecordType,
    timeout: Duration,
) -> Result<Duration, DnsResolverError> {
    let started = Instant::now();
    let (sender, receiver) = mpsc::channel();
    let domain = domain.to_string();

    thread::spawn(move || {
        let result = (domain.as_str(), 0)
            .to_socket_addrs()
            .map(|addresses| addresses.map(|address| address.ip()).collect::<Vec<_>>());
        let _ = sender.send(result);
    });

    let addresses = match receiver.recv_timeout(timeout) {
        Ok(Ok(addresses)) => addresses,
        Ok(Err(error)) => return Err(DnsResolverError::Io(error)),
        Err(mpsc::RecvTimeoutError::Timeout) => return Err(DnsResolverError::Timeout),
        Err(mpsc::RecvTimeoutError::Disconnected) => {
            return Err(DnsResolverError::Io(io::Error::new(
                io::ErrorKind::BrokenPipe,
                "system DNS lookup worker disconnected",
            )));
        }
    };

    if addresses
        .iter()
        .any(|address| matches_record_type(*address, record_type))
    {
        Ok(started.elapsed())
    } else {
        Err(DnsResolverError::Io(io::Error::new(
            io::ErrorKind::NotFound,
            format!(
                "system DNS returned no {} address",
                match record_type {
                    RecordType::A => "IPv4",
                    RecordType::Aaaa => "IPv6",
                }
            ),
        )))
    }
}

fn matches_record_type(address: IpAddr, record_type: RecordType) -> bool {
    match record_type {
        RecordType::A => address.is_ipv4(),
        RecordType::Aaaa => address.is_ipv6(),
    }
}
