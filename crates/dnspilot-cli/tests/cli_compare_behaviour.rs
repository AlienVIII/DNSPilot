use serde_json::Value;
use std::fs;
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
fn compare_command_can_limit_to_ipv4_records() {
    let resolver = start_fake_resolver(1, Duration::from_millis(1));

    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "compare",
            "--resolver",
            &format!("ipv4-only={resolver}"),
            "--domain",
            "example.com",
            "--attempts",
            "1",
            "--timeout-ms",
            "500",
            "--ip-family",
            "ipv4-only",
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
    let samples = json["runs"][0]["samples"].as_array().expect("samples");

    assert_eq!(json["summary"]["ip_family"], "ipv4-only");
    assert_eq!(samples.len(), 1);
    assert!(samples.iter().all(|sample| sample["record_type"] == "A"));
    assert_eq!(json["runs"][0]["metrics"]["ipv6_health"], 1.0);
}

#[test]
fn compare_command_includes_failure_detail_in_result_samples() {
    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "compare",
            "--resolver",
            "unreachable=127.0.0.1:9",
            "--domain",
            "example.com",
            "--attempts",
            "1",
            "--timeout-ms",
            "100",
        ])
        .output()
        .expect("run dnspilot-cli compare");

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");
    let samples = json["runs"][0]["samples"].as_array().expect("samples");

    assert!(samples
        .iter()
        .all(|sample| sample["failure_detail"].is_string()));
}

#[test]
fn compare_command_can_emit_progress_jsonl_to_stderr() {
    let slow = start_fake_resolver(2, Duration::from_millis(10));
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
            "--progress-jsonl",
        ])
        .output()
        .expect("run dnspilot-cli compare");

    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8(output.stdout).expect("stdout should be utf8");
    let result_json: Value = serde_json::from_str(&stdout).expect("stdout should stay final json");
    assert_eq!(result_json["summary"]["measurement_scope"], "dns-only");
    assert!(result_json["summary"]["gate_note_ids"].is_array());

    let stderr = String::from_utf8(output.stderr).expect("stderr should be utf8");
    let events = stderr
        .lines()
        .map(|line| {
            serde_json::from_str::<Value>(line).expect("stderr line should be progress json")
        })
        .collect::<Vec<_>>();

    assert_eq!(events.len(), 5);
    assert!(events.iter().all(|event| event["schema_version"] == 1));
    let run_id = events[0]["run_id"].as_str().expect("run id");
    assert!(run_id.starts_with("run-"));
    assert!(events.iter().all(|event| event["run_id"] == run_id));
    assert_eq!(events[0]["type"], "resolver_started");
    assert_eq!(events[0]["measurement_scope"], "dns-only");
    assert_eq!(events[0]["profile_id"], "slow");
    assert_eq!(events[0]["index"], 1);
    assert_eq!(events[0]["total"], 2);
    assert!(events[0]["elapsed_ms"].is_null());
    assert_eq!(events[1]["type"], "resolver_finished");
    assert_eq!(events[1]["profile_id"], "slow");
    assert_eq!(events[1]["status"], "success");
    assert!(events[1]["failure_kind"].is_null());
    assert!(events[1]["elapsed_ms"].as_f64().unwrap() >= 0.0);
    assert_eq!(events[2]["profile_id"], "fast");
    assert_eq!(events[3]["type"], "resolver_finished");
    assert_eq!(events[3]["profile_id"], "fast");
    assert!(events[3]["elapsed_ms"].as_f64().unwrap() >= 0.0);
    assert_eq!(events[4]["type"], "run_finished");
    assert_eq!(events[4]["status"], "success");
    assert!(events[4]["failure_kind"].is_null());
    assert_eq!(events[4]["completed"], 2);
    assert_eq!(events[4]["total"], 2);
    assert!(events[4]["elapsed_ms"].as_f64().unwrap() >= 0.0);
}

#[test]
fn compare_command_can_use_saved_domain_suite() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-compare-suite-{}.sqlite",
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

    let slow = start_fake_resolver(4, Duration::from_millis(60));
    let fast = start_fake_resolver(4, Duration::from_millis(1));
    let compare = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "compare",
            "--resolver",
            &format!("slow={slow}"),
            "--resolver",
            &format!("fast={fast}"),
            "--suite-db",
            db_path.to_str().expect("utf8 path"),
            "--suite-id",
            "azure-lab",
            "--attempts",
            "1",
            "--timeout-ms",
            "500",
        ])
        .output()
        .expect("run dnspilot-cli compare");

    assert!(
        compare.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&compare.stderr)
    );

    let stdout = String::from_utf8(compare.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");

    assert_eq!(json["summary"]["domain_count"], 2);
    assert_eq!(json["recommendation"]["profile_id"], "fast");
    assert!(json["runs"][0]["samples"]
        .as_array()
        .expect("samples")
        .iter()
        .any(|sample| sample["domain"] == "portal.azure.com"));

    let _ = fs::remove_file(db_path);
}

#[test]
fn compare_command_can_use_saved_plain_dns_profiles() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-compare-profiles-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);
    let resolver = start_fake_resolver(4, Duration::from_millis(1));

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

    let compare = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "compare",
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
            "--timeout-ms",
            "500",
        ])
        .output()
        .expect("run dnspilot-cli compare");

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
fn compare_command_can_save_history_to_sqlite() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-compare-history-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);
    let slow = start_fake_resolver(2, Duration::from_millis(60));
    let fast = start_fake_resolver(2, Duration::from_millis(1));

    let compare = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
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
            "--save-db",
            db_path.to_str().expect("utf8 path"),
            "--history-id",
            "dns-run-1",
        ])
        .output()
        .expect("run dnspilot-cli compare");

    assert!(
        compare.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&compare.stderr)
    );
    let compare_stdout = String::from_utf8(compare.stdout).expect("stdout should be utf8");
    let compare_json: Value = serde_json::from_str(&compare_stdout).expect("stdout should be json");
    assert_eq!(compare_json["saved_history_id"], "dns-run-1");

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
    assert_eq!(history[0]["id"], "dns-run-1");
    assert_eq!(history[0]["scope"], "dns-only");
    assert_eq!(history[0]["mode"], "fastest-raw-dns");
    assert_eq!(history[0]["domains"][0], "example.com");
    assert_eq!(history[0]["resolver_profile_ids"][0], "slow");
    assert_eq!(history[0]["resolver_profile_ids"][1], "fast");
    assert_eq!(history[0]["recommendation_profile_id"], "fast");
    assert_eq!(history[0]["gate"]["can_recommend"], true);

    let _ = fs::remove_file(db_path);
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
fn compare_command_rejects_zero_timeout() {
    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "compare",
            "--resolver",
            "cloudflare=127.0.0.1:9",
            "--domain",
            "github.com",
            "--attempts",
            "1",
            "--timeout-ms",
            "0",
        ])
        .output()
        .expect("run dnspilot-cli compare");

    assert!(
        !output.status.success(),
        "compare should reject zero timeout"
    );
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        stderr.contains("--timeout-ms must be greater than 0"),
        "stderr: {stderr}"
    );
}

#[test]
fn compare_command_rejects_zero_resolver_port() {
    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "compare",
            "--resolver",
            "cloudflare=127.0.0.1:0",
            "--domain",
            "github.com",
            "--attempts",
            "1",
        ])
        .output()
        .expect("run dnspilot-cli compare");

    assert!(
        !output.status.success(),
        "compare should reject zero resolver port"
    );
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        stderr.contains("--resolver port must be greater than 0"),
        "stderr: {stderr}"
    );
}

#[test]
fn compare_command_rejects_duplicate_domains() {
    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "compare",
            "--resolver",
            "cloudflare=127.0.0.1:9",
            "--domain",
            "github.com",
            "--domain",
            "github.com",
            "--attempts",
            "1",
        ])
        .output()
        .expect("run dnspilot-cli compare");

    assert!(
        !output.status.success(),
        "compare should reject duplicate domains"
    );
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(stderr.contains("duplicate domain"), "stderr: {stderr}");
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
    assert_eq!(
        json["summary"]["gate_note_ids"],
        serde_json::json!(["every-candidate-failed"])
    );
    assert_eq!(json["summary"]["can_recommend"], false);
    assert!(json["summary"]["recommended_profile_id"].is_null());
    assert!(json["recommendation"].is_null());
}

fn start_fake_resolver(query_count: usize, delay: Duration) -> SocketAddr {
    start_fake_resolver_on(
        "127.0.0.1:0".parse().expect("loopback addr"),
        query_count,
        delay,
    )
}

fn start_fake_resolver_on(
    bind_addr: SocketAddr,
    query_count: usize,
    delay: Duration,
) -> SocketAddr {
    let socket = UdpSocket::bind(bind_addr).expect("bind fake resolver");
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
