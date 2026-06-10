use serde_json::Value;
use std::process::Command;

#[test]
fn catalog_command_outputs_shell_contract_with_schema_version() {
    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .arg("catalog")
        .output()
        .expect("run dnspilot-cli catalog");

    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8(output.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");
    let profiles = json["profiles"].as_array().expect("profiles array");
    let suites = json["testSuites"].as_array().expect("testSuites array");

    assert_eq!(json["schema_version"], 1);
    assert!(json.get("test_suites").is_none());
    assert!(profiles.iter().any(|profile| profile["id"] == "cloudflare"));
    assert!(profiles.iter().any(|profile| profile["id"] == "quad9"));
    assert!(suites.iter().any(|suite| {
        suite["id"] == "azure-microsoft"
            && suite["domains"]
                .as_array()
                .expect("domains")
                .iter()
                .any(|domain| domain == "login.microsoftonline.com")
    }));
}
