use serde_json::Value;
use std::fs;
use std::process::Command;

#[test]
fn storage_smoke_command_saves_and_loads_builtin_snapshot() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-storage-smoke-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);

    let output = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "storage-smoke",
            "--db",
            db_path.to_str().expect("utf8 path"),
        ])
        .output()
        .expect("run dnspilot-cli storage-smoke");

    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8(output.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");

    assert_eq!(json["schema_version"], 1);
    assert!(json["profile_count"].as_u64().expect("profile count") >= 9);
    assert!(json["test_suite_count"].as_u64().expect("suite count") >= 5);
    assert_eq!(json["benchmark_history_count"], 0);
    assert!(db_path.exists());

    let _ = fs::remove_file(db_path);
}

#[test]
fn profile_add_command_persists_custom_plain_dns_profile() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-profile-add-{}.sqlite",
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
            "4.4.4.4",
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

    let list = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args(["profile-list", "--db", db_path.to_str().expect("utf8 path")])
        .output()
        .expect("run dnspilot-cli profile-list");

    assert!(
        list.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&list.stderr)
    );

    let stdout = String::from_utf8(list.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");
    let profiles = json["profiles"].as_array().expect("profiles array");

    assert!(profiles.iter().any(|profile| {
        profile["id"] == "custom-lab"
            && profile["name"] == "Custom Lab"
            && profile["ipv4_servers"]
                .as_array()
                .expect("ipv4")
                .iter()
                .any(|ip| ip == "4.4.4.4")
    }));

    let _ = fs::remove_file(db_path);
}
