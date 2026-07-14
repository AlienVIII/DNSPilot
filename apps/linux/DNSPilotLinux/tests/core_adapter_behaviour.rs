use dnspilot_linux_shell::core_adapter::{
    CoreBenchmarkResult, CoreCatalog, CoreCliAdapter, CoreCliAdapterError, CoreCliCommandRunner,
    CoreCliOutput, LinuxDataPaths,
};
use std::fs;
use std::path::PathBuf;

#[test]
fn core_catalog_requires_the_supported_schema_and_preserves_vietnam_suite() {
    let catalog = CoreCatalog::from_json(
        r#"{
            "schema_version": 1,
            "profiles": [],
            "testSuites": [{
                "id": "vietnam-daily",
                "name": "Vietnam / Daily",
                "description": "Vietnam suite",
                "domains": ["vnexpress.net"],
                "tags": ["vietnam"]
            }]
        }"#,
    )
    .unwrap();

    assert_eq!(catalog.schema_version, 1);
    assert_eq!(catalog.suites[0].id, "vietnam-daily");
    assert_eq!(catalog.suites[0].domains, vec!["vnexpress.net"]);

    let error =
        CoreCatalog::from_json(r#"{"schema_version": 2, "profiles": [], "testSuites": []}"#)
            .unwrap_err();
    assert_eq!(error, CoreCliAdapterError::UnsupportedSchema(2));
}

#[test]
fn legacy_json_profiles_migrate_once_to_the_xdg_core_database_with_backup() {
    let root = temp_path("core-adapter-migration");
    let paths = LinuxDataPaths::from_data_home(root.clone());
    let legacy = paths.legacy_profile_path();
    fs::create_dir_all(legacy.parent().unwrap()).unwrap();
    fs::write(
        &legacy,
        r#"{"schema_version":1,"profiles":[{"id":"custom","name":"Custom DNS","ipv4_servers":["1.1.1.1"],"ipv6_servers":[]}] }"#,
    )
    .unwrap();
    let runner = RecordingRunner::default();
    let mut adapter = CoreCliAdapter::new("dnspilot-cli", paths.core_database_path(), runner);

    let outcome = adapter.migrate_legacy_profiles_once(&legacy).unwrap();

    assert_eq!(outcome.migrated_profile_count, 1);
    assert!(outcome.backup_path.exists());
    assert!(!legacy.exists());
    assert!(adapter
        .runner()
        .commands
        .iter()
        .any(|args| args[0] == "profile-add" && args.contains(&"custom".to_string())));

    let repeated = adapter.migrate_legacy_profiles_once(&legacy).unwrap();
    assert_eq!(repeated.migrated_profile_count, 0);
    assert!(!adapter.runner().commands.is_empty());
}

#[test]
fn legacy_migration_skips_existing_core_profile_ids_without_overwriting_them() {
    let root = temp_path("core-adapter-existing-profile");
    let paths = LinuxDataPaths::from_data_home(root);
    let legacy = paths.legacy_profile_path();
    fs::create_dir_all(legacy.parent().unwrap()).unwrap();
    fs::write(
        &legacy,
        r#"{"schema_version":1,"profiles":[
            {"id":"cloudflare","name":"Legacy Cloudflare","ipv4_servers":["1.1.1.1"],"ipv6_servers":[]},
            {"id":"custom","name":"Custom DNS","ipv4_servers":["9.9.9.9"],"ipv6_servers":[]}
        ]}"#,
    )
    .unwrap();
    let mut adapter = CoreCliAdapter::new(
        "dnspilot-cli",
        paths.core_database_path(),
        ExistingProfileRunner::default(),
    );

    let outcome = adapter.migrate_legacy_profiles_once(&legacy).unwrap();

    assert_eq!(outcome.migrated_profile_count, 1);
    assert_eq!(outcome.skipped_profile_count, 1);
    assert!(adapter.runner().commands.iter().any(|args| {
        args.first().map(String::as_str) == Some("profile-add")
            && args.contains(&"custom".to_string())
            && !args.contains(&"cloudflare".to_string())
    }));
}

#[test]
fn core_profile_load_creates_the_xdg_database_parent_before_invoking_cli() {
    let root = temp_path("core-adapter-data-path");
    let paths = LinuxDataPaths::from_data_home(root);
    let database_path = paths.core_database_path();
    let runner = RecordingRunner::default();
    let mut adapter = CoreCliAdapter::new("dnspilot-cli", database_path.clone(), runner);

    adapter.load_profiles().unwrap();

    assert!(database_path.parent().unwrap().exists());
}

#[test]
fn core_adapter_decodes_history_policy_apply_plan_and_benchmark_contracts() {
    let root = temp_path("core-adapter-contracts");
    let paths = LinuxDataPaths::from_data_home(root);
    let runner = ContractRunner::default();
    let mut adapter = CoreCliAdapter::new("dnspilot-cli", paths.core_database_path(), runner);

    let history = adapter.load_history().unwrap();
    let policy = adapter.apply_policy("linux-flatpak").unwrap();
    let plan = adapter.apply_plan("linux-flatpak", "custom").unwrap();
    let result = CoreBenchmarkResult::from_json(
        r#"{
            "summary": {"can_recommend": true, "recommended_profile_id": "custom"},
            "saved_history_id": "run-1",
            "warning": "Benchmark estimate only."
        }"#,
    )
    .unwrap();

    assert_eq!(history[0].id, "run-1");
    assert_eq!(
        history[0].recommendation_profile_id.as_deref(),
        Some("custom")
    );
    assert_eq!(policy.disposition, "guide-only");
    assert!(!policy.can_prompt_apply);
    assert_eq!(plan.profile_id.as_deref(), Some("custom"));
    assert!(!plan.can_apply);
    assert_eq!(result.recommended_profile_id.as_deref(), Some("custom"));
    assert!(adapter.runner().commands.iter().any(|args| args
        == &[
            "apply-plan",
            "linux-flatpak",
            "--profile-db",
            paths.core_database_path().to_str().unwrap(),
            "--profile-id",
            "custom"
        ]));
}

#[derive(Debug, Default, Clone)]
struct RecordingRunner {
    commands: Vec<Vec<String>>,
}

#[derive(Debug, Default, Clone)]
struct ContractRunner {
    commands: Vec<Vec<String>>,
}

impl CoreCliCommandRunner for ContractRunner {
    fn run(
        &mut self,
        _program: &str,
        args: &[String],
    ) -> Result<CoreCliOutput, CoreCliAdapterError> {
        self.commands.push(args.to_vec());
        let stdout = match args.first().map(String::as_str) {
            Some("history-list") => {
                r#"{
                "schema_version": 1,
                "benchmark_history": [{
                    "id": "run-1",
                    "started_at": "2026-07-14T00:00:00Z",
                    "domains": ["example.com"],
                    "resolver_profile_ids": ["custom"],
                    "recommendation_profile_id": "custom",
                    "notes": ["Saved by Core CLI."]
                }]
            }"#
            }
            Some("apply-policy") => {
                r#"{
                "schema_version": 1,
                "disposition": "guide-only",
                "can_prompt_apply": false,
                "notes": ["Store-safe guidance only."]
            }"#
            }
            Some("apply-plan") => {
                r#"{
                "schema_version": 1,
                "disposition": "guide-only",
                "profile_id": "custom",
                "profile_name": "Custom DNS",
                "tested_resolver": null,
                "dns_servers": ["1.1.1.1"],
                "can_apply": false,
                "notes": ["Guidance only."]
            }"#
            }
            _ => unreachable!("unexpected Core CLI command: {args:?}"),
        };
        Ok(CoreCliOutput {
            stdout: stdout.to_string(),
            stderr: String::new(),
        })
    }
}

#[derive(Debug, Default, Clone)]
struct ExistingProfileRunner {
    commands: Vec<Vec<String>>,
}

impl CoreCliCommandRunner for ExistingProfileRunner {
    fn run(
        &mut self,
        _program: &str,
        args: &[String],
    ) -> Result<CoreCliOutput, CoreCliAdapterError> {
        self.commands.push(args.to_vec());
        let stdout = if args.first().map(String::as_str) == Some("profile-list") {
            r#"{"schema_version":1,"profiles":[{
                "id":"cloudflare",
                "name":"Cloudflare",
                "ipv4_servers":["1.1.1.1"],
                "ipv6_servers":[]
            }]}"#
                .to_string()
        } else {
            "{}".to_string()
        };
        Ok(CoreCliOutput {
            stdout,
            stderr: String::new(),
        })
    }
}

impl CoreCliCommandRunner for RecordingRunner {
    fn run(
        &mut self,
        _program: &str,
        args: &[String],
    ) -> Result<CoreCliOutput, CoreCliAdapterError> {
        self.commands.push(args.to_vec());
        let stdout = if args.first().map(String::as_str) == Some("profile-list") {
            r#"{"schema_version":1,"profiles":[]}"#.to_string()
        } else {
            "{}".to_string()
        };
        Ok(CoreCliOutput {
            stdout,
            stderr: String::new(),
        })
    }
}

fn temp_path(name: &str) -> PathBuf {
    std::env::temp_dir().join(format!("dnspilot-linux-{name}-{}", std::process::id()))
}
