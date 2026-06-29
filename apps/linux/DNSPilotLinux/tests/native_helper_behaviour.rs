use std::process::Command;

fn helper_binary() -> Command {
    Command::new(env!("CARGO_BIN_EXE_dnspilot-native-helper"))
}

#[test]
fn native_helper_prints_polkit_contract_without_dns_mutation() {
    let output = helper_binary().arg("--contract").output().unwrap();

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("DNS Pilot Native Helper Contract"));
    assert!(stdout.contains("Polkit action: io.dnspilot.DNSPilot.apply-dns"));
    assert!(stdout.contains("NetworkManager D-Bus"));
    assert!(stdout.contains("systemd-resolved D-Bus"));
    assert!(stdout.contains("does not mutate DNS without an explicit apply request"));
}

#[test]
fn native_helper_dry_run_renders_stack_and_servers_without_writing() {
    let output = helper_binary()
        .args([
            "--dry-run",
            "--stack",
            "networkmanager",
            "--server",
            "1.1.1.1",
            "--server",
            "9.9.9.9",
        ])
        .output()
        .unwrap();

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("Dry run: yes"));
    assert!(stdout.contains("Resolver stack: NetworkManager D-Bus"));
    assert!(stdout.contains("Servers: 1.1.1.1, 9.9.9.9"));
    assert!(stdout.contains("DNS writes executed: no"));
}

#[test]
fn native_helper_rejects_dry_run_without_servers() {
    let output = helper_binary()
        .args(["--dry-run", "--stack", "systemd-resolved"])
        .output()
        .unwrap();

    assert!(!output.status.success());
    assert!(String::from_utf8(output.stderr)
        .unwrap()
        .contains("--server is required"));
}

#[test]
fn native_helper_request_json_runs_mock_lifecycle_without_writing_dns() {
    let request = r#"{
        "schema_version": 1,
        "polkit_action_id": "io.dnspilot.DNSPilot.apply-dns",
        "resolver_stack": "networkmanager",
        "servers": ["1.1.1.1"],
        "rollback_snapshot": true,
        "validate_after_apply": true
    }"#;

    let output = helper_binary()
        .args(["--request-json", request])
        .output()
        .unwrap();

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("Native helper mock execution"));
    assert!(stdout.contains("snapshot:NetworkManager"));
    assert!(stdout.contains("authorize:io.dnspilot.DNSPilot.apply-dns"));
    assert!(stdout.contains("would-write:NetworkManager:1.1.1.1"));
    assert!(stdout.contains("DNS writes executed: no"));
}

#[test]
fn native_helper_request_json_rejects_execute_mode_without_backend() {
    let request = r#"{
        "schema_version": 1,
        "polkit_action_id": "io.dnspilot.DNSPilot.apply-dns",
        "resolver_stack": "networkmanager",
        "servers": ["1.1.1.1"],
        "rollback_snapshot": true,
        "validate_after_apply": true,
        "mutation_mode": "execute",
        "confirm_system_dns_mutation": true
    }"#;

    let output = helper_binary()
        .args(["--request-json", request])
        .output()
        .unwrap();

    assert!(!output.status.success());
    let stderr = String::from_utf8(output.stderr).unwrap();
    assert!(stderr.contains("execution backend is not enabled"));
}
