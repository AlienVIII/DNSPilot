use serde_json::Value;
use std::process::Command;

#[test]
fn preflight_command_outputs_flush_policy_for_system_dns_validation() {
    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "preflight",
            "macos-store",
            "--scope",
            "system-dns-validation",
        ])
        .output()
        .expect("run dnspilot-cli preflight");

    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8(output.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");

    assert_eq!(json["schema_version"], 1);
    assert_eq!(json["platform"], "macos-store");
    assert_eq!(json["scope"], "system-dns-validation");
    assert_eq!(json["flush_capability"], "guided-user-action");
    assert_eq!(json["flush_requirement"], "recommended-before-test");
}

#[test]
fn preflight_command_defaults_direct_resolver_to_no_flush() {
    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args(["preflight", "ios"])
        .output()
        .expect("run dnspilot-cli preflight");

    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8(output.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");

    assert_eq!(json["schema_version"], 1);
    assert_eq!(json["platform"], "ios");
    assert_eq!(json["scope"], "direct-resolver-benchmark");
    assert_eq!(json["flush_capability"], "unsupported");
    assert_eq!(json["flush_requirement"], "not-needed");
}
