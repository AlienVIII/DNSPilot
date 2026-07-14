use crate::profiles::PlainDnsProfile;
use crate::storage::FileProfileRepository;
use serde_json::Value;
use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

pub const CORE_CONTRACT_SCHEMA_VERSION: u64 = 1;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CoreCliAdapterError {
    CommandFailed(String),
    InvalidJson(String),
    UnsupportedSchema(u64),
    MissingField(String),
    Io(String),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CoreCliOutput {
    pub stdout: String,
    pub stderr: String,
}

pub trait CoreCliCommandRunner {
    fn run(&mut self, program: &str, args: &[String])
        -> Result<CoreCliOutput, CoreCliAdapterError>;
}

#[derive(Debug, Default, Clone, Copy, PartialEq, Eq)]
pub struct ProcessCoreCliCommandRunner;

impl CoreCliCommandRunner for ProcessCoreCliCommandRunner {
    fn run(
        &mut self,
        program: &str,
        args: &[String],
    ) -> Result<CoreCliOutput, CoreCliAdapterError> {
        let output = Command::new(program)
            .args(args)
            .output()
            .map_err(|error| CoreCliAdapterError::CommandFailed(error.to_string()))?;
        let stdout = String::from_utf8_lossy(&output.stdout).to_string();
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();
        if output.status.success() {
            Ok(CoreCliOutput { stdout, stderr })
        } else {
            Err(CoreCliAdapterError::CommandFailed(
                if stderr.trim().is_empty() {
                    format!("{program} exited with {}", output.status)
                } else {
                    stderr.trim().to_string()
                },
            ))
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CoreProfile {
    pub id: String,
    pub name: String,
    pub ipv4_servers: Vec<String>,
    pub ipv6_servers: Vec<String>,
}

impl From<CoreProfile> for PlainDnsProfile {
    fn from(profile: CoreProfile) -> Self {
        Self {
            id: profile.id,
            name: profile.name,
            ipv4_servers: profile.ipv4_servers,
            ipv6_servers: profile.ipv6_servers,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CoreSuite {
    pub id: String,
    pub name: String,
    pub description: String,
    pub domains: Vec<String>,
    pub tags: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CoreCatalog {
    pub schema_version: u64,
    pub profiles: Vec<CoreProfile>,
    pub suites: Vec<CoreSuite>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CoreHistoryRecord {
    pub id: String,
    pub started_at: String,
    pub domains: Vec<String>,
    pub resolver_profile_ids: Vec<String>,
    pub recommendation_profile_id: Option<String>,
    pub notes: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CoreApplyPolicy {
    pub disposition: String,
    pub can_prompt_apply: bool,
    pub notes: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CoreApplyPlan {
    pub disposition: String,
    pub profile_id: Option<String>,
    pub profile_name: Option<String>,
    pub tested_resolver: Option<String>,
    pub dns_servers: Vec<String>,
    pub can_apply: bool,
    pub notes: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CoreBenchmarkResult {
    pub recommended_profile_id: Option<String>,
    pub can_recommend: bool,
    pub warning: String,
    pub saved_history_id: Option<String>,
}

impl CoreBenchmarkResult {
    pub fn from_json(payload: &str) -> Result<Self, CoreCliAdapterError> {
        let value = parse_payload(payload)?;
        let summary = value
            .get("summary")
            .ok_or_else(|| CoreCliAdapterError::MissingField("summary".to_string()))?;
        Ok(Self {
            recommended_profile_id: optional_string(summary, "recommended_profile_id")?,
            can_recommend: required_bool(summary, "can_recommend")?,
            warning: required_string(&value, "warning")?,
            saved_history_id: optional_string(&value, "saved_history_id")?,
        })
    }
}

impl CoreCatalog {
    pub fn from_json(payload: &str) -> Result<Self, CoreCliAdapterError> {
        let value = parse_payload(payload)?;
        let schema_version = required_schema_version(&value)?;
        let profiles = required_array(&value, "profiles")?
            .iter()
            .map(parse_profile)
            .collect::<Result<Vec<_>, _>>()?;
        let suites = required_array(&value, "testSuites")?
            .iter()
            .map(parse_suite)
            .collect::<Result<Vec<_>, _>>()?;
        Ok(Self {
            schema_version,
            profiles,
            suites,
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LinuxDataPaths {
    data_directory: PathBuf,
}

impl LinuxDataPaths {
    pub fn from_data_home(data_home: impl Into<PathBuf>) -> Self {
        Self {
            data_directory: data_home.into().join("dnspilot"),
        }
    }

    pub fn from_environment() -> Self {
        if let Some(data_home) = std::env::var_os("XDG_DATA_HOME") {
            return Self::from_data_home(PathBuf::from(data_home));
        }
        if let Some(home) = std::env::var_os("HOME") {
            return Self::from_data_home(PathBuf::from(home).join(".local/share"));
        }
        Self::from_data_home(".")
    }

    pub fn core_database_path(&self) -> PathBuf {
        self.data_directory.join("dnspilot.sqlite")
    }

    pub fn legacy_profile_path(&self) -> PathBuf {
        self.data_directory.join("profiles.json")
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LegacyProfileMigration {
    pub migrated_profile_count: usize,
    pub skipped_profile_count: usize,
    pub backup_path: PathBuf,
}

pub struct CoreCliAdapter<R> {
    program: String,
    database_path: PathBuf,
    runner: R,
}

impl<R: CoreCliCommandRunner> CoreCliAdapter<R> {
    pub fn new(program: impl Into<String>, database_path: impl Into<PathBuf>, runner: R) -> Self {
        Self {
            program: program.into(),
            database_path: database_path.into(),
            runner,
        }
    }

    pub fn runner(&self) -> &R {
        &self.runner
    }

    pub fn load_catalog(&mut self) -> Result<CoreCatalog, CoreCliAdapterError> {
        let output = self.run(&["catalog"])?;
        CoreCatalog::from_json(&output.stdout)
    }

    pub fn load_profiles(&mut self) -> Result<Vec<CoreProfile>, CoreCliAdapterError> {
        self.ensure_database_parent()?;
        let output = self.run(&["profile-list", "--db", self.database_path_string().as_str()])?;
        parse_profile_list(&output.stdout)
    }

    pub fn load_suites(&mut self) -> Result<Vec<CoreSuite>, CoreCliAdapterError> {
        self.ensure_database_parent()?;
        let output = self.run(&["suite-list", "--db", self.database_path_string().as_str()])?;
        let value = parse_payload(&output.stdout)?;
        required_schema_version(&value)?;
        required_array(&value, "test_suites")?
            .iter()
            .map(parse_suite)
            .collect()
    }

    pub fn load_history(&mut self) -> Result<Vec<CoreHistoryRecord>, CoreCliAdapterError> {
        self.ensure_database_parent()?;
        let output = self.run(&["history-list", "--db", self.database_path_string().as_str()])?;
        let value = parse_payload(&output.stdout)?;
        required_schema_version(&value)?;
        required_array(&value, "benchmark_history")?
            .iter()
            .map(parse_history_record)
            .collect()
    }

    pub fn apply_policy(&mut self, platform: &str) -> Result<CoreApplyPolicy, CoreCliAdapterError> {
        let output = self.run(&["apply-policy", platform])?;
        parse_apply_policy(&output.stdout)
    }

    pub fn apply_plan(
        &mut self,
        platform: &str,
        profile_id: &str,
    ) -> Result<CoreApplyPlan, CoreCliAdapterError> {
        self.ensure_database_parent()?;
        let output = self.runner.run(
            &self.program,
            &[
                "apply-plan".to_string(),
                platform.to_string(),
                "--profile-db".to_string(),
                self.database_path_string(),
                "--profile-id".to_string(),
                profile_id.to_string(),
            ],
        )?;
        parse_apply_plan(&output.stdout)
    }

    pub fn migrate_legacy_profiles_once(
        &mut self,
        legacy_path: &Path,
    ) -> Result<LegacyProfileMigration, CoreCliAdapterError> {
        if self.database_path.exists() || !legacy_path.exists() {
            return Ok(LegacyProfileMigration {
                migrated_profile_count: 0,
                skipped_profile_count: 0,
                backup_path: legacy_backup_path(legacy_path),
            });
        }

        let legacy_profiles = FileProfileRepository::new(legacy_path)
            .load_profiles()
            .map_err(|error| CoreCliAdapterError::InvalidJson(format!("{error:?}")))?;
        let existing_ids = self
            .load_profiles()?
            .into_iter()
            .map(|profile| profile.id)
            .collect::<HashSet<_>>();
        let mut migrated_profile_count = 0;
        let mut skipped_profile_count = 0;

        for profile in legacy_profiles {
            if existing_ids.contains(&profile.id) {
                skipped_profile_count += 1;
                continue;
            }
            self.add_plain_profile(&profile)?;
            migrated_profile_count += 1;
        }

        let backup_path = legacy_backup_path(legacy_path);
        fs::rename(legacy_path, &backup_path)
            .map_err(|error| CoreCliAdapterError::Io(error.to_string()))?;
        Ok(LegacyProfileMigration {
            migrated_profile_count,
            skipped_profile_count,
            backup_path,
        })
    }

    pub fn save_plain_profile(
        &mut self,
        profile: &PlainDnsProfile,
        update: bool,
    ) -> Result<(), CoreCliAdapterError> {
        self.write_plain_profile(
            profile,
            if update {
                "profile-update"
            } else {
                "profile-add"
            },
        )
    }

    pub fn delete_profile(&mut self, profile_id: &str) -> Result<(), CoreCliAdapterError> {
        self.ensure_database_parent()?;
        self.runner
            .run(
                &self.program,
                &[
                    "profile-delete".to_string(),
                    "--db".to_string(),
                    self.database_path_string(),
                    "--id".to_string(),
                    profile_id.to_string(),
                ],
            )
            .map(|_| ())
    }

    fn add_plain_profile(&mut self, profile: &PlainDnsProfile) -> Result<(), CoreCliAdapterError> {
        self.write_plain_profile(profile, "profile-add")
    }

    fn write_plain_profile(
        &mut self,
        profile: &PlainDnsProfile,
        command: &str,
    ) -> Result<(), CoreCliAdapterError> {
        self.ensure_database_parent()?;
        let mut args = vec![
            command.to_string(),
            "--db".to_string(),
            self.database_path_string(),
            "--id".to_string(),
            profile.id.clone(),
            "--name".to_string(),
            profile.name.clone(),
            "--protocol".to_string(),
            "plain".to_string(),
        ];
        for server in &profile.ipv4_servers {
            args.push("--ipv4".to_string());
            args.push(server.clone());
        }
        for server in &profile.ipv6_servers {
            args.push("--ipv6".to_string());
            args.push(server.clone());
        }
        self.runner.run(&self.program, &args).map(|_| ())
    }

    fn run(&mut self, args: &[&str]) -> Result<CoreCliOutput, CoreCliAdapterError> {
        self.runner.run(
            &self.program,
            &args
                .iter()
                .map(|arg| (*arg).to_string())
                .collect::<Vec<_>>(),
        )
    }

    fn database_path_string(&self) -> String {
        self.database_path.to_string_lossy().to_string()
    }

    fn ensure_database_parent(&self) -> Result<(), CoreCliAdapterError> {
        if let Some(parent) = self.database_path.parent() {
            fs::create_dir_all(parent)
                .map_err(|error| CoreCliAdapterError::Io(error.to_string()))?;
        }
        Ok(())
    }
}

fn parse_profile_list(payload: &str) -> Result<Vec<CoreProfile>, CoreCliAdapterError> {
    let value = parse_payload(payload)?;
    required_schema_version(&value)?;
    required_array(&value, "profiles")?
        .iter()
        .map(parse_profile)
        .collect()
}

fn parse_history_record(value: &Value) -> Result<CoreHistoryRecord, CoreCliAdapterError> {
    Ok(CoreHistoryRecord {
        id: required_string(value, "id")?,
        started_at: required_string(value, "started_at")?,
        domains: required_string_array(value, "domains")?,
        resolver_profile_ids: required_string_array(value, "resolver_profile_ids")?,
        recommendation_profile_id: optional_string(value, "recommendation_profile_id")?,
        notes: required_string_array(value, "notes")?,
    })
}

fn parse_apply_policy(payload: &str) -> Result<CoreApplyPolicy, CoreCliAdapterError> {
    let value = parse_payload(payload)?;
    required_schema_version(&value)?;
    Ok(CoreApplyPolicy {
        disposition: required_string(&value, "disposition")?,
        can_prompt_apply: required_bool(&value, "can_prompt_apply")?,
        notes: required_string_array(&value, "notes")?,
    })
}

fn parse_apply_plan(payload: &str) -> Result<CoreApplyPlan, CoreCliAdapterError> {
    let value = parse_payload(payload)?;
    required_schema_version(&value)?;
    Ok(CoreApplyPlan {
        disposition: required_string(&value, "disposition")?,
        profile_id: optional_string(&value, "profile_id")?,
        profile_name: optional_string(&value, "profile_name")?,
        tested_resolver: optional_string(&value, "tested_resolver")?,
        dns_servers: required_string_array(&value, "dns_servers")?,
        can_apply: required_bool(&value, "can_apply")?,
        notes: required_string_array(&value, "notes")?,
    })
}

fn parse_payload(payload: &str) -> Result<Value, CoreCliAdapterError> {
    serde_json::from_str(payload)
        .map_err(|error| CoreCliAdapterError::InvalidJson(error.to_string()))
}

fn required_schema_version(value: &Value) -> Result<u64, CoreCliAdapterError> {
    let schema_version = value
        .get("schema_version")
        .and_then(Value::as_u64)
        .ok_or_else(|| CoreCliAdapterError::MissingField("schema_version".to_string()))?;
    if schema_version != CORE_CONTRACT_SCHEMA_VERSION {
        return Err(CoreCliAdapterError::UnsupportedSchema(schema_version));
    }
    Ok(schema_version)
}

fn required_array<'a>(value: &'a Value, key: &str) -> Result<&'a Vec<Value>, CoreCliAdapterError> {
    value
        .get(key)
        .and_then(Value::as_array)
        .ok_or_else(|| CoreCliAdapterError::MissingField(key.to_string()))
}

fn parse_profile(value: &Value) -> Result<CoreProfile, CoreCliAdapterError> {
    Ok(CoreProfile {
        id: required_string(value, "id")?,
        name: required_string(value, "name")?,
        ipv4_servers: required_string_array(value, "ipv4_servers")?,
        ipv6_servers: required_string_array(value, "ipv6_servers")?,
    })
}

fn parse_suite(value: &Value) -> Result<CoreSuite, CoreCliAdapterError> {
    Ok(CoreSuite {
        id: required_string(value, "id")?,
        name: required_string(value, "name")?,
        description: value
            .get("description")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_string(),
        domains: required_string_array(value, "domains")?,
        tags: value
            .get("tags")
            .map(|_| required_string_array(value, "tags"))
            .transpose()?
            .unwrap_or_default(),
    })
}

fn required_string(value: &Value, key: &str) -> Result<String, CoreCliAdapterError> {
    value
        .get(key)
        .and_then(Value::as_str)
        .map(ToString::to_string)
        .ok_or_else(|| CoreCliAdapterError::MissingField(key.to_string()))
}

fn optional_string(value: &Value, key: &str) -> Result<Option<String>, CoreCliAdapterError> {
    match value.get(key) {
        None | Some(Value::Null) => Ok(None),
        Some(Value::String(item)) => Ok(Some(item.clone())),
        Some(_) => Err(CoreCliAdapterError::MissingField(key.to_string())),
    }
}

fn required_bool(value: &Value, key: &str) -> Result<bool, CoreCliAdapterError> {
    value
        .get(key)
        .and_then(Value::as_bool)
        .ok_or_else(|| CoreCliAdapterError::MissingField(key.to_string()))
}

fn required_string_array(value: &Value, key: &str) -> Result<Vec<String>, CoreCliAdapterError> {
    required_array(value, key)?
        .iter()
        .map(|item| {
            item.as_str()
                .map(ToString::to_string)
                .ok_or_else(|| CoreCliAdapterError::MissingField(key.to_string()))
        })
        .collect()
}

fn legacy_backup_path(legacy_path: &Path) -> PathBuf {
    let filename = legacy_path
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("profiles.json");
    legacy_path.with_file_name(format!("{filename}.migrated"))
}
