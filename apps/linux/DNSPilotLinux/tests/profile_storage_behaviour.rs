use std::fs;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

use dnspilot_linux_shell::profiles::PlainDnsProfile;
use dnspilot_linux_shell::storage::{FileProfileRepository, ProfileStorageError};

fn temp_path(name: &str) -> PathBuf {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    std::env::temp_dir().join(format!(
        "dnspilot-linux-{name}-{}-{nanos}.json",
        std::process::id()
    ))
}

fn profile(id: &str, name: &str, ipv4: Vec<&str>, ipv6: Vec<&str>) -> PlainDnsProfile {
    PlainDnsProfile {
        id: id.to_string(),
        name: name.to_string(),
        ipv4_servers: ipv4.into_iter().map(str::to_string).collect(),
        ipv6_servers: ipv6.into_iter().map(str::to_string).collect(),
    }
}

#[test]
fn missing_profile_store_loads_as_empty() {
    let repo = FileProfileRepository::new(temp_path("missing"));

    assert_eq!(repo.load_profiles().unwrap(), Vec::<PlainDnsProfile>::new());
}

#[test]
fn profile_store_round_trips_plain_dns_profiles() {
    let path = temp_path("roundtrip");
    let repo = FileProfileRepository::new(&path);
    let profiles = vec![
        profile(
            "cloudflare",
            "Cloudflare",
            vec!["1.1.1.1"],
            vec!["2606:4700:4700::1111"],
        ),
        profile("quad9", "Quad9", vec!["9.9.9.9", "149.112.112.112"], vec![]),
    ];

    repo.save_profiles(&profiles).unwrap();
    let loaded = repo.load_profiles().unwrap();

    assert_eq!(loaded, profiles);
    let raw = fs::read_to_string(path).unwrap();
    assert!(raw.contains("\"schema_version\":1"));
}

#[test]
fn profile_store_creates_parent_directory() {
    let dir = temp_path("nested-dir");
    let path = dir.join("profiles.json");
    let repo = FileProfileRepository::new(&path);

    repo.save_profiles(&[profile("local", "Local", vec!["192.168.1.1"], vec![])])
        .unwrap();

    assert_eq!(repo.load_profiles().unwrap().len(), 1);
}

#[test]
fn profile_store_rejects_unsupported_schema_version() {
    let path = temp_path("schema");
    fs::write(&path, r#"{"schema_version":99,"profiles":[]}"#).unwrap();
    let repo = FileProfileRepository::new(path);

    assert_eq!(
        repo.load_profiles(),
        Err(ProfileStorageError::UnsupportedSchema(99))
    );
}

#[test]
fn profile_store_rejects_invalid_profile_shape() {
    let path = temp_path("invalid-profile");
    fs::write(
        &path,
        r#"{"schema_version":1,"profiles":[{"id":"bad","name":"Bad","ipv4_servers":"1.1.1.1","ipv6_servers":[]}]}"#,
    )
    .unwrap();
    let repo = FileProfileRepository::new(path);

    let error = repo.load_profiles().unwrap_err();
    assert!(matches!(error, ProfileStorageError::InvalidProfile(_)));
}
