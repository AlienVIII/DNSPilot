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
        .args(["storage-smoke", "--db", db_path.to_str().expect("utf8 path")])
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
