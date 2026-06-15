use serde_json::Value;
use std::fs;
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
fn path_compare_command_can_limit_to_ipv4_records() {
    let tcp_listener = TcpListener::bind("127.0.0.1:0").expect("bind local TCP listener");
    let connect_port = tcp_listener.local_addr().expect("listener addr").port();
    thread::spawn(move || {
        let _ = tcp_listener.accept().expect("accept TCP connection");
    });

    let resolver =
        start_fake_resolver_with_a(1, Duration::from_millis(1), Ipv4Addr::new(127, 0, 0, 1));

    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "path-compare",
            "--resolver",
            &format!("ipv4-only={resolver}"),
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
            "--ip-family",
            "ipv4-only",
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
    let samples = json["runs"][0]["dns_samples"]
        .as_array()
        .expect("dns samples");

    assert_eq!(json["summary"]["ip_family"], "ipv4-only");
    assert_eq!(samples.len(), 1);
    assert!(samples.iter().all(|sample| sample["record_type"] == "A"));
    assert_eq!(json["runs"][0]["metrics"]["ipv6_health"], 1.0);
}

#[test]
fn path_compare_command_can_emit_progress_jsonl_to_stderr() {
    let tcp_listener = TcpListener::bind("127.0.0.1:0").expect("bind local TCP listener");
    let connect_port = tcp_listener.local_addr().expect("listener addr").port();
    thread::spawn(move || {
        for _ in 0..2 {
            let _ = tcp_listener.accept().expect("accept TCP connection");
        }
    });

    let first =
        start_fake_resolver_with_a(1, Duration::from_millis(1), Ipv4Addr::new(127, 0, 0, 1));
    let second =
        start_fake_resolver_with_a(1, Duration::from_millis(1), Ipv4Addr::new(127, 0, 0, 1));

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
            "500",
            "--connect-port",
            &connect_port.to_string(),
            "--ip-family",
            "ipv4-only",
            "--progress-jsonl",
        ])
        .output()
        .expect("run dnspilot-cli path-compare");

    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8(output.stdout).expect("stdout should be utf8");
    let result_json: Value = serde_json::from_str(&stdout).expect("stdout should stay final json");
    assert_eq!(result_json["summary"]["measurement_scope"], "dns-tcp");

    let stderr = String::from_utf8(output.stderr).expect("stderr should be utf8");
    let events = stderr
        .lines()
        .map(|line| {
            serde_json::from_str::<Value>(line).expect("stderr line should be progress json")
        })
        .collect::<Vec<_>>();

    assert_eq!(events.len(), 4);
    assert_eq!(events[0]["type"], "resolver_started");
    assert_eq!(events[0]["measurement_scope"], "dns-tcp");
    assert_eq!(events[0]["profile_id"], "first");
    assert_eq!(events[0]["index"], 1);
    assert_eq!(events[0]["total"], 2);
    assert!(events[0]["elapsed_ms"].is_null());
    assert_eq!(events[1]["type"], "resolver_finished");
    assert_eq!(events[1]["profile_id"], "first");
    assert_eq!(events[1]["status"], "success");
    assert!(events[1]["elapsed_ms"].as_f64().unwrap() >= 0.0);
    assert_eq!(events[3]["type"], "resolver_finished");
    assert_eq!(events[3]["profile_id"], "second");
    assert!(events[3]["elapsed_ms"].as_f64().unwrap() >= 0.0);
}

#[test]
fn path_compare_command_can_use_saved_domain_suite() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-path-compare-suite-{}.sqlite",
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

    let resolver =
        start_fake_resolver_with_a(4, Duration::from_millis(1), Ipv4Addr::new(127, 0, 0, 1));
    let compare = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "path-compare",
            "--resolver",
            &format!("suite-test={resolver}"),
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
        .expect("run dnspilot-cli path-compare");

    assert!(
        compare.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&compare.stderr)
    );

    let stdout = String::from_utf8(compare.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");

    assert_eq!(json["summary"]["domain_count"], 2);
    assert!(json["runs"][0]["dns_samples"]
        .as_array()
        .expect("dns samples")
        .iter()
        .any(|sample| sample["domain"] == "portal.azure.com"));

    let _ = fs::remove_file(db_path);
}

#[test]
fn path_compare_command_can_use_saved_plain_dns_profiles() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-path-compare-profiles-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);

    for id in ["lab-a", "lab-b"] {
        let add = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
            .args([
                "profile-add",
                "--db",
                db_path.to_str().expect("utf8 path"),
                "--id",
                id,
                "--name",
                id,
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
    }

    let tcp_listener = TcpListener::bind("127.0.0.1:0").expect("bind local TCP listener");
    let connect_port = tcp_listener.local_addr().expect("listener addr").port();
    thread::spawn(move || {
        for _ in 0..2 {
            let _ = tcp_listener.accept().expect("accept TCP connection");
        }
    });

    let resolver =
        start_fake_resolver_with_a(4, Duration::from_millis(1), Ipv4Addr::new(127, 0, 0, 1));
    let compare = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "path-compare",
            "--profile-db",
            db_path.to_str().expect("utf8 path"),
            "--profile-id",
            "lab-a",
            "--profile-id",
            "lab-b",
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
        .expect("run dnspilot-cli path-compare");

    assert!(
        compare.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&compare.stderr)
    );

    let stdout = String::from_utf8(compare.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");

    assert_eq!(json["summary"]["resolver_count"], 2);
    assert_eq!(json["runs"][0]["profile_id"], "lab-a");
    assert_eq!(json["runs"][1]["profile_id"], "lab-b");

    let _ = fs::remove_file(db_path);
}

#[test]
fn path_compare_command_can_save_history_to_sqlite() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-path-compare-history-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);
    let tcp_listener = TcpListener::bind("127.0.0.1:0").expect("bind local TCP listener");
    let connect_port = tcp_listener.local_addr().expect("listener addr").port();
    thread::spawn(move || {
        let _ = tcp_listener.accept().expect("accept one TCP connection");
    });

    let dns_fast_bad_path =
        start_fake_resolver_with_a(2, Duration::from_millis(1), Ipv4Addr::new(127, 0, 0, 2));
    let dns_slower_good_path =
        start_fake_resolver_with_a(2, Duration::from_millis(50), Ipv4Addr::new(127, 0, 0, 1));

    let compare = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
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
            "--save-db",
            db_path.to_str().expect("utf8 path"),
            "--history-id",
            "path-run-1",
        ])
        .output()
        .expect("run dnspilot-cli path-compare");

    assert!(
        compare.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&compare.stderr)
    );
    let compare_stdout = String::from_utf8(compare.stdout).expect("stdout should be utf8");
    let compare_json: Value = serde_json::from_str(&compare_stdout).expect("stdout should be json");
    assert_eq!(compare_json["saved_history_id"], "path-run-1");

    let list = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args(["history-list", "--db", db_path.to_str().expect("utf8 path")])
        .output()
        .expect("run dnspilot-cli history-list");

    assert!(
        list.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&list.stderr)
    );

    let stdout = String::from_utf8(list.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");
    let history = json["benchmark_history"].as_array().expect("history array");

    assert_eq!(json["benchmark_history_count"], 1);
    assert_eq!(history[0]["id"], "path-run-1");
    assert_eq!(history[0]["scope"], "dns-tcp");
    assert_eq!(history[0]["mode"], "best-overall");
    assert_eq!(history[0]["domains"][0], "example.com");
    assert_eq!(
        history[0]["resolver_profile_ids"]
            .as_array()
            .expect("resolver ids")
            .len(),
        2
    );
    assert_eq!(history[0]["resolver_profile_ids"][0], "dns-fast-bad-path");
    assert_eq!(history[0]["resolver_profile_ids"][1], "path-good");
    assert_eq!(history[0]["recommendation_profile_id"], "path-good");
    assert_eq!(history[0]["gate"]["can_recommend"], true);

    let _ = fs::remove_file(db_path);
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

#[test]
fn path_compare_command_rejects_zero_tls_timeout() {
    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "path-compare",
            "--resolver",
            "cloudflare=127.0.0.1:9",
            "--domain",
            "github.com",
            "--attempts",
            "1",
            "--tls-handshake-timeout-ms",
            "0",
        ])
        .output()
        .expect("run dnspilot-cli path-compare");

    assert!(
        !output.status.success(),
        "path-compare should reject zero TLS timeout"
    );
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        stderr.contains("--tls-handshake-timeout-ms must be greater than 0"),
        "stderr: {stderr}"
    );
}

#[test]
fn path_compare_command_rejects_zero_max_connect_targets() {
    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "path-compare",
            "--resolver",
            "cloudflare=127.0.0.1:9",
            "--domain",
            "github.com",
            "--attempts",
            "1",
            "--max-connect-targets-per-domain",
            "0",
        ])
        .output()
        .expect("run dnspilot-cli path-compare");

    assert!(
        !output.status.success(),
        "path-compare should reject zero max connect targets"
    );
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        stderr.contains("--max-connect-targets-per-domain must be greater than 0"),
        "stderr: {stderr}"
    );
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
