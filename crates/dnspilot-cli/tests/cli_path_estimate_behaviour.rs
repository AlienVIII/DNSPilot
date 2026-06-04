use serde_json::Value;
use std::net::{SocketAddr, TcpListener, UdpSocket};
use std::process::Command;
use std::thread;

#[test]
fn path_estimate_command_outputs_dns_and_connect_metrics() {
    let tcp_listener = TcpListener::bind("127.0.0.1:0").expect("bind local TCP listener");
    let connect_port = tcp_listener.local_addr().expect("listener addr").port();
    thread::spawn(move || {
        let _ = tcp_listener.accept().expect("accept one TCP connection");
    });

    let resolver = start_fake_resolver(2);

    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "path-estimate",
            "--resolver",
            &resolver.to_string(),
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
        .expect("run dnspilot-cli path-estimate");

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
    assert!(json["metrics"]["median_connect_latency_ms"]
        .as_f64()
        .expect("connect latency should be numeric")
        >= 0.0);
    assert_eq!(json["dns_samples"].as_array().expect("dns samples").len(), 2);
    assert_eq!(
        json["connect_samples"]
            .as_array()
            .expect("connect samples")
            .len(),
        1
    );
    assert_eq!(
        json["connect_targets"]
            .as_array()
            .expect("connect targets")
            .len(),
        1
    );
    assert!(json["caveats"]
        .as_array()
        .expect("caveats")
        .iter()
        .any(|caveat| caveat.as_str().unwrap_or("").contains("TLS")));
}

fn start_fake_resolver(query_count: usize) -> SocketAddr {
    let socket = UdpSocket::bind("127.0.0.1:0").expect("bind fake resolver");
    let addr = socket.local_addr().expect("local addr");

    thread::spawn(move || {
        let mut buffer = [0_u8; 512];
        for _ in 0..query_count {
            let (length, peer) = socket.recv_from(&mut buffer).expect("receive DNS query");
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
                    0xc0, 0x0c, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x1e, 0x00,
                    0x04, 127, 0, 0, 1,
                ]);
            }
            socket
                .send_to(&response, peer)
                .expect("send fake DNS response");
        }
    });

    addr
}

