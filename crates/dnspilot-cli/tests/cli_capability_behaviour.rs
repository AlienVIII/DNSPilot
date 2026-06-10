use serde_json::Value;
use std::process::Command;

#[test]
fn capabilities_command_outputs_full_matrix_with_flush_contract() {
    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .arg("capabilities")
        .output()
        .expect("run dnspilot-cli capabilities");

    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8(output.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");
    let capabilities = json["capabilities"]
        .as_array()
        .expect("capabilities should be an array");

    assert_eq!(capabilities.len(), 9);
    assert!(capabilities.iter().all(|capability| capability["flush"].is_string()));
    assert!(capabilities.iter().any(|capability| {
        capability["platform"] == "macos-store"
            && capability["apply"] == "apple-network-extension-dns-settings"
            && capability["flush"] == "guided-user-action"
    }));
    assert!(capabilities.iter().any(|capability| {
        capability["platform"] == "ios" && capability["flush"] == "unsupported"
    }));
    assert!(capabilities.iter().any(|capability| {
        capability["platform"] == "linux-native-power"
            && capability["flush"] == "linux-system-resolver-polkit"
    }));
}
