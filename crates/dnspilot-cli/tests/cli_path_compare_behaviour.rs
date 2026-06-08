use serde_json::Value;
use std::net::{Ipv4Addr, SocketAddr, TcpListener, UdpSocket};
use std::process::Command;
use std::thread;
use std::time::Duration;

#[test]
fn path_compare_command_recommends_better_connection_path_over_raw_dns_speed() {
    let tcp_listener = TcpListener::bind("127.0.0.1:0").expect("bind local TCP listener");
    let connect_port = tcp_listener.local_addr().expect("listener addr").port();
    thread::spawn(move || {
        let _ = tcp_listener.accept().expect("accept one TCP connection");
    });

    let dns_fast_bad_path =
        start_fake_resolver_with_a(2, Duration::from_millis(1), Ipv4Addr::new(127, 0, 0, 2));
    let dns_slower_good_path =
        start_fake_resolver_with_a(2, Duration::from_millis(50), Ipv4Addr::new(127, 0, 0, 1));

    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "path-compare",
            "--resolver",
            &format!("dns-fast-bad-path={dns_fast_bad_path}"),
            "--resolver",
            &format!("path-good={dns_slower_good_path}"),
            "--domain",
            "example.com",
            "--attempts",
            "1",
            "--dns-timeout-ms",
            "500",
            "--connect-timeout-ms",
            "500",
            "--connect-port",
            &connect_port.to_string(),
        ])
        .output()
        .expect("run dnspilot-cli path-compare");

    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8(output.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");

    assert_eq!(json["summary"]["measurement_scope"], "dns-tcp");
    assert_eq!(json["summary"]["mode"], "best-overall");
    assert_eq!(json["summary"]["health"], "degraded");
    assert_eq!(json["summary"]["primary_issue"], "partial-failure");
    assert_eq!(json["summary"]["can_recommend"], true);
    assert_eq!(json["summary"]["recommended_profile_id"], "path-good");
    assert_eq!(json["runs"].as_array().expect("runs array").len(), 2);
    assert_eq!(json["recommendation"]["profile_id"], "path-good");
    assert_eq!(
        json["recommendation"]["decision"]["apply-profile"],
        "path-good"
    );
    assert!(json["warning"]
        .as_str()
        .expect("warning string")
        .contains("DNS plus TCP"));
}

#[test]
fn path_compare_command_suppresses_recommendation_when_all_paths_fail() {
    let first =
        start_fake_resolver_with_a(2, Duration::from_millis(1), Ipv4Addr::new(127, 0, 0, 2));
    let second =
        start_fake_resolver_with_a(2, Duration::from_millis(1), Ipv4Addr::new(127, 0, 0, 3));

    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "path-compare",
            "--resolver",
            &format!("first={first}"),
            "--resolver",
            &format!("second={second}"),
            "--domain",
            "example.com",
            "--attempts",
            "1",
            "--dns-timeout-ms",
            "500",
            "--connect-timeout-ms",
            "100",
            "--connect-port",
            "9",
        ])
        .output()
        .expect("run dnspilot-cli path-compare");

    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8(output.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");

    assert_eq!(json["summary"]["health"], "failed");
    assert_eq!(json["summary"]["primary_issue"], "all-resolvers-failed");
    assert_eq!(json["summary"]["can_recommend"], false);
    assert!(json["summary"]["recommended_profile_id"].is_null());
    assert!(json["recommendation"].is_null());
}

#[test]
fn path_compare_command_can_include_tls_samples_when_enabled() {
    let tcp_listener = TcpListener::bind("127.0.0.1:0").expect("bind local TCP listener");
    let connect_port = tcp_listener.local_addr().expect("listener addr").port();
    thread::spawn(move || {
        for _ in 0..2 {
            let _ = tcp_listener.accept().expect("accept TCP connection");
        }
    });

    let resolver =
        start_fake_resolver_with_a(2, Duration::from_millis(1), Ipv4Addr::new(127, 0, 0, 1));

    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "path-compare",
            "--resolver",
            &format!("tls-test={resolver}"),
            "--domain",
            "example.com",
            "--attempts",
            "1",
            "--dns-timeout-ms",
            "500",
            "--connect-timeout-ms",
            "500",
            "--connect-port",
            &connect_port.to_string(),
            "--tls-handshake-timeout-ms",
            "500",
        ])
        .output()
        .expect("run dnspilot-cli path-compare with TLS");

    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8(output.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");
    let first_run = &json["runs"].as_array().expect("runs array")[0];
    let tls_samples = first_run["tls_samples"].as_array().expect("tls samples");

    assert_eq!(json["summary"]["measurement_scope"], "dns-tcp-tls");
    assert_eq!(json["summary"]["tls_enabled"], true);
    assert_eq!(json["summary"]["trust_store"], "mozilla-webpki-roots");
    assert_eq!(json["summary"]["health"], "failed");
    assert_eq!(json["summary"]["can_recommend"], false);
    assert!(json["summary"]["recommended_profile_id"].is_null());
    assert!(json["recommendation"].is_null());
    assert_eq!(first_run["summary"]["measurement_scope"], "dns-tcp-tls");
    assert_eq!(
        first_run["summary"]["primary_issue"],
        "tls-handshake-failure"
    );
    assert_eq!(first_run["summary"]["trust_store"], "mozilla-webpki-roots");
    assert_eq!(first_run["summary"]["tls_sample_count"], 1);
    assert_eq!(tls_samples.len(), 1);
    assert_eq!(tls_samples[0]["server_name"], "example.com");
    assert_eq!(tls_samples[0]["outcome"], "handshake-failure");
    assert!(json["warning"]
        .as_str()
        .expect("warning string")
        .contains("TLS/SNI"));
}

fn start_fake_resolver_with_a(query_count: usize, delay: Duration, ipv4: Ipv4Addr) -> SocketAddr {
    let socket = UdpSocket::bind("127.0.0.1:0").expect("bind fake resolver");
    let addr = socket.local_addr().expect("local addr");

    thread::spawn(move || {
        let mut buffer = [0_u8; 512];
        for _ in 0..query_count {
            let (length, peer) = socket.recv_from(&mut buffer).expect("receive DNS query");
            thread::sleep(delay);
            let request = &buffer[..length];
            let qtype = u16::from_be_bytes([request[length - 4], request[length - 3]]);
            let mut response = vec![
                request[0],
                request[1],
                0x81,
                0x80,
                0x00,
                0x01,
                0x00,
                if qtype == 1 { 0x01 } else { 0x00 },
                0x00,
                0x00,
                0x00,
                0x00,
            ];
            response.extend(&request[12..]);
            if qtype == 1 {
                response.extend([
                    0xc0, 0x0c, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x1e, 0x00, 0x04,
                ]);
                response.extend(ipv4.octets());
            }
            socket
                .send_to(&response, peer)
                .expect("send fake DNS response");
        }
    });

    addr
}
