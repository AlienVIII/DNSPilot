use dnspilot_core::dns_wire::{build_query, parse_response, DnsRecordData, RecordType};
use std::net::{Ipv4Addr, Ipv6Addr};

fn github_question() -> Vec<u8> {
    vec![
        6, b'g', b'i', b't', b'h', b'u', b'b', 3, b'c', b'o', b'm', 0, 0, 1, 0, 1,
    ]
}

#[test]
fn builds_plain_dns_a_query_packet() {
    let packet = build_query(0x1234, "github.com", RecordType::A).expect("query packet");

    assert_eq!(&packet[0..2], &[0x12, 0x34]);
    assert_eq!(&packet[2..4], &[0x01, 0x00]);
    assert_eq!(&packet[4..6], &[0x00, 0x01]);
    assert_eq!(&packet[12..], github_question().as_slice());
}

#[test]
fn parses_compressed_a_response() {
    let mut response = vec![
        0x12, 0x34, 0x81, 0x80, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00,
    ];
    response.extend(github_question());
    response.extend([
        0xc0, 0x0c, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x3c, 0x00, 0x04, 140, 82, 112, 3,
    ]);

    let parsed = parse_response(&response).expect("response should parse");

    assert_eq!(parsed.transaction_id, 0x1234);
    assert_eq!(parsed.answers.len(), 1);
    assert_eq!(parsed.answers[0].name, "github.com");
    assert_eq!(parsed.answers[0].ttl_seconds, 60);
    assert_eq!(
        parsed.answers[0].data,
        DnsRecordData::A(Ipv4Addr::new(140, 82, 112, 3))
    );
}

#[test]
fn parses_compressed_aaaa_response() {
    let mut response = vec![
        0xab, 0xcd, 0x81, 0x80, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 6, b'g', b'o',
        b'o', b'g', b'l', b'e', 3, b'c', b'o', b'm', 0, 0, 28, 0, 1, 0xc0, 0x0c, 0x00, 0x1c, 0x00,
        0x01, 0x00, 0x00, 0x00, 0x3c, 0x00, 0x10,
    ];
    response.extend([0x26, 0x07, 0xf8, 0xb0, 0x40, 0x05, 0x08, 0x0a]);
    response.extend([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x20, 0x0e]);

    let parsed = parse_response(&response).expect("response should parse");

    assert_eq!(
        parsed.answers[0].data,
        DnsRecordData::Aaaa(Ipv6Addr::new(
            0x2607, 0xf8b0, 0x4005, 0x080a, 0, 0, 0, 0x200e
        ))
    );
}

#[test]
fn rejects_invalid_domain_labels_before_network_use() {
    let error = build_query(1, "label with spaces.com", RecordType::A)
        .expect_err("domain should be rejected");

    assert!(error.to_string().contains("invalid DNS label"));
}

#[test]
fn rejects_dns_query_packets_as_responses() {
    let query = build_query(0x1234, "github.com", RecordType::A).expect("query packet");

    assert!(
        parse_response(&query).is_err(),
        "DNS query packets must never be accepted as responses"
    );
}

#[test]
fn rejects_nonstandard_opcode_responses() {
    let mut response = vec![
        0x12, 0x34, 0x88, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    ];
    response.extend(github_question());

    assert!(
        parse_response(&response).is_err(),
        "benchmark responses must use the standard DNS opcode"
    );
}
