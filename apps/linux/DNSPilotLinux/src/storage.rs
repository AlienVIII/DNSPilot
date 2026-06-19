use crate::profiles::PlainDnsProfile;
use serde_json::{json, Value};
use std::fs;
use std::io::ErrorKind;
use std::path::PathBuf;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ProfileStorageError {
    Io(String),
    InvalidJson(String),
    UnsupportedSchema(i64),
    InvalidProfile(String),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FileProfileRepository {
    pub path: PathBuf,
}

impl FileProfileRepository {
    pub fn new(path: impl Into<PathBuf>) -> Self {
        Self { path: path.into() }
    }

    pub fn load_profiles(&self) -> Result<Vec<PlainDnsProfile>, ProfileStorageError> {
        let raw = match fs::read_to_string(&self.path) {
            Ok(raw) => raw,
            Err(error) if error.kind() == ErrorKind::NotFound => return Ok(Vec::new()),
            Err(error) => return Err(ProfileStorageError::Io(error.to_string())),
        };
        let value = serde_json::from_str::<Value>(&raw)
            .map_err(|error| ProfileStorageError::InvalidJson(error.to_string()))?;
        let schema_version = value
            .get("schema_version")
            .and_then(Value::as_i64)
            .ok_or_else(|| {
                ProfileStorageError::InvalidJson("missing schema_version".to_string())
            })?;
        if schema_version != 1 {
            return Err(ProfileStorageError::UnsupportedSchema(schema_version));
        }
        let profiles = value
            .get("profiles")
            .and_then(Value::as_array)
            .ok_or_else(|| ProfileStorageError::InvalidJson("missing profiles".to_string()))?;

        profiles.iter().map(parse_profile).collect()
    }

    pub fn save_profiles(&self, profiles: &[PlainDnsProfile]) -> Result<(), ProfileStorageError> {
        if let Some(parent) = self.path.parent() {
            fs::create_dir_all(parent)
                .map_err(|error| ProfileStorageError::Io(error.to_string()))?;
        }

        let profiles_json = profiles
            .iter()
            .map(|profile| {
                json!({
                    "id": profile.id,
                    "name": profile.name,
                    "ipv4_servers": profile.ipv4_servers,
                    "ipv6_servers": profile.ipv6_servers,
                })
            })
            .collect::<Vec<_>>();
        let raw = json!({
            "schema_version": 1,
            "profiles": profiles_json,
        })
        .to_string();

        let tmp_path = self.path.with_extension("tmp");
        fs::write(&tmp_path, raw).map_err(|error| ProfileStorageError::Io(error.to_string()))?;
        fs::rename(&tmp_path, &self.path)
            .map_err(|error| ProfileStorageError::Io(error.to_string()))?;
        Ok(())
    }
}

fn parse_profile(value: &Value) -> Result<PlainDnsProfile, ProfileStorageError> {
    let id = required_string(value, "id")?;
    let name = required_string(value, "name")?;
    let ipv4_servers = required_string_array(value, "ipv4_servers")?;
    let ipv6_servers = required_string_array(value, "ipv6_servers")?;

    Ok(PlainDnsProfile {
        id,
        name,
        ipv4_servers,
        ipv6_servers,
    })
}

fn required_string(value: &Value, key: &str) -> Result<String, ProfileStorageError> {
    value
        .get(key)
        .and_then(Value::as_str)
        .map(str::to_string)
        .ok_or_else(|| ProfileStorageError::InvalidProfile(format!("missing string field {key}")))
}

fn required_string_array(value: &Value, key: &str) -> Result<Vec<String>, ProfileStorageError> {
    let array = value
        .get(key)
        .and_then(Value::as_array)
        .ok_or_else(|| ProfileStorageError::InvalidProfile(format!("missing array field {key}")))?;

    array
        .iter()
        .map(|item| {
            item.as_str().map(str::to_string).ok_or_else(|| {
                ProfileStorageError::InvalidProfile(format!("{key} must contain strings"))
            })
        })
        .collect()
}
