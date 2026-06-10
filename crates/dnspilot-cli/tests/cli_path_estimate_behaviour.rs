use serde_json::Value;
use std::fs;
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
    assert_eq!(json["summary"]["measurement_scope"], "dns-tcp");
    assert_eq!(json["summary"]["health"], "healthy");
    assert_eq!(json["summary"]["primary_issue"], "none");
    assert_eq!(json["summary"]["tls_enabled"], false);
    assert_eq!(json["summary"]["dns_sample_count"], 2);
    assert_eq!(json["summary"]["connect_target_count"], 1);
    assert_eq!(json["summary"]["connect_sample_count"], 1);
    assert_eq!(json["summary"]["tls_sample_count"], 0);
    assert_eq!(json["summary"]["trust_store"], Value::Null);
    assert_eq!(json["metrics"]["failure_rate"], 0.0);
    assert_eq!(json["metrics"]["timeout_rate"], 0.0);
    assert!(
        json["metrics"]["median_connect_latency_ms"]
            .as_f64()
            .expect("connect latency should be numeric")
            >= 0.0
    );
    assert_eq!(
        json["dns_samples"].as_array().expect("dns samples").len(),
        2
    );
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

#[test]
fn path_estimate_command_can_use_saved_plain_dns_profile() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-path-estimate-profile-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);
    let add = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "profile-add",
            "--db",
            db_path.to_str().expect("utf8 path"),
            "--id",
            "custom-lab",
            "--name",
            "Custom Lab",
            "--ipv4",
            "127.0.0.1",
        ])
        .output()
        .expect("run dnspilot-cli profile-add");

    assert!(
        add.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&add.stderr)
    );

    let tcp_listener = TcpListener::bind("127.0.0.1:0").expect("bind local TCP listener");
    let connect_port = tcp_listener.local_addr().expect("listener addr").port();
    thread::spawn(move || {
        let _ = tcp_listener.accept().expect("accept TCP connection");
    });

    let resolver = start_fake_resolver(2);
    let estimate = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "path-estimate",
            "--profile-db",
            db_path.to_str().expect("utf8 path"),
            "--profile-id",
            "custom-lab",
            "--resolver-port",
            &resolver.port().to_string(),
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
        estimate.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&estimate.stderr)
    );

    let stdout = String::from_utf8(estimate.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");

    assert_eq!(json["metrics"]["profile_id"], "custom-lab");
    assert_eq!(json["summary"]["domain_count"], 1);
    assert_eq!(json["summary"]["dns_sample_count"], 2);

    let _ = fs::remove_file(db_path);
}

#[test]
fn path_estimate_command_can_use_saved_domain_suite() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-path-estimate-suite-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);
    let add = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "suite-add",
            "--db",
            db_path.to_str().expect("utf8 path"),
            "--id",
            "azure-lab",
            "--name",
            "Azure Lab",
            "--domain",
            "portal.azure.com",
            "--domain",
            "login.microsoftonline.com",
        ])
        .output()
        .expect("run dnspilot-cli suite-add");

    assert!(
        add.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&add.stderr)
    );

    let tcp_listener = TcpListener::bind("127.0.0.1:0").expect("bind local TCP listener");
    let connect_port = tcp_listener.local_addr().expect("listener addr").port();
    thread::spawn(move || {
        for _ in 0..2 {
            let _ = tcp_listener.accept().expect("accept TCP connection");
        }
    });

    let resolver = start_fake_resolver(4);
    let estimate = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "path-estimate",
            "--resolver",
            &resolver.to_string(),
            "--suite-db",
            db_path.to_str().expect("utf8 path"),
            "--suite-id",
            "azure-lab",
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
        estimate.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&estimate.stderr)
    );

    let stdout = String::from_utf8(estimate.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");

    assert_eq!(json["summary"]["domain_count"], 2);
    assert!(json["dns_samples"]
        .as_array()
        .expect("dns samples")
        .iter()
        .any(|sample| sample["domain"] == "portal.azure.com"));

    let _ = fs::remove_file(db_path);
}

#[test]
fn path_estimate_command_can_include_tls_samples_when_enabled() {
    let tcp_listener = TcpListener::bind("127.0.0.1:0").expect("bind local TCP listener");
    let connect_port = tcp_listener.local_addr().expect("listener addr").port();
    thread::spawn(move || {
        for _ in 0..2 {
            let _ = tcp_listener.accept().expect("accept TCP connection");
        }
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
            "--tls-handshake-timeout-ms",
            "500",
        ])
        .output()
        .expect("run dnspilot-cli path-estimate with TLS");

    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8(output.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");

    let tls_samples = json["tls_samples"].as_array().expect("tls samples");
    assert_eq!(json["summary"]["measurement_scope"], "dns-tcp-tls");
    assert_eq!(json["summary"]["health"], "failed");
    assert_eq!(json["summary"]["primary_issue"], "tls-handshake-failure");
    assert_eq!(json["summary"]["tls_enabled"], true);
    assert_eq!(json["summary"]["tls_sample_count"], 1);
    assert_eq!(json["summary"]["trust_store"], "mozilla-webpki-roots");
    assert_eq!(tls_samples.len(), 1);
    assert_eq!(tls_samples[0]["server_name"], "example.com");
    assert_eq!(tls_samples[0]["outcome"], "handshake-failure");
    assert_eq!(json["metrics"]["failure_rate"], 1.0);
    assert!(json["caveats"]
        .as_array()
        .expect("caveats")
        .iter()
        .any(|caveat| caveat.as_str().unwrap_or("").contains("TLS/SNI")));
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
                    0xc0, 0x0c, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x1e, 0x00, 0x04, 127, 0,
                    0, 1,
                ]);
            }
            socket
                .send_to(&response, peer)
                .expect("send fake DNS response");
        }
    });

    addr
}
