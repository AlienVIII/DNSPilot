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

fn start_fake_resolver(query_count: usize) -> SocketAddr {
    let socket = UdpSocket::bind("127.0.0.1:0").expect("bind fake resolver");
    let addr = socket.local_addr().expect("local addr");

    thread::spawn(move || {
        let mut buffer = [0_u8; 512];
        for _ in 0..query_count {
            let (length, peer) = socket.recv_from(&mut buffer).expect("receive DNS query");
            let request = &buffer[..length];
            let mut response = vec![
                request[0], request[1], 0x81, 0x80, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00,
            ];
            response.extend(&request[12..]);
            socket
                .send_to(&response, peer)
                .expect("send fake DNS response");
        }
    });

    addr
}

