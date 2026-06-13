use serde_json::Value;
use std::fs;
use std::net::{SocketAddr, UdpSocket};
use std::process::Command;
use std::thread;

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

#[test]
fn profile_add_command_rejects_duplicate_profile_id() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-profile-add-duplicate-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);

    add_plain_profile(&db_path, "custom-lab", "Custom Lab", "4.4.4.4");

    let duplicate = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "profile-add",
            "--db",
            db_path.to_str().expect("utf8 path"),
            "--id",
            "custom-lab",
            "--name",
            "Duplicate Custom Lab",
            "--ipv4",
            "8.8.8.8",
        ])
        .output()
        .expect("run dnspilot-cli profile-add duplicate");

    assert!(
        !duplicate.status.success(),
        "profile-add should reject duplicate IDs"
    );
    let stderr = String::from_utf8_lossy(&duplicate.stderr);
    assert!(stderr.contains("already exists"), "stderr: {stderr}");

    let _ = fs::remove_file(db_path);
}

#[test]
fn profile_update_command_replaces_custom_plain_dns_profile() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-profile-update-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);

    add_plain_profile(&db_path, "custom-lab", "Custom Lab", "4.4.4.4");

    let update = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "profile-update",
            "--db",
            db_path.to_str().expect("utf8 path"),
            "--id",
            "custom-lab",
            "--name",
            "Custom Lab Updated",
            "--ipv4",
            "8.8.8.8",
            "--tag",
            "custom",
        ])
        .output()
        .expect("run dnspilot-cli profile-update");

    assert!(
        update.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&update.stderr)
    );

    let profiles = list_profiles(&db_path);
    let profile = profiles
        .iter()
        .find(|profile| profile["id"] == "custom-lab")
        .expect("updated custom profile");

    assert_eq!(profile["name"], "Custom Lab Updated");
    assert_eq!(profile["ipv4_servers"][0], "8.8.8.8");
    assert!(!profile["ipv4_servers"]
        .as_array()
        .expect("ipv4")
        .iter()
        .any(|ip| ip == "4.4.4.4"));

    let _ = fs::remove_file(db_path);
}

#[test]
fn profile_update_command_rejects_builtin_profile() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-profile-update-builtin-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);

    let update = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "profile-update",
            "--db",
            db_path.to_str().expect("utf8 path"),
            "--id",
            "cloudflare",
            "--name",
            "Cloudflare Edited",
            "--ipv4",
            "8.8.8.8",
        ])
        .output()
        .expect("run dnspilot-cli profile-update");

    assert!(
        !update.status.success(),
        "profile-update should reject built-in profiles"
    );
    let stderr = String::from_utf8_lossy(&update.stderr);
    assert!(
        stderr.contains("cannot update built-in profile"),
        "stderr: {stderr}"
    );

    let _ = fs::remove_file(db_path);
}

#[test]
fn profile_delete_command_removes_custom_plain_dns_profile() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-profile-delete-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);

    add_plain_profile(&db_path, "custom-lab", "Custom Lab", "4.4.4.4");

    let delete = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "profile-delete",
            "--db",
            db_path.to_str().expect("utf8 path"),
            "--id",
            "custom-lab",
        ])
        .output()
        .expect("run dnspilot-cli profile-delete");

    assert!(
        delete.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&delete.stderr)
    );

    let profiles = list_profiles(&db_path);
    assert!(!profiles.iter().any(|profile| profile["id"] == "custom-lab"));

    let _ = fs::remove_file(db_path);
}

#[test]
fn profile_delete_command_rejects_builtin_profile() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-profile-delete-builtin-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);

    let delete = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "profile-delete",
            "--db",
            db_path.to_str().expect("utf8 path"),
            "--id",
            "cloudflare",
        ])
        .output()
        .expect("run dnspilot-cli profile-delete");

    assert!(
        !delete.status.success(),
        "profile-delete should reject built-in profiles"
    );
    let stderr = String::from_utf8_lossy(&delete.stderr);
    assert!(
        stderr.contains("cannot delete built-in profile"),
        "stderr: {stderr}"
    );

    let _ = fs::remove_file(db_path);
}

#[test]
fn profile_add_command_rejects_mismatched_ipv4_server() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-profile-mismatched-ipv4-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);

    let add = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "profile-add",
            "--db",
            db_path.to_str().expect("utf8 path"),
            "--id",
            "bad-v4",
            "--name",
            "Bad IPv4",
            "--ipv4",
            "::1",
        ])
        .output()
        .expect("run dnspilot-cli profile-add");

    assert!(
        !add.status.success(),
        "profile-add should reject IPv6 in IPv4 list"
    );
    let stderr = String::from_utf8_lossy(&add.stderr);
    assert!(stderr.contains("IPv4 DNS server"), "stderr: {stderr}");

    let _ = fs::remove_file(db_path);
}

#[test]
fn profile_add_command_persists_custom_encrypted_dns_profiles() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-profile-encrypted-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);

    let doh = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "profile-add",
            "--db",
            db_path.to_str().expect("utf8 path"),
            "--id",
            "custom-doh",
            "--name",
            "Custom DoH",
            "--protocol",
            "doh",
            "--doh-url",
            "https://dns.example/dns-query",
        ])
        .output()
        .expect("run dnspilot-cli profile-add DoH");

    assert!(
        doh.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&doh.stderr)
    );

    let dot = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "profile-add",
            "--db",
            db_path.to_str().expect("utf8 path"),
            "--id",
            "custom-dot",
            "--name",
            "Custom DoT",
            "--protocol",
            "dot",
            "--dot-hostname",
            "dns.example",
        ])
        .output()
        .expect("run dnspilot-cli profile-add DoT");

    assert!(
        dot.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&dot.stderr)
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
        profile["id"] == "custom-doh"
            && profile["protocol"] == "doh"
            && profile["doh_url"] == "https://dns.example/dns-query"
    }));
    assert!(profiles.iter().any(|profile| {
        profile["id"] == "custom-dot"
            && profile["protocol"] == "dot"
            && profile["dot_hostname"] == "dns.example"
    }));

    let _ = fs::remove_file(db_path);
}

#[test]
fn profile_add_command_rejects_insecure_doh_url() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-profile-insecure-doh-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);

    let add = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "profile-add",
            "--db",
            db_path.to_str().expect("utf8 path"),
            "--id",
            "bad-doh",
            "--name",
            "Bad DoH",
            "--protocol",
            "doh",
            "--doh-url",
            "http://dns.example/dns-query",
        ])
        .output()
        .expect("run dnspilot-cli profile-add");

    assert!(
        !add.status.success(),
        "profile-add should reject insecure DoH URL"
    );
    let stderr = String::from_utf8_lossy(&add.stderr);
    assert!(
        stderr.contains("DoH URL must use https"),
        "stderr: {stderr}"
    );

    let _ = fs::remove_file(db_path);
}

#[test]
fn profile_add_command_persists_custom_filtering_type() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-profile-filtering-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);

    let add = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "profile-add",
            "--db",
            db_path.to_str().expect("utf8 path"),
            "--id",
            "family-filter",
            "--name",
            "Family Filter",
            "--ipv4",
            "1.1.1.3",
            "--filtering",
            "family",
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

    let profile = profiles
        .iter()
        .find(|profile| profile["id"] == "family-filter")
        .expect("custom filtering profile");
    assert_eq!(profile["filtering_type"], "family");
    assert!(profile["security_notes"]
        .as_array()
        .expect("security notes")
        .iter()
        .any(|note| note.as_str().unwrap_or("").contains("Filtered DNS")));

    let _ = fs::remove_file(db_path);
}

#[test]
fn benchmark_command_can_use_saved_plain_dns_profile() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-benchmark-profile-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);
    let resolver = start_fake_resolver(2);

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
            "127.0.0.1",
        ])
        .output()
        .expect("run dnspilot-cli profile-add");

    assert!(
        add.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&add.stderr)
    );

    let benchmark = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "benchmark",
            "--profile-db",
            db_path.to_str().expect("utf8 path"),
            "--profile-id",
            "custom-lab",
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
        .expect("run dnspilot-cli benchmark");

    assert!(
        benchmark.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&benchmark.stderr)
    );

    let stdout = String::from_utf8(benchmark.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");

    assert_eq!(json["metrics"]["profile_id"], "custom-lab");
    assert_eq!(json["metrics"]["failure_rate"], 0.0);
    assert_eq!(json["samples"].as_array().expect("samples").len(), 2);

    let _ = fs::remove_file(db_path);
}

#[test]
fn suite_add_command_persists_custom_domain_suite() {
    let db_path =
        std::env::temp_dir().join(format!("dnspilot-suite-add-{}.sqlite", std::process::id()));
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
            "--tag",
            "azure",
        ])
        .output()
        .expect("run dnspilot-cli suite-add");

    assert!(
        add.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&add.stderr)
    );

    let list = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args(["suite-list", "--db", db_path.to_str().expect("utf8 path")])
        .output()
        .expect("run dnspilot-cli suite-list");

    assert!(
        list.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&list.stderr)
    );

    let stdout = String::from_utf8(list.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");
    let suites = json["test_suites"].as_array().expect("test suites array");

    assert!(suites.iter().any(|suite| {
        suite["id"] == "azure-lab"
            && suite["name"] == "Azure Lab"
            && suite["domains"]
                .as_array()
                .expect("domains")
                .iter()
                .any(|domain| domain == "portal.azure.com")
    }));

    let _ = fs::remove_file(db_path);
}

#[test]
fn suite_add_command_rejects_invalid_domain() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-suite-invalid-domain-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);

    let add = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "suite-add",
            "--db",
            db_path.to_str().expect("utf8 path"),
            "--id",
            "invalid-suite",
            "--name",
            "Invalid Suite",
            "--domain",
            "bad domain",
        ])
        .output()
        .expect("run dnspilot-cli suite-add");

    assert!(
        !add.status.success(),
        "suite-add should reject invalid domain"
    );
    let stderr = String::from_utf8_lossy(&add.stderr);
    assert!(
        stderr.contains("invalid test suite domain"),
        "stderr: {stderr}"
    );

    let _ = fs::remove_file(db_path);
}

#[test]
fn suite_add_command_rejects_duplicate_suite_id() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-suite-duplicate-{}.sqlite",
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
        ])
        .output()
        .expect("run dnspilot-cli suite-add");
    assert!(
        add.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&add.stderr)
    );

    let duplicate = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "suite-add",
            "--db",
            db_path.to_str().expect("utf8 path"),
            "--id",
            "azure-lab",
            "--name",
            "Azure Lab",
            "--domain",
            "login.microsoftonline.com",
        ])
        .output()
        .expect("run dnspilot-cli suite-add duplicate");

    assert!(
        !duplicate.status.success(),
        "duplicate suite-add should fail"
    );
    let stderr = String::from_utf8_lossy(&duplicate.stderr);
    assert!(
        stderr.contains("test suite 'azure-lab' already exists"),
        "stderr: {stderr}"
    );

    let _ = fs::remove_file(db_path);
}

#[test]
fn suite_update_command_replaces_custom_domain_suite() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-suite-update-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);
    add_suite(
        &db_path,
        "azure-lab",
        "Azure Lab",
        &["portal.azure.com", "login.microsoftonline.com"],
    );

    let update = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "suite-update",
            "--db",
            db_path.to_str().expect("utf8 path"),
            "--id",
            "azure-lab",
            "--name",
            "Azure Lab Updated",
            "--domain",
            "management.azure.com",
            "--domain",
            "blob.core.windows.net",
            "--tag",
            "custom",
        ])
        .output()
        .expect("run dnspilot-cli suite-update");

    assert!(
        update.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&update.stderr)
    );

    let suites = list_suites(&db_path);
    let suite = suites
        .iter()
        .find(|suite| suite["id"] == "azure-lab")
        .expect("updated custom suite");

    assert_eq!(suite["name"], "Azure Lab Updated");
    assert_eq!(suite["domains"][0], "management.azure.com");
    assert!(suite["domains"]
        .as_array()
        .expect("domains")
        .iter()
        .all(|domain| domain != "portal.azure.com"));

    let _ = fs::remove_file(db_path);
}

#[test]
fn suite_update_command_rejects_builtin_suite() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-suite-update-builtin-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);

    let update = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "suite-update",
            "--db",
            db_path.to_str().expect("utf8 path"),
            "--id",
            "general",
            "--name",
            "General Edited",
            "--domain",
            "example.com",
        ])
        .output()
        .expect("run dnspilot-cli suite-update");

    assert!(
        !update.status.success(),
        "suite-update should reject built-in suites"
    );
    let stderr = String::from_utf8_lossy(&update.stderr);
    assert!(
        stderr.contains("cannot update built-in test suite"),
        "stderr: {stderr}"
    );

    let _ = fs::remove_file(db_path);
}

#[test]
fn suite_delete_command_removes_custom_domain_suite() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-suite-delete-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);
    add_suite(&db_path, "azure-lab", "Azure Lab", &["portal.azure.com"]);

    let delete = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "suite-delete",
            "--db",
            db_path.to_str().expect("utf8 path"),
            "--id",
            "azure-lab",
        ])
        .output()
        .expect("run dnspilot-cli suite-delete");

    assert!(
        delete.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&delete.stderr)
    );

    let suites = list_suites(&db_path);
    assert!(!suites.iter().any(|suite| suite["id"] == "azure-lab"));

    let _ = fs::remove_file(db_path);
}

#[test]
fn suite_delete_command_rejects_builtin_suite() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-suite-delete-builtin-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);

    let delete = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "suite-delete",
            "--db",
            db_path.to_str().expect("utf8 path"),
            "--id",
            "general",
        ])
        .output()
        .expect("run dnspilot-cli suite-delete");

    assert!(
        !delete.status.success(),
        "suite-delete should reject built-in suites"
    );
    let stderr = String::from_utf8_lossy(&delete.stderr);
    assert!(
        stderr.contains("cannot delete built-in test suite"),
        "stderr: {stderr}"
    );

    let _ = fs::remove_file(db_path);
}

#[test]
fn benchmark_command_can_use_saved_domain_suite() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-benchmark-suite-{}.sqlite",
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

    let resolver = start_fake_resolver(4);
    let benchmark = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "benchmark",
            "--resolver",
            &resolver.to_string(),
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
        .expect("run dnspilot-cli benchmark");

    assert!(
        benchmark.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&benchmark.stderr)
    );

    let stdout = String::from_utf8(benchmark.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");
    let sample_domains = json["samples"]
        .as_array()
        .expect("samples")
        .iter()
        .map(|sample| sample["domain"].as_str().expect("domain"))
        .collect::<Vec<_>>();

    assert!(sample_domains.contains(&"portal.azure.com"));
    assert!(sample_domains.contains(&"login.microsoftonline.com"));

    let _ = fs::remove_file(db_path);
}

#[test]
fn benchmark_command_can_save_history_to_sqlite() {
    let db_path = std::env::temp_dir().join(format!(
        "dnspilot-benchmark-history-{}.sqlite",
        std::process::id()
    ));
    let _ = fs::remove_file(&db_path);
    let resolver = start_fake_resolver(2);

    let benchmark = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "benchmark",
            "--resolver",
            &resolver.to_string(),
            "--domain",
            "example.com",
            "--attempts",
            "1",
            "--timeout-ms",
            "500",
            "--profile-id",
            "custom-lab",
            "--save-db",
            db_path.to_str().expect("utf8 path"),
            "--history-id",
            "run-1",
        ])
        .output()
        .expect("run dnspilot-cli benchmark");

    assert!(
        benchmark.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&benchmark.stderr)
    );
    let benchmark_stdout = String::from_utf8(benchmark.stdout).expect("stdout should be utf8");
    let benchmark_json: Value =
        serde_json::from_str(&benchmark_stdout).expect("stdout should be json");
    assert_eq!(benchmark_json["saved_history_id"], "run-1");

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
    assert_eq!(history[0]["id"], "run-1");
    assert_eq!(history[0]["scope"], "dns-only");
    assert_eq!(history[0]["resolver_profile_ids"][0], "custom-lab");

    let _ = fs::remove_file(db_path);
}

fn add_plain_profile(db_path: &std::path::Path, id: &str, name: &str, ipv4: &str) {
    let add = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args([
            "profile-add",
            "--db",
            db_path.to_str().expect("utf8 path"),
            "--id",
            id,
            "--name",
            name,
            "--ipv4",
            ipv4,
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
}

fn list_profiles(db_path: &std::path::Path) -> Vec<Value> {
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
    json["profiles"].as_array().expect("profiles array").clone()
}

fn add_suite(db_path: &std::path::Path, id: &str, name: &str, domains: &[&str]) {
    let mut args = vec![
        "suite-add".to_string(),
        "--db".to_string(),
        db_path.to_str().expect("utf8 path").to_string(),
        "--id".to_string(),
        id.to_string(),
        "--name".to_string(),
        name.to_string(),
    ];
    for domain in domains {
        args.push("--domain".to_string());
        args.push((*domain).to_string());
    }
    args.push("--tag".to_string());
    args.push("custom".to_string());

    let add = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args(args)
        .output()
        .expect("run dnspilot-cli suite-add");

    assert!(
        add.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&add.stderr)
    );
}

fn list_suites(db_path: &std::path::Path) -> Vec<Value> {
    let list = Command::new(env!("CARGO_BIN_EXE_dnspilot-cli"))
        .args(["suite-list", "--db", db_path.to_str().expect("utf8 path")])
        .output()
        .expect("run dnspilot-cli suite-list");

    assert!(
        list.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&list.stderr)
    );

    let stdout = String::from_utf8(list.stdout).expect("stdout should be utf8");
    let json: Value = serde_json::from_str(&stdout).expect("stdout should be json");
    json["test_suites"]
        .as_array()
        .expect("test suites array")
        .clone()
}

fn start_fake_resolver(query_count: usize) -> SocketAddr {
    let socket = UdpSocket::bind("127.0.0.1:0").expect("bind fake resolver");
    let addr = socket.local_addr().expect("local addr");

    thread::spawn(move || {
        let mut buffer = [0_u8; 512];
        for _ in 0..query_count {
            let (length, peer) = socket.recv_from(&mut buffer).expect("receive DNS query");
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
