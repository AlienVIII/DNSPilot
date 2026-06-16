use serde_json::Value;
use std::fs;
use std::process::Command;

#[test]
fn apply_policy_command_protects_current_dns_when_vpn_is_active() {
    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args(["apply-policy", "macos-store", "--vpn-active"])
        .output()
        .expect("run dnspilot-cli apply-policy");

    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8(output.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");

    assert_eq!(json["schema_version"], 1);
    assert_eq!(json["platform"], "macos-store");
    assert_eq!(
        json["apply_capability"],
        "apple-network-extension-dns-settings"
    );
    assert_eq!(json["disposition"], "protect-current-dns");
    assert_eq!(json["can_prompt_apply"], false);
    assert!(json["notes"]
        .as_array()
        .expect("notes")
        .iter()
        .any(|note| note.as_str().expect("note").contains("VPN")));
}

#[test]
fn apply_policy_command_guides_store_settings_without_protected_signals() {
    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args(["apply-policy", "windows-store"])
        .output()
        .expect("run dnspilot-cli apply-policy");

    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8(output.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");

    assert_eq!(json["schema_version"], 1);
    assert_eq!(json["platform"], "windows-store");
    assert_eq!(json["apply_capability"], "guided-settings");
    assert_eq!(json["disposition"], "guide-only");
    assert_eq!(json["can_prompt_apply"], true);
}

#[test]
fn apply_plan_command_guides_plain_dns_for_store_safe_profile() {
    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args(["apply-plan", "macos-store", "--profile-id", "cloudflare"])
        .output()
        .expect("run dnspilot-cli apply-plan");

    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8(output.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");

    assert_eq!(json["schema_version"], 1);
    assert_eq!(json["platform"], "macos-store");
    assert_eq!(json["profile_id"], "cloudflare");
    assert_eq!(json["profile_name"], "Cloudflare");
    assert_eq!(json["disposition"], "guide-only");
    assert_eq!(json["can_apply"], false);
    assert!(json["dns_servers"]
        .as_array()
        .expect("dns servers")
        .iter()
        .any(|server| server == "1.1.1.1"));
}

#[test]
fn apply_plan_command_protects_power_apply_when_vpn_is_active() {
    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "apply-plan",
            "linux-native-power",
            "--profile-id",
            "cloudflare",
            "--vpn-active",
        ])
        .output()
        .expect("run dnspilot-cli apply-plan");

    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8(output.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");

    assert_eq!(json["platform"], "linux-native-power");
    assert_eq!(json["disposition"], "protect-current-dns");
    assert_eq!(json["can_apply"], false);
    assert!(json["notes"]
        .as_array()
        .expect("notes")
        .iter()
        .any(|note| note.as_str().expect("note").contains("VPN")));
}

#[test]
fn apply_plan_command_uses_custom_profile_database_dns_servers() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-apply-plan-custom-profile-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);

    let add = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "profile-add",
            "--db",
            db_path.to_str().expect("utf8 path"),
            "--id",
            "office-fast",
            "--name",
            "Office Fast",
            "--ipv4",
            "10.10.10.10",
            "--ipv6",
            "2001:db8::53",
            "--tag",
            "custom",
        ])
        .output()
        .expect("run dnspilot-cli profile-add");

    assert!(
        add.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&add.stderr)
    );

    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "apply-plan",
            "macos-store",
            "--profile-db",
            db_path.to_str().expect("utf8 path"),
            "--profile-id",
            "office-fast",
        ])
        .output()
        .expect("run dnspilot-cli apply-plan");

    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8(output.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");

    assert_eq!(json["platform"], "macos-store");
    assert_eq!(json["profile_id"], "office-fast");
    assert_eq!(json["profile_name"], "Office Fast");
    assert_eq!(json["disposition"], "guide-only");
    assert_eq!(json["can_apply"], false);
    let dns_servers = json["dns_servers"].as_array().expect("dns servers");
    assert!(dns_servers.iter().any(|server| server == "10.10.10.10"));
    assert!(dns_servers.iter().any(|server| server == "2001:db8::53"));

    let _ = fs::remove_file(&db_path);
}

#[test]
fn apply_plan_command_preserves_tested_resolver_as_primary_dns_server() {
    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "apply-plan",
            "macos-store",
            "--profile-id",
            "cloudflare",
            "--tested-resolver",
            "1.0.0.1:53",
        ])
        .output()
        .expect("run dnspilot-cli apply-plan");

    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8(output.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");
    let dns_servers = json["dns_servers"].as_array().expect("dns servers");

    assert_eq!(json["tested_resolver"], "1.0.0.1:53");
    assert_eq!(dns_servers.first().expect("primary dns server"), "1.0.0.1");
    assert!(json["notes"]
        .as_array()
        .expect("notes")
        .iter()
        .any(|note| note
            .as_str()
            .expect("note")
            .contains("measured resolver first")));
}
