use dnspilot_core::dns_resolver::{query_udp_once, DnsResolverError};
use dnspilot_core::dns_wire::{DnsRecordData, RecordType};
use std::net::{Ipv4Addr, UdpSocket};
use std::thread;
use std::time::Duration;

#[test]
fn resolves_a_record_from_local_udp_resolver() {
    let resolver = start_fake_resolver(|request| {
        let mut response = vec![
            request[0], request[1], 0x81, 0x80, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00,
        ];
        response.extend(&request[12..]);
        response.extend([
            0xc0, 0x0c, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x1e, 0x00, 0x04, 93, 184, 216,
            34,
        ]);
        response
    });

    let result = query_udp_once(
        resolver,
        "example.com",
        RecordType::A,
        Duration::from_millis(500),
        0x4444,
    )
    .expect("local resolver should respond");

    assert_eq!(result.response.transaction_id, 0x4444);
    assert_eq!(
        result.response.answers[0].data,
        DnsRecordData::A(Ipv4Addr::new(93, 184, 216, 34))
    );
    assert!(result.elapsed < Duration::from_millis(500));
}

#[test]
fn rejects_response_with_wrong_transaction_id() {
    let resolver = start_fake_resolver(|request| {
        let mut response = vec![
            0x99, 0x99, 0x81, 0x80, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ];
        response.extend(&request[12..]);
        response
    });

    let error = query_udp_once(
        resolver,
        "example.com",
        RecordType::A,
        Duration::from_millis(500),
        0x4444,
    )
    .expect_err("mismatched transaction should be rejected");

    assert!(matches!(
        error,
        DnsResolverError::TransactionMismatch {
            expected: 0x4444,
            actual: 0x9999
        }
    ));
}

#[test]
fn reports_timeout_when_resolver_does_not_reply() {
    let socket = UdpSocket::bind("127.0.0.1:0").expect("bind unused local UDP port");
    let resolver = socket.local_addr().expect("local addr");
    drop(socket);

    let error = query_udp_once(
        resolver,
        "example.com",
        RecordType::A,
        Duration::from_millis(20),
        0x4444,
    )
    .expect_err("closed UDP port should time out or be unreachable");

    assert!(matches!(
        error,
        DnsResolverError::Timeout | DnsResolverError::Io(_)
    ));
}

#[test]
fn rejects_response_with_wrong_question() {
    let resolver = start_fake_resolver(|request| {
        let mut response = vec![
            request[0], request[1], 0x81, 0x80, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ];
        response.extend([
            5, b'o', b't', b'h', b'e', b'r', 3, b'c', b'o', b'm', 0, 0, 1, 0, 1,
        ]);
        response
    });

    assert!(
        query_udp_once(
            resolver,
            "example.com",
            RecordType::A,
            Duration::from_millis(500),
            0x4444,
        )
        .is_err(),
        "a response for another DNS question must not count as a successful lookup"
    );
}

#[test]
fn ignores_response_from_an_unconnected_source() {
    let resolver_socket = UdpSocket::bind("127.0.0.1:0").expect("bind fake resolver");
    let resolver = resolver_socket.local_addr().expect("resolver address");

    thread::spawn(move || {
        let mut buffer = [0_u8; 512];
        let (length, peer) = resolver_socket
            .recv_from(&mut buffer)
            .expect("receive DNS query");
        let request = &buffer[..length];
        let attacker = UdpSocket::bind("127.0.0.1:0").expect("bind attacker socket");
        let mut response = vec![
            request[0], request[1], 0x81, 0x80, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ];
        response.extend(&request[12..]);
        attacker
            .send_to(&response, peer)
            .expect("send forged DNS response");
    });

    let error = query_udp_once(
        resolver,
        "example.com",
        RecordType::A,
        Duration::from_millis(100),
        0x4444,
    )
    .expect_err("only the selected resolver may satisfy a DNS query");

    assert!(matches!(
        error,
        DnsResolverError::Timeout | DnsResolverError::Io(_)
    ));
}

fn start_fake_resolver(response_for: fn(&[u8]) -> Vec<u8>) -> std::net::SocketAddr {
    let socket = UdpSocket::bind("127.0.0.1:0").expect("bind fake resolver");
    let addr = socket.local_addr().expect("local addr");

    thread::spawn(move || {
        let mut buffer = [0_u8; 512];
        let (length, peer) = socket.recv_from(&mut buffer).expect("receive DNS query");
        let response = response_for(&buffer[..length]);
        socket
            .send_to(&response, peer)
            .expect("send fake DNS response");
    });

    addr
}
