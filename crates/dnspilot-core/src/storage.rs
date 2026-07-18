use crate::{
    BenchmarkMetrics, DnsPilotError, DnsProfile, MeasurementScope, RecommendationGate,
    RecommendationMode, TestSuite,
};
use rusqlite::{params, Connection, OptionalExtension, Transaction, TransactionBehavior};
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::path::Path;
use std::time::Duration;

pub const STORAGE_SCHEMA_VERSION: u32 = 1;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct StorageSnapshot {
    pub schema_version: u32,
    pub profiles: Vec<DnsProfile>,
    pub test_suites: Vec<TestSuite>,
    pub benchmark_history: Vec<BenchmarkHistoryRecord>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct BenchmarkHistoryRecord {
    pub id: String,
    pub started_at: String,
    pub scope: MeasurementScope,
    pub mode: RecommendationMode,
    pub domains: Vec<String>,
    pub resolver_profile_ids: Vec<String>,
    pub metrics: Vec<BenchmarkMetrics>,
    pub gate: RecommendationGate,
    pub recommendation_profile_id: Option<String>,
    pub notes: Vec<String>,
}

pub struct SqliteStorage {
    connection: Connection,
}

impl SqliteStorage {
    pub fn open(path: impl AsRef<Path>) -> Result<Self, DnsPilotError> {
        let storage = Self {
            connection: Connection::open(path).map_err(storage_error)?,
        };
        storage
            .connection
            .busy_timeout(Duration::from_secs(5))
            .map_err(storage_error)?;
        storage.initialize()?;
        Ok(storage)
    }

    pub fn open_in_memory() -> Result<Self, DnsPilotError> {
        let storage = Self {
            connection: Connection::open_in_memory().map_err(storage_error)?,
        };
        storage
            .connection
            .busy_timeout(Duration::from_secs(5))
            .map_err(storage_error)?;
        storage.initialize()?;
        Ok(storage)
    }

    pub fn save_snapshot(&mut self, snapshot: &StorageSnapshot) -> Result<(), DnsPilotError> {
        validate_storage_snapshot(snapshot)?;
        let transaction = self
            .connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage_error)?;
        save_snapshot_in_transaction(&transaction, snapshot)?;
        transaction.commit().map_err(storage_error)?;
        Ok(())
    }

    /// Serializes a read-modify-write update so concurrent CLI invocations cannot lose changes.
    pub fn mutate_snapshot<T, F>(
        &mut self,
        initial_snapshot: StorageSnapshot,
        mutation: F,
    ) -> Result<T, DnsPilotError>
    where
        F: FnOnce(&mut StorageSnapshot) -> Result<T, DnsPilotError>,
    {
        let transaction = self
            .connection
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(storage_error)?;
        let payload: Option<String> = transaction
            .query_row(
                "SELECT payload_json FROM storage_snapshots WHERE id = 1",
                [],
                |row| row.get(0),
            )
            .optional()
            .map_err(storage_error)?;
        let mut snapshot = match payload {
            Some(payload) => serde_json::from_str(&payload).map_err(storage_error)?,
            None => initial_snapshot,
        };

        validate_storage_snapshot(&snapshot)?;
        let result = mutation(&mut snapshot)?;
        validate_storage_snapshot(&snapshot)?;
        save_snapshot_in_transaction(&transaction, &snapshot)?;
        transaction.commit().map_err(storage_error)?;
        Ok(result)
    }

    pub fn load_snapshot(&self) -> Result<StorageSnapshot, DnsPilotError> {
        let payload: String = self
            .connection
            .query_row(
                "SELECT payload_json FROM storage_snapshots WHERE id = 1",
                [],
                |row| row.get(0),
            )
            .map_err(storage_error)?;
        let snapshot: StorageSnapshot = serde_json::from_str(&payload).map_err(storage_error)?;
        validate_storage_snapshot(&snapshot)?;
        Ok(snapshot)
    }

    fn initialize(&self) -> Result<(), DnsPilotError> {
        self.connection
            .execute_batch(
                "CREATE TABLE IF NOT EXISTS storage_metadata (
                    key TEXT PRIMARY KEY NOT NULL,
                    value TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS storage_snapshots (
                    id INTEGER PRIMARY KEY CHECK (id = 1),
                    payload_json TEXT NOT NULL
                );",
            )
            .map_err(storage_error)?;
        Ok(())
    }
}

fn save_snapshot_in_transaction(
    transaction: &Transaction<'_>,
    snapshot: &StorageSnapshot,
) -> Result<(), DnsPilotError> {
    let payload = serde_json::to_string(snapshot).map_err(storage_error)?;
    transaction
        .execute(
            "INSERT INTO storage_metadata (key, value) VALUES ('schema_version', ?1)
             ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            params![snapshot.schema_version.to_string()],
        )
        .map_err(storage_error)?;
    transaction
        .execute(
            "INSERT INTO storage_snapshots (id, payload_json) VALUES (1, ?1)
             ON CONFLICT(id) DO UPDATE SET payload_json = excluded.payload_json",
            params![payload],
        )
        .map_err(storage_error)?;
    Ok(())
}

pub fn validate_storage_snapshot(snapshot: &StorageSnapshot) -> Result<(), DnsPilotError> {
    if snapshot.schema_version != STORAGE_SCHEMA_VERSION {
        return Err(DnsPilotError::InvalidStorage(format!(
            "unsupported storage schema version {}",
            snapshot.schema_version
        )));
    }

    ensure_unique_ids(
        snapshot.profiles.iter().map(|profile| profile.id.as_str()),
        "profile",
    )?;
    ensure_unique_ids(
        snapshot.test_suites.iter().map(|suite| suite.id.as_str()),
        "test suite",
    )?;
    ensure_unique_ids(
        snapshot
            .benchmark_history
            .iter()
            .map(|record| record.id.as_str()),
        "benchmark history",
    )?;

    for profile in &snapshot.profiles {
        profile.validate()?;
    }
    for suite in &snapshot.test_suites {
        suite.validate()?;
    }
    for record in &snapshot.benchmark_history {
        validate_history_record(record)?;
    }

    Ok(())
}

fn storage_error(error: impl std::error::Error) -> DnsPilotError {
    DnsPilotError::InvalidStorage(error.to_string())
}

fn ensure_unique_ids<'a, I>(ids: I, label: &str) -> Result<(), DnsPilotError>
where
    I: IntoIterator<Item = &'a str>,
{
    let mut seen = BTreeSet::new();
    for id in ids {
        if id.trim().is_empty() {
            return Err(DnsPilotError::InvalidStorage(format!(
                "{label} id cannot be empty"
            )));
        }
        if !seen.insert(id) {
            return Err(DnsPilotError::InvalidStorage(format!(
                "duplicate {label} id '{id}'"
            )));
        }
    }
    Ok(())
}

fn validate_history_record(record: &BenchmarkHistoryRecord) -> Result<(), DnsPilotError> {
    if record.started_at.trim().is_empty() {
        return Err(DnsPilotError::InvalidStorage(format!(
            "benchmark history '{}' needs started_at",
            record.id
        )));
    }
    if record.domains.is_empty() {
        return Err(DnsPilotError::InvalidStorage(format!(
            "benchmark history '{}' needs at least one domain",
            record.id
        )));
    }
    if record.resolver_profile_ids.is_empty() {
        return Err(DnsPilotError::InvalidStorage(format!(
            "benchmark history '{}' needs at least one resolver profile id",
            record.id
        )));
    }
    if record.metrics.is_empty() {
        return Err(DnsPilotError::InvalidStorage(format!(
            "benchmark history '{}' needs metrics",
            record.id
        )));
    }
    Ok(())
}
