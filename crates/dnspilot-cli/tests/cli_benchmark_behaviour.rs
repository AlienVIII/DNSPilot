use serde_json::Value;
use std::net::{SocketAddr, UdpSocket};
use std::process::Command;
use std::thread;

#[test]
fn benchmark_command_outputs_json_metrics_from_udp_resolver() {
    let resolver = start_fake_resolver(2);

    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "benchmark",
            "--resolver",
            &resolver.to_string(),
            "--domain",
            "example.com",
            "--attempts",
            "1",
            "--timeout-ms",
            "500",
        ])
        .output()
        .expect("run dnspilot-cli benchmark");

    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8(output.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");

    assert_eq!(json["metrics"]["profile_id"], "manual");
    assert_eq!(json["metrics"]["failure_rate"], 0.0);
    assert_eq!(json["metrics"]["timeout_rate"], 0.0);
    assert_eq!(json["samples"].as_array().expect("samples array").len(), 2);
}

#[test]
fn system_benchmark_command_outputs_system_dns_validation_payload() {
    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "system-benchmark",
            "--domain",
            "localhost",
            "--attempts",
            "1",
            "--ip-family",
            "ipv4-only",
            "--timeout-ms",
            "500",
        ])
        .output()
        .expect("run dnspilot-cli system-benchmark");

    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8(output.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");

    assert_eq!(json["scope"], "system-dns-validation");
    assert_eq!(json["metrics"]["profile_id"], "system-dns");
    assert_eq!(json["samples"].as_array().expect("samples array").len(), 1);
    assert_eq!(json["summary"]["measurement_scope"], "dns-only");
    assert_eq!(json["summary"]["mode"], "fastest-raw-dns");
    assert_eq!(json["summary"]["can_recommend"], false);
    assert!(json["summary"]["gate_note_ids"].is_array());
    assert_eq!(json["summary"]["recommended_profile_id"], Value::Null);
    assert_eq!(json["summary"]["resolver_count"], 1);
    assert_eq!(json["summary"]["domain_count"], 1);
    assert_eq!(json["summary"]["attempts_per_record"], 1);
    assert_eq!(json["summary"]["ip_family"], "ipv4-only");
    assert_eq!(json["runs"][0]["profile_id"], "system-dns");
    assert_eq!(json["runs"][0]["resolver"], "macOS system resolver");
    assert_eq!(json["runs"][0]["metrics"]["profile_id"], "system-dns");
    assert_eq!(json["recommendation"], Value::Null);
    assert_eq!(
        json["preflight"]["flush_requirement"],
        "recommended-before-test"
    );
}

#[test]
fn system_benchmark_command_can_emit_progress_jsonl() {
    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "system-benchmark",
            "--domain",
            "localhost",
            "--attempts",
            "1",
            "--ip-family",
            "ipv4-only",
            "--timeout-ms",
            "500",
            "--progress-jsonl",
        ])
        .output()
        .expect("run dnspilot-cli system-benchmark");

    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stderr = String::from_utf8(output.stderr).expect("stderr should be utf8");
    let events = stderr
        .lines()
        .map(|line| serde_json::from_str::<Value>(line).expect("progress line should be json"))
        .collect::<Vec<_>>();

    assert_eq!(events.len(), 3);
    let run_id = events[0]["run_id"].as_str().expect("run id");
    assert!(events.iter().all(|event| event["run_id"] == run_id));
    assert_eq!(events[0]["type"], "resolver_started");
    assert_eq!(events[1]["type"], "resolver_finished");
    assert_eq!(events[0]["profile_id"], "system-dns");
    assert_eq!(events[0]["resolver"], "macOS system resolver");
    assert_eq!(events[2]["type"], "run_finished");
    assert_eq!(events[2]["completed"], 1);
    assert_eq!(events[2]["total"], 1);
}

#[test]
fn benchmark_command_rejects_zero_attempts() {
    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "benchmark",
            "--resolver",
            "127.0.0.1:9",
            "--domain",
            "github.com",
            "--attempts",
            "0",
        ])
        .output()
        .expect("run dnspilot-cli benchmark");

    assert!(
        !output.status.success(),
        "benchmark should reject zero attempts"
    );
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        stderr.contains("--attempts must be greater than 0"),
        "stderr: {stderr}"
    );
}

#[test]
fn benchmark_command_rejects_zero_timeout() {
    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "benchmark",
            "--resolver",
            "127.0.0.1:9",
            "--domain",
            "github.com",
            "--attempts",
            "1",
            "--timeout-ms",
            "0",
        ])
        .output()
        .expect("run dnspilot-cli benchmark");

    assert!(
        !output.status.success(),
        "benchmark should reject zero timeout"
    );
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        stderr.contains("--timeout-ms must be greater than 0"),
        "stderr: {stderr}"
    );
}

#[test]
fn benchmark_command_rejects_zero_resolver_port() {
    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "benchmark",
            "--resolver",
            "127.0.0.1:0",
            "--domain",
            "github.com",
            "--attempts",
            "1",
        ])
        .output()
        .expect("run dnspilot-cli benchmark");

    assert!(
        !output.status.success(),
        "benchmark should reject zero resolver port"
    );
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        stderr.contains("--resolver port must be greater than 0"),
        "stderr: {stderr}"
    );
}

#[test]
fn benchmark_command_rejects_invalid_domain_before_network() {
    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "benchmark",
            "--resolver",
            "127.0.0.1:9",
            "--domain",
            "bad domain",
            "--attempts",
            "1",
        ])
        .output()
        .expect("run dnspilot-cli benchmark");

    assert!(
        !output.status.success(),
        "benchmark should reject invalid domain"
    );
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(stderr.contains("invalid --domain"), "stderr: {stderr}");
}

fn start_fake_resolver(query_count: usize) -> SocketAddr {
    let socket = UdpSocket::bind("127.0.0.1:0").expect("bind fake resolver");
    let addr = socket.local_addr().expect("local addr");

    thread::spawn(move || {
        let mut buffer = [0_u8; 512];
        for _ in 0..query_count {
            let (length, peer) = socket.recv_from(&mut buffer).expect("receive DNS query");
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
