use serde_json::Value;
use std::net::{SocketAddr, UdpSocket};
use std::process::Command;
use std::thread;
use std::time::Duration;

#[test]
fn compare_command_recommends_fastest_dns_resolver() {
    let slow = start_fake_resolver(2, Duration::from_millis(60));
    let fast = start_fake_resolver(2, Duration::from_millis(1));

    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "compare",
            "--resolver",
            &format!("slow={slow}"),
            "--resolver",
            &format!("fast={fast}"),
            "--domain",
            "example.com",
            "--attempts",
            "1",
            "--timeout-ms",
            "500",
        ])
        .output()
        .expect("run dnspilot-cli compare");

    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8(output.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");

    assert_eq!(json["summary"]["mode"], "fastest-raw-dns");
    assert_eq!(json["summary"]["resolver_count"], 2);
    assert_eq!(json["summary"]["domain_count"], 1);
    assert_eq!(json["runs"].as_array().expect("runs array").len(), 2);
    assert_eq!(json["recommendation"]["profile_id"], "fast");
    assert_eq!(json["recommendation"]["decision"]["apply-profile"], "fast");
    assert!(json["warning"]
        .as_str()
        .expect("warning string")
        .contains("DNS-only"));
}

#[test]
fn compare_command_rejects_duplicate_resolver_ids() {
    let first = start_fake_resolver(2, Duration::from_millis(1));
    let second = start_fake_resolver(2, Duration::from_millis(1));

    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "compare",
            "--resolver",
            &format!("same={first}"),
            "--resolver",
            &format!("same={second}"),
            "--domain",
            "example.com",
            "--attempts",
            "1",
            "--timeout-ms",
            "500",
        ])
        .output()
        .expect("run dnspilot-cli compare");

    assert!(!output.status.success());
    assert!(String::from_utf8_lossy(&output.stderr).contains("duplicate --resolver id 'same'"));
}

#[test]
fn compare_command_marks_recommendation_inconclusive_when_all_resolvers_fail() {
    let first = start_silent_resolver(Duration::from_secs(1));
    let second = start_silent_resolver(Duration::from_secs(1));

    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "compare",
            "--resolver",
            &format!("first={first}"),
            "--resolver",
            &format!("second={second}"),
            "--domain",
            "example.com",
            "--attempts",
            "1",
            "--timeout-ms",
            "20",
        ])
        .output()
        .expect("run dnspilot-cli compare");

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

fn start_fake_resolver(query_count: usize, delay: Duration) -> SocketAddr {
    let socket = UdpSocket::bind("127.0.0.1:0").expect("bind fake resolver");
    let addr = socket.local_addr().expect("local addr");

    thread::spawn(move || {
        let mut buffer = [0_u8; 512];
        for _ in 0..query_count {
            let (length, peer) = socket.recv_from(&mut buffer).expect("receive DNS query");
            thread::sleep(delay);
            let request = &buffer[..length];
            let mut response = vec![
                request[0], request[1], 0x81, 0x80, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            ];
            response.extend(&request[12..]);
            socket
                .send_to(&response, peer)
                .expect("send fake DNS response");
        }
    });

    addr
}

fn start_silent_resolver(hold_for: Duration) -> SocketAddr {
    let socket = UdpSocket::bind("127.0.0.1:0").expect("bind silent resolver");
    let addr = socket.local_addr().expect("local addr");

    thread::spawn(move || {
        let _socket = socket;
        thread::sleep(hold_for);
    });

    addr
}
