use std::path::PathBuf;
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

fn binary() -> Command {
    Command::new(env!("CARGO_BIN_EXE_dnspilot-linux-shell"))
}

fn temp_path(name: &str) -> PathBuf {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    std::env::temp_dir().join(format!(
        "dnspilot-linux-cli-{name}-{}-{nanos}.json",
        std::process::id()
    ))
}

#[test]
fn cli_can_add_list_and_delete_custom_profiles_in_store() {
    let store = temp_path("profiles");

    let add = binary()
        .args([
            "profile-add",
            "--store",
            store.to_str().unwrap(),
            "--id",
            "local",
            "--name",
            "Local DNS",
            "--ipv4",
            "1.1.1.1",
            "--ipv6",
            "2606:4700:4700::1111",
        ])
        .output()
        .unwrap();
    assert!(add.status.success());
    assert!(String::from_utf8(add.stdout)
        .unwrap()
        .contains("Saved profile local"));

    let list = binary()
        .args(["profile-list", "--store", store.to_str().unwrap()])
        .output()
        .unwrap();
    assert!(list.status.success());
    let stdout = String::from_utf8(list.stdout).unwrap();
    assert!(stdout.contains("local\tLocal DNS\t1.1.1.1\t2606:4700:4700::1111"));

    let delete = binary()
        .args([
            "profile-delete",
            "--store",
            store.to_str().unwrap(),
            "--id",
            "local",
        ])
        .output()
        .unwrap();
    assert!(delete.status.success());
    assert!(String::from_utf8(delete.stdout)
        .unwrap()
        .contains("Deleted profile local"));

    let list = binary()
        .args(["profile-list", "--store", store.to_str().unwrap()])
        .output()
        .unwrap();
    assert!(list.status.success());
    assert!(String::from_utf8(list.stdout)
        .unwrap()
        .contains("No custom profiles"));
}

#[test]
fn cli_profile_add_rejects_invalid_family_before_saving() {
    let store = temp_path("invalid-profile");

    let output = binary()
        .args([
            "profile-add",
            "--store",
            store.to_str().unwrap(),
            "--id",
            "bad",
            "--name",
            "Bad",
            "--ipv4",
            "2606:4700:4700::1111",
        ])
        .output()
        .unwrap();

    assert!(!output.status.success());
    assert!(String::from_utf8(output.stderr)
        .unwrap()
        .contains("InvalidIpv4"));
}

#[test]
fn cli_plan_uses_stored_profiles_and_session_controls() {
    let store = temp_path("plan");
    let add = binary()
        .args([
            "profile-add",
            "--store",
            store.to_str().unwrap(),
            "--id",
            "local",
            "--name",
            "Local DNS",
            "--ipv4",
            "1.1.1.1",
            "--ipv6",
            "2606:4700:4700::1111",
        ])
        .output()
        .unwrap();
    assert!(add.status.success());

    let output = binary()
        .args([
            "plan",
            "--store",
            store.to_str().unwrap(),
            "--package",
            "snap",
            "--catalog-vietnam",
            "--profile-id",
            "local",
            "--resolver-family",
            "ipv4",
            "--record-family",
            "a",
            "--suite-id",
            "vietnam-daily",
            "--domain",
            "login.microsoftonline.com",
        ])
        .output()
        .unwrap();

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("path-compare"));
    assert!(stdout.contains("--resolver local=1.1.1.1"));
    assert!(stdout.contains("--suite-id vietnam-daily"));
    assert!(stdout.contains("--domain login.microsoftonline.com"));
    assert!(stdout.contains("--ip-family ipv4-only"));
    assert!(stdout.contains("--progress-jsonl"));
}
