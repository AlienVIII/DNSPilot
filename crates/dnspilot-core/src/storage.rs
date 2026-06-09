use crate::{
    BenchmarkMetrics, DnsPilotError, DnsProfile, MeasurementScope, RecommendationGate,
    RecommendationMode, TestSuite,
};
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;

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
        if suite.id.trim().is_empty() {
            return Err(DnsPilotError::InvalidStorage(
                "test suite id cannot be empty".into(),
            ));
        }
        if suite.domains.is_empty() {
            return Err(DnsPilotError::InvalidStorage(format!(
                "test suite '{}' needs at least one domain",
                suite.id
            )));
        }
    }
    for record in &snapshot.benchmark_history {
        validate_history_record(record)?;
    }

    Ok(())
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
