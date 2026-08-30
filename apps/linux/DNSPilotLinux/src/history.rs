use crate::capabilities::BenchmarkMode;
use crate::core_adapter::CoreHistoryRecord;

const SYSTEM_DNS_PROFILE_ID: &str = "system-dns";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HistoryRunRestore {
    pub mode: BenchmarkMode,
    pub profile_ids: Vec<String>,
    pub domains: Vec<String>,
    pub uses_current_system_resolver: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum HistoryRestoreError {
    MissingProfile(String),
    SystemResolverUnavailable,
    UnsupportedScope(String),
}

pub fn restore_history_run(
    record: &CoreHistoryRecord,
    available_profile_ids: &[String],
    can_validate_current_system_resolver: bool,
) -> Result<HistoryRunRestore, HistoryRestoreError> {
    if record.resolver_profile_ids.as_slice() == [SYSTEM_DNS_PROFILE_ID] {
        if !can_validate_current_system_resolver {
            return Err(HistoryRestoreError::SystemResolverUnavailable);
        }
        return Ok(HistoryRunRestore {
            mode: BenchmarkMode::CurrentSystemResolver,
            profile_ids: Vec::new(),
            domains: record.domains.clone(),
            uses_current_system_resolver: true,
        });
    }

    for profile_id in &record.resolver_profile_ids {
        if !available_profile_ids.contains(profile_id) {
            return Err(HistoryRestoreError::MissingProfile(profile_id.clone()));
        }
    }

    let mode = match record.scope.as_str() {
        "dns-only" => BenchmarkMode::DnsOnly,
        "dns-tcp" | "dns-tcp-tls" => BenchmarkMode::DnsAndTcp,
        scope => return Err(HistoryRestoreError::UnsupportedScope(scope.to_string())),
    };
    Ok(HistoryRunRestore {
        mode,
        profile_ids: record.resolver_profile_ids.clone(),
        domains: record.domains.clone(),
        uses_current_system_resolver: false,
    })
}
