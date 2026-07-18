//! Shared DNS Pilot core.
//!
//! This crate intentionally contains no OS mutation code. Store-safe and power
//! editions call platform adapters around this core.

use serde::{Deserialize, Deserializer, Serialize};
use std::collections::{BTreeMap, BTreeSet};
use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr};
use url::Url;

pub mod connect_probe;
pub mod connection_path;
pub mod dns_benchmark;
pub mod dns_resolver;
pub mod dns_wire;
pub mod storage;
pub mod system_dns;
pub mod tls_probe;

pub use storage::{
    validate_storage_snapshot, BenchmarkHistoryRecord, SqliteStorage, StorageSnapshot,
    STORAGE_SCHEMA_VERSION,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum DnsProtocol {
    Plain,
    Doh,
    Dot,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum FilteringType {
    None,
    Malware,
    Family,
    Ads,
    Security,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DnsProfile {
    pub id: String,
    pub name: String,
    pub description: String,
    pub ipv4_servers: Vec<String>,
    pub ipv6_servers: Vec<String>,
    pub protocol: DnsProtocol,
    pub doh_url: Option<String>,
    pub dot_hostname: Option<String>,
    pub tags: Vec<String>,
    pub use_case: String,
    pub filtering_type: FilteringType,
    pub security_notes: Vec<String>,
    pub provider_metadata: BTreeMap<String, String>,
    pub created_at: Option<String>,
    pub updated_at: Option<String>,
}

impl DnsProfile {
    pub fn validate(&self) -> Result<(), DnsPilotError> {
        if self.name.trim().is_empty() {
            return Err(DnsPilotError::InvalidProfile(
                "profile name is required".into(),
            ));
        }

        if self.protocol == DnsProtocol::Plain
            && self.ipv4_servers.is_empty()
            && self.ipv6_servers.is_empty()
        {
            return Err(DnsPilotError::InvalidProfile(
                "plain DNS profile needs at least one IPv4 or IPv6 server".into(),
            ));
        }

        let mut seen_servers = BTreeSet::new();
        for server in &self.ipv4_servers {
            let parsed = server.parse::<Ipv4Addr>().map_err(|_| {
                DnsPilotError::InvalidProfile(format!("invalid IPv4 DNS server '{server}'"))
            })?;
            if !seen_servers.insert(parsed.to_string()) {
                return Err(DnsPilotError::InvalidProfile(format!(
                    "duplicate DNS server '{server}'"
                )));
            }
        }
        for server in &self.ipv6_servers {
            let parsed = server.parse::<Ipv6Addr>().map_err(|_| {
                DnsPilotError::InvalidProfile(format!("invalid IPv6 DNS server '{server}'"))
            })?;
            if !seen_servers.insert(parsed.to_string()) {
                return Err(DnsPilotError::InvalidProfile(format!(
                    "duplicate DNS server '{server}'"
                )));
            }
        }

        if self.protocol == DnsProtocol::Doh {
            let doh_url = self
                .doh_url
                .as_deref()
                .ok_or_else(|| DnsPilotError::InvalidProfile("DoH URL is required".into()))?;
            validate_doh_url(doh_url)?;
        }

        if self.protocol == DnsProtocol::Dot {
            let dot_hostname = self
                .dot_hostname
                .as_deref()
                .ok_or_else(|| DnsPilotError::InvalidProfile("DoT hostname is required".into()))?;
            dns_wire::validate_domain_name(dot_hostname).map_err(|error| {
                DnsPilotError::InvalidProfile(format!(
                    "invalid DoT hostname '{dot_hostname}': {error}"
                ))
            })?;
        }

        Ok(())
    }
}

fn validate_doh_url(doh_url: &str) -> Result<(), DnsPilotError> {
    let parsed = Url::parse(doh_url).map_err(|error| {
        DnsPilotError::InvalidProfile(format!("invalid DoH URL '{doh_url}': {error}"))
    })?;
    if parsed.scheme() != "https" {
        return Err(DnsPilotError::InvalidProfile(
            "DoH URL must use https".into(),
        ));
    }
    if parsed.host_str().is_none() {
        return Err(DnsPilotError::InvalidProfile(
            "DoH URL requires a host".into(),
        ));
    }
    Ok(())
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TestSuite {
    pub id: String,
    pub name: String,
    pub description: String,
    pub domains: Vec<String>,
    pub tags: Vec<String>,
}

impl TestSuite {
    pub fn validate(&self) -> Result<(), DnsPilotError> {
        if self.id.trim().is_empty() {
            return Err(DnsPilotError::InvalidTestSuite(
                "test suite id is required".into(),
            ));
        }
        if self.name.trim().is_empty() {
            return Err(DnsPilotError::InvalidTestSuite(
                "test suite name is required".into(),
            ));
        }
        if self.domains.is_empty() {
            return Err(DnsPilotError::InvalidTestSuite(format!(
                "test suite '{}' needs at least one domain",
                self.id
            )));
        }

        let mut seen = BTreeSet::new();
        for domain in &self.domains {
            dns_wire::validate_domain_name(domain).map_err(|error| {
                DnsPilotError::InvalidTestSuite(format!(
                    "invalid test suite domain '{}': {error}",
                    domain
                ))
            })?;
            let normalized = domain.trim_end_matches('.').to_ascii_lowercase();
            if !seen.insert(normalized) {
                return Err(DnsPilotError::InvalidTestSuite(format!(
                    "duplicate test suite domain '{}'",
                    domain
                )));
            }
        }

        Ok(())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum RecommendationMode {
    BestOverall,
    FastestRawDns,
    MostStable,
    BestForAzureMicrosoft,
    BestForDeveloperWorkflow,
    BestForSecurity,
    BestForFamilyFiltering,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Confidence {
    High,
    Medium,
    Low,
    Inconclusive,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum RecommendationDecision {
    ApplyProfile(String),
    KeepCurrent,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum MeasurementScope {
    DnsOnly,
    DnsTcp,
    DnsTcpTls,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum RecommendationHealth {
    Healthy,
    Degraded,
    Failed,
    Inconclusive,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum RecommendationIssue {
    None,
    NoResolvers,
    NoConnectTargets,
    AllResolversFailed,
    AllResolversLowReliability,
    PartialFailure,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum RecommendationNote {
    NoBenchmarkCandidates,
    EveryCandidateFailed,
    NoConnectionPathTarget,
    AllCandidatesLowReliability,
    PartialFailureOrTimeout,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RecommendationGate {
    pub can_recommend: bool,
    pub health: RecommendationHealth,
    pub primary_issue: RecommendationIssue,
    #[serde(default)]
    pub note_ids: Vec<RecommendationNote>,
    pub notes: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct BenchmarkMetrics {
    pub profile_id: String,
    #[serde(deserialize_with = "deserialize_f64_or_infinity")]
    pub median_dns_latency_ms: f64,
    #[serde(deserialize_with = "deserialize_f64_or_infinity")]
    pub p95_dns_latency_ms: f64,
    pub failure_rate: f64,
    pub timeout_rate: f64,
    #[serde(deserialize_with = "deserialize_f64_or_infinity")]
    pub median_connect_latency_ms: f64,
    pub ipv4_health: f64,
    pub ipv6_health: f64,
    pub priority_fit: f64,
}

impl BenchmarkMetrics {
    pub fn reliability(&self) -> f64 {
        1.0 - self.failure_rate.max(self.timeout_rate).clamp(0.0, 1.0)
    }

    pub fn ip_health(&self) -> f64 {
        ((self.ipv4_health.clamp(0.0, 1.0) + self.ipv6_health.clamp(0.0, 1.0)) / 2.0)
            .clamp(0.0, 1.0)
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Recommendation {
    pub decision: RecommendationDecision,
    pub profile_id: String,
    pub score: f64,
    pub confidence: Confidence,
    pub reasons: Vec<String>,
    pub caveats: Vec<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ResolutionOutcome {
    Resolved,
    Timeout,
    Failed,
    Blocked,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ClassifiedOutcome {
    pub counts_as_failure: bool,
    pub note: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Platform {
    #[serde(rename = "macos-store")]
    MacOSStore,
    #[serde(rename = "ios")]
    IOS,
    #[serde(rename = "android-play")]
    AndroidPlay,
    #[serde(rename = "windows-store")]
    WindowsStore,
    #[serde(rename = "linux-flatpak")]
    LinuxFlatpak,
    #[serde(rename = "linux-snap")]
    LinuxSnap,
    #[serde(rename = "linux-native-power")]
    LinuxNativePower,
    #[serde(rename = "macos-power")]
    MacOSPower,
    #[serde(rename = "windows-power")]
    WindowsPower,
}

pub const ALL_PLATFORMS: [Platform; 9] = [
    Platform::MacOSStore,
    Platform::IOS,
    Platform::AndroidPlay,
    Platform::WindowsStore,
    Platform::LinuxFlatpak,
    Platform::LinuxSnap,
    Platform::LinuxNativePower,
    Platform::MacOSPower,
    Platform::WindowsPower,
];

pub const SHELL_PAYLOAD_SCHEMA_VERSION: u32 = 1;

pub fn all_platforms() -> &'static [Platform] {
    &ALL_PLATFORMS
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ApplyCapability {
    AppleNetworkExtensionDnsSettings,
    GuidedSettings,
    AndroidVpnService,
    LinuxNetworkManagerPolkit,
    DesktopAdminService,
    Unsupported,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum FlushCapability {
    GuidedUserAction,
    DesktopAdminService,
    LinuxSystemResolverPolkit,
    Unsupported,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PlatformCapability {
    pub platform: Platform,
    pub can_benchmark: bool,
    pub apply: ApplyCapability,
    pub flush: FlushCapability,
    pub store_safe: bool,
    pub notes: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CatalogPayload {
    pub schema_version: u32,
    pub profiles: Vec<DnsProfile>,
    #[serde(rename = "testSuites")]
    pub test_suites: Vec<TestSuite>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CapabilityMatrixPayload {
    pub schema_version: u32,
    pub capabilities: Vec<PlatformCapability>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum BenchmarkPreflightScope {
    DirectResolverBenchmark,
    SystemDnsValidation,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum FlushRequirement {
    NotNeeded,
    RecommendedBeforeTest,
    RecommendedButUnsupported,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BenchmarkPreflight {
    pub platform: Platform,
    pub scope: BenchmarkPreflightScope,
    pub flush_capability: FlushCapability,
    pub flush_requirement: FlushRequirement,
    pub notes: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BenchmarkPreflightPayload {
    pub schema_version: u32,
    #[serde(flatten)]
    pub preflight: BenchmarkPreflight,
}

#[derive(Debug, Clone, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct NetworkEnvironment {
    pub vpn_active: bool,
    pub mdm_profile_active: bool,
    pub corporate_dns_detected: bool,
    pub captive_portal_detected: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ApplyPromptDisposition {
    Allow,
    GuideOnly,
    ProtectCurrentDns,
    Unsupported,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ApplyPromptPolicy {
    pub platform: Platform,
    pub apply_capability: ApplyCapability,
    pub disposition: ApplyPromptDisposition,
    pub can_prompt_apply: bool,
    pub notes: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ApplyPromptPolicyPayload {
    pub schema_version: u32,
    #[serde(flatten)]
    pub policy: ApplyPromptPolicy,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ApplyPlanDisposition {
    ApplyWithUserApproval,
    GuideOnly,
    ProtectCurrentDns,
    Unsupported,
    NotRecommended,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ApplyPlan {
    pub platform: Platform,
    pub apply_capability: ApplyCapability,
    pub disposition: ApplyPlanDisposition,
    pub profile_id: Option<String>,
    pub profile_name: Option<String>,
    pub tested_resolver: Option<String>,
    pub dns_servers: Vec<String>,
    pub can_apply: bool,
    pub notes: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ApplyPlanPayload {
    pub schema_version: u32,
    #[serde(flatten)]
    pub plan: ApplyPlan,
}

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum DnsPilotError {
    #[error("no benchmark metrics provided")]
    EmptyBenchmark,
    #[error("invalid IP address: {0}")]
    InvalidIp(String),
    #[error("invalid DNS profile: {0}")]
    InvalidProfile(String),
    #[error("invalid test suite: {0}")]
    InvalidTestSuite(String),
    #[error("invalid storage snapshot: {0}")]
    InvalidStorage(String),
}

pub fn catalog_payload() -> CatalogPayload {
    CatalogPayload {
        schema_version: SHELL_PAYLOAD_SCHEMA_VERSION,
        profiles: built_in_profiles(),
        test_suites: built_in_test_suites(),
    }
}

pub fn capability_matrix_payload() -> CapabilityMatrixPayload {
    CapabilityMatrixPayload {
        schema_version: SHELL_PAYLOAD_SCHEMA_VERSION,
        capabilities: all_platforms()
            .iter()
            .copied()
            .map(capability_for)
            .collect(),
    }
}

pub fn benchmark_preflight_payload_for(
    platform: Platform,
    scope: BenchmarkPreflightScope,
) -> BenchmarkPreflightPayload {
    BenchmarkPreflightPayload {
        schema_version: SHELL_PAYLOAD_SCHEMA_VERSION,
        preflight: benchmark_preflight_for(platform, scope),
    }
}

pub fn apply_prompt_policy_payload_for(
    platform: Platform,
    environment: &NetworkEnvironment,
) -> ApplyPromptPolicyPayload {
    ApplyPromptPolicyPayload {
        schema_version: SHELL_PAYLOAD_SCHEMA_VERSION,
        policy: apply_prompt_policy_for(platform, environment),
    }
}

pub fn apply_plan_payload_for(
    platform: Platform,
    environment: &NetworkEnvironment,
    gate: &RecommendationGate,
    recommendation: Option<&Recommendation>,
    tested_resolver: Option<&str>,
    profiles: &[DnsProfile],
) -> ApplyPlanPayload {
    ApplyPlanPayload {
        schema_version: SHELL_PAYLOAD_SCHEMA_VERSION,
        plan: apply_plan_for(
            platform,
            environment,
            gate,
            recommendation,
            tested_resolver,
            profiles,
        ),
    }
}

pub fn apply_plan_for(
    platform: Platform,
    environment: &NetworkEnvironment,
    gate: &RecommendationGate,
    recommendation: Option<&Recommendation>,
    tested_resolver: Option<&str>,
    profiles: &[DnsProfile],
) -> ApplyPlan {
    let prompt_policy = apply_prompt_policy_for(platform, environment);
    let mut notes = prompt_policy.notes.clone();

    if !gate.can_recommend {
        notes.extend(gate.notes.clone());
        notes.push("Benchmark gate did not allow DNS changes.".into());
        return apply_plan(
            platform,
            prompt_policy.apply_capability,
            ApplyPlanDisposition::NotRecommended,
            None,
            None,
            None,
            Vec::new(),
            false,
            notes,
        );
    }

    if gate.health != RecommendationHealth::Healthy {
        notes.extend(gate.notes.clone());
        notes.push(
            "Recommendation is not healthy enough for apply; keep current DNS and retest.".into(),
        );
        return apply_plan(
            platform,
            prompt_policy.apply_capability,
            ApplyPlanDisposition::NotRecommended,
            None,
            None,
            None,
            Vec::new(),
            false,
            notes,
        );
    }

    let Some(recommendation) = recommendation else {
        notes.push("No benchmark recommendation was provided.".into());
        return apply_plan(
            platform,
            prompt_policy.apply_capability,
            ApplyPlanDisposition::NotRecommended,
            None,
            None,
            None,
            Vec::new(),
            false,
            notes,
        );
    };

    if !matches!(
        recommendation.confidence,
        Confidence::High | Confidence::Medium
    ) {
        notes.push(
            "Recommendation confidence is too low for apply; keep current DNS and retest.".into(),
        );
        return apply_plan(
            platform,
            prompt_policy.apply_capability,
            ApplyPlanDisposition::NotRecommended,
            Some(recommendation.profile_id.clone()),
            None,
            tested_resolver.map(str::to_string),
            Vec::new(),
            false,
            notes,
        );
    }

    let RecommendationDecision::ApplyProfile(recommended_profile_id) = &recommendation.decision
    else {
        notes.push("Recommendation says to keep current DNS.".into());
        return apply_plan(
            platform,
            prompt_policy.apply_capability,
            ApplyPlanDisposition::NotRecommended,
            Some(recommendation.profile_id.clone()),
            None,
            tested_resolver.map(str::to_string),
            Vec::new(),
            false,
            notes,
        );
    };

    if prompt_policy.disposition == ApplyPromptDisposition::ProtectCurrentDns {
        return apply_plan(
            platform,
            prompt_policy.apply_capability,
            ApplyPlanDisposition::ProtectCurrentDns,
            Some(recommended_profile_id.clone()),
            None,
            tested_resolver.map(str::to_string),
            Vec::new(),
            false,
            notes,
        );
    }

    if prompt_policy.disposition == ApplyPromptDisposition::Unsupported {
        notes.push("Platform does not support DNS apply prompts.".into());
        return apply_plan(
            platform,
            prompt_policy.apply_capability,
            ApplyPlanDisposition::Unsupported,
            Some(recommended_profile_id.clone()),
            None,
            tested_resolver.map(str::to_string),
            Vec::new(),
            false,
            notes,
        );
    }

    let Some(profile) = profiles
        .iter()
        .find(|profile| profile.id == *recommended_profile_id)
    else {
        notes.push("Recommended profile was not found in the loaded catalog.".into());
        return apply_plan(
            platform,
            prompt_policy.apply_capability,
            ApplyPlanDisposition::Unsupported,
            Some(recommended_profile_id.clone()),
            None,
            tested_resolver.map(str::to_string),
            Vec::new(),
            false,
            notes,
        );
    };

    match profile.protocol {
        DnsProtocol::Plain => plain_dns_apply_plan(
            platform,
            prompt_policy.apply_capability,
            profile,
            tested_resolver,
            notes,
        ),
        DnsProtocol::Doh | DnsProtocol::Dot => encrypted_dns_apply_plan(
            platform,
            prompt_policy.apply_capability,
            profile,
            tested_resolver,
            notes,
        ),
    }
}

fn plain_dns_apply_plan(
    platform: Platform,
    apply_capability: ApplyCapability,
    profile: &DnsProfile,
    tested_resolver: Option<&str>,
    mut notes: Vec<String>,
) -> ApplyPlan {
    let dns_servers = ordered_plain_dns_servers(profile, tested_resolver, &mut notes);
    if dns_servers.is_empty() {
        notes.push("Plain DNS profile has no IPv4 or IPv6 server addresses.".into());
        return apply_plan(
            platform,
            apply_capability,
            ApplyPlanDisposition::Unsupported,
            Some(profile.id.clone()),
            Some(profile.name.clone()),
            tested_resolver.map(str::to_string),
            dns_servers,
            false,
            notes,
        );
    }

    let power_adapter_available = matches!(
        platform,
        Platform::MacOSPower | Platform::WindowsPower | Platform::LinuxNativePower
    );
    if power_adapter_available {
        notes.push(
            "Power/native adapter may apply plain DNS with explicit user approval or privilege."
                .into(),
        );
        return apply_plan(
            platform,
            apply_capability,
            ApplyPlanDisposition::ApplyWithUserApproval,
            Some(profile.id.clone()),
            Some(profile.name.clone()),
            tested_resolver.map(str::to_string),
            dns_servers,
            true,
            notes,
        );
    }

    notes.push("Store-safe build must guide plain DNS changes through OS settings.".into());
    apply_plan(
        platform,
        apply_capability,
        ApplyPlanDisposition::GuideOnly,
        Some(profile.id.clone()),
        Some(profile.name.clone()),
        tested_resolver.map(str::to_string),
        dns_servers,
        false,
        notes,
    )
}

fn encrypted_dns_apply_plan(
    platform: Platform,
    apply_capability: ApplyCapability,
    profile: &DnsProfile,
    tested_resolver: Option<&str>,
    mut notes: Vec<String>,
) -> ApplyPlan {
    if matches!(platform, Platform::MacOSStore | Platform::IOS)
        && apply_capability == ApplyCapability::AppleNetworkExtensionDnsSettings
    {
        notes.push(
            "Apple DNS Settings profile can be offered only through explicit user enablement."
                .into(),
        );
        return apply_plan(
            platform,
            apply_capability,
            ApplyPlanDisposition::ApplyWithUserApproval,
            Some(profile.id.clone()),
            Some(profile.name.clone()),
            tested_resolver.map(str::to_string),
            Vec::new(),
            true,
            notes,
        );
    }

    notes.push("Encrypted DNS apply is not available for this platform/build yet.".into());
    apply_plan(
        platform,
        apply_capability,
        ApplyPlanDisposition::Unsupported,
        Some(profile.id.clone()),
        Some(profile.name.clone()),
        tested_resolver.map(str::to_string),
        Vec::new(),
        false,
        notes,
    )
}

fn apply_plan(
    platform: Platform,
    apply_capability: ApplyCapability,
    disposition: ApplyPlanDisposition,
    profile_id: Option<String>,
    profile_name: Option<String>,
    tested_resolver: Option<String>,
    dns_servers: Vec<String>,
    can_apply: bool,
    notes: Vec<String>,
) -> ApplyPlan {
    ApplyPlan {
        platform,
        apply_capability,
        disposition,
        profile_id,
        profile_name,
        tested_resolver,
        dns_servers,
        can_apply,
        notes,
    }
}

fn ordered_plain_dns_servers(
    profile: &DnsProfile,
    tested_resolver: Option<&str>,
    notes: &mut Vec<String>,
) -> Vec<String> {
    let mut dns_servers = profile
        .ipv4_servers
        .iter()
        .chain(profile.ipv6_servers.iter())
        .cloned()
        .collect::<Vec<_>>();

    let Some(tested_ip) = tested_resolver_ip(tested_resolver) else {
        return dns_servers;
    };

    if let Some(index) = dns_servers.iter().position(|server| *server == tested_ip) {
        let primary = dns_servers.remove(index);
        dns_servers.insert(0, primary);
        notes.push(
            "Apply plan keeps the measured resolver first; remaining DNS servers are provider fallbacks."
                .into(),
        );
    } else {
        notes.push(
            "Measured resolver was not found in the profile DNS server list; provider fallback order is unchanged."
                .into(),
        );
    }

    dns_servers
}

fn tested_resolver_ip(tested_resolver: Option<&str>) -> Option<String> {
    let tested_resolver = tested_resolver?.trim();
    if tested_resolver.is_empty() {
        return None;
    }

    tested_resolver
        .parse::<SocketAddr>()
        .map(|address| address.ip().to_string())
        .or_else(|_| {
            tested_resolver
                .parse::<IpAddr>()
                .map(|address| address.to_string())
        })
        .ok()
}

pub fn built_in_profiles() -> Vec<DnsProfile> {
    vec![
        profile(
            "cloudflare",
            "Cloudflare",
            "Fast unfiltered public DNS.",
            &["1.1.1.1", "1.0.0.1"],
            &["2606:4700:4700::1111", "2606:4700:4700::1001"],
            FilteringType::None,
            &["general", "unfiltered"],
        ),
        profile(
            "cloudflare-malware",
            "Cloudflare Malware Blocking",
            "Cloudflare DNS with malware blocking.",
            &["1.1.1.2", "1.0.0.2"],
            &["2606:4700:4700::1112", "2606:4700:4700::1002"],
            FilteringType::Malware,
            &["security", "filtered"],
        ),
        profile(
            "cloudflare-family",
            "Cloudflare Family",
            "Cloudflare DNS with malware and adult-content filtering.",
            &["1.1.1.3", "1.0.0.3"],
            &["2606:4700:4700::1113", "2606:4700:4700::1003"],
            FilteringType::Family,
            &["family", "filtered"],
        ),
        profile(
            "google-public-dns",
            "Google Public DNS",
            "Google unfiltered public DNS.",
            &["8.8.8.8", "8.8.4.4"],
            &["2001:4860:4860::8888", "2001:4860:4860::8844"],
            FilteringType::None,
            &["general", "unfiltered"],
        ),
        profile(
            "quad9",
            "Quad9",
            "Security-oriented DNS that blocks known malicious domains.",
            &["9.9.9.9", "149.112.112.112"],
            &["2620:fe::fe", "2620:fe::9"],
            FilteringType::Security,
            &["security", "filtered"],
        ),
        profile(
            "opendns",
            "OpenDNS",
            "Cisco OpenDNS public resolver.",
            &["208.67.222.222", "208.67.220.220"],
            &["2620:119:35::35", "2620:119:53::53"],
            FilteringType::None,
            &["general", "unfiltered"],
        ),
        profile(
            "opendns-familyshield",
            "OpenDNS FamilyShield",
            "OpenDNS resolver preconfigured for family filtering.",
            &["208.67.222.123", "208.67.220.123"],
            &[],
            FilteringType::Family,
            &["family", "filtered"],
        ),
        profile(
            "adguard-dns",
            "AdGuard DNS",
            "Ad-blocking and privacy-oriented DNS.",
            &["94.140.14.14", "94.140.15.15"],
            &["2a10:50c0::ad1:ff", "2a10:50c0::ad2:ff"],
            FilteringType::Ads,
            &["ads", "filtered"],
        ),
        profile(
            "cleanbrowsing-family",
            "CleanBrowsing Family",
            "Family filtering DNS profile.",
            &["185.228.168.168", "185.228.169.168"],
            &["2a0d:2a00:1::", "2a0d:2a00:2::"],
            FilteringType::Family,
            &["family", "filtered"],
        ),
        profile(
            "fpt-telecom-dns",
            "FPT Telecom DNS",
            "Vietnam ISP DNS from FPT Telecom.",
            &["210.245.24.20", "210.245.24.22"],
            &["2405:4800:0:1::1", "2405:4800:0:1::2"],
            FilteringType::None,
            &["vietnam", "isp", "unfiltered"],
        ),
        profile(
            "vnpt-dns",
            "VNPT DNS",
            "Vietnam ISP DNS commonly used on VNPT networks.",
            &["203.162.4.191", "203.162.4.190"],
            &[],
            FilteringType::None,
            &["vietnam", "isp", "unfiltered"],
        ),
        profile(
            "viettel-dns",
            "Viettel DNS",
            "Vietnam ISP DNS commonly used on Viettel networks.",
            &["203.113.131.1", "203.113.131.2"],
            &[],
            FilteringType::None,
            &["vietnam", "isp", "unfiltered"],
        ),
    ]
}

pub fn built_in_test_suites() -> Vec<TestSuite> {
    vec![
        suite(
            "general",
            "General Browsing",
            "Common browsing, video, Apple, and CDN checks.",
            &[
                "google.com",
                "youtube.com",
                "facebook.com",
                "apple.com",
                "cloudflare.com",
            ],
            &["general"],
        ),
        suite(
            "developer",
            "Developer",
            "GitHub, npm, Expo, and Docker workflow checks.",
            &[
                "github.com",
                "api.github.com",
                "registry.npmjs.org",
                "npmjs.com",
                "expo.dev",
                "docker.com",
            ],
            &["developer"],
        ),
        suite(
            "azure-microsoft",
            "Azure / Microsoft",
            "Microsoft login, Azure portal, APIs, storage, and CDN checks.",
            &[
                "portal.azure.com",
                "management.azure.com",
                "login.microsoftonline.com",
                "dev.azure.com",
                "azureedge.net",
                "blob.core.windows.net",
                "microsoft.com",
                "office.com",
            ],
            &["developer", "cloud", "microsoft"],
        ),
        suite(
            "youtube-google-video",
            "YouTube / Google Video",
            "YouTube player, short links, video CDN, thumbnails, and client API checks.",
            &[
                "youtube.com",
                "www.youtube.com",
                "youtu.be",
                "googlevideo.com",
                "ytimg.com",
                "youtubei.googleapis.com",
            ],
            &["video", "google", "youtube"],
        ),
        suite(
            "github-developer",
            "GitHub",
            "GitHub web, API, source download, raw content, and asset CDN checks.",
            &[
                "github.com",
                "api.github.com",
                "raw.githubusercontent.com",
                "codeload.github.com",
                "githubusercontent.com",
                "github.githubassets.com",
            ],
            &["developer", "github"],
        ),
        suite(
            "chatgpt-openai",
            "ChatGPT / OpenAI",
            "ChatGPT, OpenAI API, auth, static asset, and user-content domain checks.",
            &[
                "chatgpt.com",
                "openai.com",
                "api.openai.com",
                "auth.openai.com",
                "oaistatic.com",
                "oaiusercontent.com",
            ],
            &["ai", "chatgpt", "openai"],
        ),
        suite(
            "google-firebase",
            "Google / Firebase",
            "Firebase and Google API checks.",
            &[
                "firebase.googleapis.com",
                "firestore.googleapis.com",
                "fcm.googleapis.com",
                "googleapis.com",
                "accounts.google.com",
            ],
            &["developer", "cloud", "google"],
        ),
        suite(
            "vietnam-daily",
            "Vietnam / Daily",
            "Vietnamese commerce, media, messaging, and general browsing checks.",
            &[
                "vnexpress.net",
                "shopee.vn",
                "tiki.vn",
                "zalo.me",
                "google.com",
                "youtube.com",
            ],
            &["vietnam", "daily"],
        ),
        suite(
            "gaming-steam-valve",
            "Gaming / Steam + Valve",
            "Steam, Valve services, and CDN reachability checks. This is a DNS/TCP latency preset, not ICMP game-server ping.",
            &[
                "steampowered.com",
                "steamcommunity.com",
                "steamcontent.com",
                "api.steampowered.com",
                "valvesoftware.com",
            ],
            &["gaming", "steam", "valve"],
        ),
        suite(
            "gaming-dota2-sea",
            "Gaming / Dota 2 SEA",
            "Dota 2 and Steam service reachability for Southeast Asia-oriented checks. Actual match servers can differ by session.",
            &[
                "dota2.com",
                "steamcommunity.com",
                "steampowered.com",
                "steamcontent.com",
                "api.steampowered.com",
            ],
            &["gaming", "steam", "valve", "dota2", "sea"],
        ),
        suite(
            "gaming-cs2",
            "Gaming / CS2",
            "Counter-Strike 2 and Steam service reachability checks. This estimates DNS/TCP path behavior, not in-match UDP latency.",
            &[
                "counter-strike.net",
                "steamcommunity.com",
                "steampowered.com",
                "steamcontent.com",
                "api.steampowered.com",
            ],
            &["gaming", "steam", "valve", "cs2"],
        ),
        suite(
            "gaming-riot-lol",
            "Gaming / Riot + LoL",
            "Riot, League of Legends, and Riot CDN reachability checks. Region routing can vary by account and session.",
            &[
                "riotgames.com",
                "leagueoflegends.com",
                "lolesports.com",
                "riotcdn.net",
                "valorant.com",
            ],
            &["gaming", "riot", "league-of-legends"],
        ),
    ]
}

pub fn recommend(
    metrics: &[BenchmarkMetrics],
    current: Option<&BenchmarkMetrics>,
    mode: RecommendationMode,
) -> Result<Recommendation, DnsPilotError> {
    if metrics.is_empty() {
        return Err(DnsPilotError::EmptyBenchmark);
    }

    let scored: Vec<(&BenchmarkMetrics, f64)> = metrics
        .iter()
        .map(|metric| (metric, score_metric(metric, mode)))
        .collect();

    let (best, best_score) = scored
        .iter()
        .max_by(|(_, left), (_, right)| left.total_cmp(right))
        .map(|(metric, score)| (*metric, *score))
        .expect("metrics is not empty");

    let (primary_reason, scope_caveat) = recommendation_scope_text(mode);
    let mut reasons = vec![primary_reason];
    let mut caveats = vec![scope_caveat];

    if best.reliability() < 0.95 {
        caveats.push("Timeout or failure rate reduces confidence.".into());
    }
    if best.ipv6_health < 0.75 {
        caveats.push("IPv6 behavior looks weak on this network.".into());
    }

    if let Some(current) = current {
        let current_score = score_metric(current, mode);
        let improvement = best_score - current_score;
        if best.profile_id == current.profile_id || improvement < 0.03 {
            reasons.push("Improvement over current DNS is not meaningful.".into());
            return Ok(Recommendation {
                decision: RecommendationDecision::KeepCurrent,
                profile_id: current.profile_id.clone(),
                score: current_score,
                confidence: if current.reliability() >= 0.98 {
                    Confidence::Medium
                } else {
                    Confidence::Low
                },
                reasons,
                caveats,
            });
        }
    }

    let confidence = confidence_for(best, best_score);
    reasons.push(format!("Recommended profile: {}.", best.profile_id));

    Ok(Recommendation {
        decision: RecommendationDecision::ApplyProfile(best.profile_id.clone()),
        profile_id: best.profile_id.clone(),
        score: best_score,
        confidence,
        reasons,
        caveats,
    })
}

fn recommendation_scope_text(mode: RecommendationMode) -> (String, String) {
    match mode {
        RecommendationMode::FastestRawDns => (
            format!("Best DNS lookup estimate for {:?} mode.", mode),
            "This estimates DNS lookup behavior, not TCP, TLS, HTTP, QUIC, browser cache, VPN, MDM, captive portal, or app-specific behavior.".into(),
        ),
        _ => (
            format!("Best connection-path estimate for {:?} mode.", mode),
            "This estimates DNS and TCP connection behavior, not full HTTPS, browser, or app speed."
                .into(),
        ),
    }
}

pub fn recommendation_gate(
    metrics: &[BenchmarkMetrics],
    scope: MeasurementScope,
) -> RecommendationGate {
    if metrics.is_empty() {
        return RecommendationGate {
            can_recommend: false,
            health: RecommendationHealth::Inconclusive,
            primary_issue: RecommendationIssue::NoResolvers,
            note_ids: vec![RecommendationNote::NoBenchmarkCandidates],
            notes: vec!["No benchmark candidates were provided.".into()],
        };
    }

    if metrics.iter().all(|metric| metric.failure_rate >= 1.0) {
        return RecommendationGate {
            can_recommend: false,
            health: RecommendationHealth::Failed,
            primary_issue: RecommendationIssue::AllResolversFailed,
            note_ids: vec![RecommendationNote::EveryCandidateFailed],
            notes: vec!["Every candidate failed the measured scope.".into()],
        };
    }

    if scope != MeasurementScope::DnsOnly
        && metrics
            .iter()
            .all(|metric| !metric.median_connect_latency_ms.is_finite())
    {
        return RecommendationGate {
            can_recommend: false,
            health: RecommendationHealth::Inconclusive,
            primary_issue: RecommendationIssue::NoConnectTargets,
            note_ids: vec![RecommendationNote::NoConnectionPathTarget],
            notes: vec!["No candidate produced a usable connection-path target.".into()],
        };
    }

    if metrics.iter().all(|metric| metric.reliability() < 0.95) {
        return RecommendationGate {
            can_recommend: false,
            health: RecommendationHealth::Degraded,
            primary_issue: RecommendationIssue::AllResolversLowReliability,
            note_ids: vec![RecommendationNote::AllCandidatesLowReliability],
            notes: vec![
                "All candidates have reduced reliability; Keep current DNS and retest on a stable network."
                    .into(),
            ],
        };
    }

    if metrics
        .iter()
        .any(|metric| metric.failure_rate > 0.0 || metric.timeout_rate > 0.0)
    {
        return RecommendationGate {
            can_recommend: true,
            health: RecommendationHealth::Degraded,
            primary_issue: RecommendationIssue::PartialFailure,
            note_ids: vec![RecommendationNote::PartialFailureOrTimeout],
            notes: vec!["At least one candidate had partial failure or timeout.".into()],
        };
    }

    RecommendationGate {
        can_recommend: true,
        health: RecommendationHealth::Healthy,
        primary_issue: RecommendationIssue::None,
        note_ids: Vec::new(),
        notes: Vec::new(),
    }
}

pub fn classify_resolution_outcome(
    outcome: ResolutionOutcome,
    filtering_type: FilteringType,
    mode: RecommendationMode,
) -> ClassifiedOutcome {
    let expected_filtering_block = outcome == ResolutionOutcome::Blocked
        && matches!(
            filtering_type,
            FilteringType::Family
                | FilteringType::Malware
                | FilteringType::Ads
                | FilteringType::Security
        )
        && matches!(
            mode,
            RecommendationMode::BestForFamilyFiltering | RecommendationMode::BestForSecurity
        );

    if expected_filtering_block {
        return ClassifiedOutcome {
            counts_as_failure: false,
            note: "Blocked result is expected for the selected filtering goal.".into(),
        };
    }

    match outcome {
        ResolutionOutcome::Resolved => ClassifiedOutcome {
            counts_as_failure: false,
            note: "Resolved.".into(),
        },
        ResolutionOutcome::Blocked | ResolutionOutcome::Failed | ResolutionOutcome::Timeout => {
            ClassifiedOutcome {
                counts_as_failure: true,
                note: "Counts against reliability for this test mode.".into(),
            }
        }
    }
}

pub fn capability_for(platform: Platform) -> PlatformCapability {
    match platform {
        Platform::MacOSStore => PlatformCapability {
            platform,
            can_benchmark: true,
            apply: ApplyCapability::AppleNetworkExtensionDnsSettings,
            flush: FlushCapability::GuidedUserAction,
            store_safe: true,
            notes: vec![
                "DoH/DoT DNS Settings require explicit user enablement.".into(),
                "Store builds should guide DNS cache flush rather than running system commands."
                    .into(),
            ],
        },
        Platform::IOS => PlatformCapability {
            platform,
            can_benchmark: true,
            apply: ApplyCapability::AppleNetworkExtensionDnsSettings,
            flush: FlushCapability::Unsupported,
            store_safe: true,
            notes: vec![
                "Plain system DNS switching is not available to normal apps.".into(),
                "System DNS cache flush is not available to normal apps.".into(),
            ],
        },
        Platform::AndroidPlay => PlatformCapability {
            platform,
            can_benchmark: true,
            apply: ApplyCapability::GuidedSettings,
            flush: FlushCapability::GuidedUserAction,
            store_safe: true,
            notes: vec![
                "VpnService is deferred until disclosure and policy review are ready.".into(),
                "Store builds should guide users through network/private DNS reset steps.".into(),
            ],
        },
        Platform::WindowsStore => PlatformCapability {
            platform,
            can_benchmark: true,
            apply: ApplyCapability::GuidedSettings,
            flush: FlushCapability::GuidedUserAction,
            store_safe: true,
            notes: vec![
                "Store builds must not depend on administrator elevation.".into(),
                "DNS cache flush should be guided unless an admin service is installed.".into(),
            ],
        },
        Platform::LinuxFlatpak => PlatformCapability {
            platform,
            can_benchmark: true,
            apply: ApplyCapability::GuidedSettings,
            flush: FlushCapability::GuidedUserAction,
            store_safe: true,
            notes: vec![
                "Flatpak should avoid broad system D-Bus access for MVP.".into(),
                "Resolver cache flush varies by distro and should be guided in sandboxed builds."
                    .into(),
            ],
        },
        Platform::LinuxSnap => PlatformCapability {
            platform,
            can_benchmark: true,
            apply: ApplyCapability::GuidedSettings,
            flush: FlushCapability::GuidedUserAction,
            store_safe: true,
            notes: vec![
                "network-manager plug is privileged and not auto-connected.".into(),
                "Resolver cache flush varies by distro and snap interfaces.".into(),
            ],
        },
        Platform::LinuxNativePower => PlatformCapability {
            platform,
            can_benchmark: true,
            apply: ApplyCapability::LinuxNetworkManagerPolkit,
            flush: FlushCapability::LinuxSystemResolverPolkit,
            store_safe: false,
            notes: vec![
                "Native deb/rpm can use NetworkManager/systemd-resolved with polkit.".into(),
                "Resolver cache flush can use systemd-resolved or NetworkManager when available."
                    .into(),
            ],
        },
        Platform::MacOSPower | Platform::WindowsPower => PlatformCapability {
            platform,
            can_benchmark: true,
            apply: ApplyCapability::DesktopAdminService,
            flush: FlushCapability::DesktopAdminService,
            store_safe: false,
            notes: vec![
                "Power edition is separate from store-safe builds.".into(),
                "DNS cache flush requires an approved local helper/admin path.".into(),
            ],
        },
    }
}

pub fn benchmark_preflight_for(
    platform: Platform,
    scope: BenchmarkPreflightScope,
) -> BenchmarkPreflight {
    let capability = capability_for(platform);
    let (flush_requirement, notes) = match scope {
        BenchmarkPreflightScope::DirectResolverBenchmark => (
            FlushRequirement::NotNeeded,
            vec![
                "A direct resolver benchmark sends DNS queries to the selected resolver and bypasses the OS DNS cache.".into(),
                "Do not flush system DNS cache as a prerequisite for direct resolver scoring.".into(),
            ],
        ),
        BenchmarkPreflightScope::SystemDnsValidation => {
            let requirement = if capability.flush == FlushCapability::Unsupported {
                FlushRequirement::RecommendedButUnsupported
            } else {
                FlushRequirement::RecommendedBeforeTest
            };
            (
                requirement,
                vec![
                    "System DNS validation after apply can be polluted by stale OS resolver cache.".into(),
                    "Browser Secure DNS, VPN, MDM, captive portals, and app caches may still bypass or distort system DNS validation.".into(),
                ],
            )
        }
    };

    BenchmarkPreflight {
        platform,
        scope,
        flush_capability: capability.flush,
        flush_requirement,
        notes,
    }
}

pub fn apply_prompt_policy_for(
    platform: Platform,
    environment: &NetworkEnvironment,
) -> ApplyPromptPolicy {
    let capability = capability_for(platform);
    let mut notes = Vec::new();

    if environment.vpn_active {
        notes.push("VPN is active; protect current DNS and avoid apply prompts.".into());
    }
    if environment.mdm_profile_active {
        notes.push("MDM profile is active; protect current DNS and avoid apply prompts.".into());
    }
    if environment.corporate_dns_detected {
        notes.push(
            "corporate DNS was detected; protect current DNS and avoid apply prompts.".into(),
        );
    }
    if environment.captive_portal_detected {
        notes.push(
            "Captive portal was detected; finish portal login before DNS apply prompts.".into(),
        );
    }

    if !notes.is_empty() {
        return ApplyPromptPolicy {
            platform,
            apply_capability: capability.apply,
            disposition: ApplyPromptDisposition::ProtectCurrentDns,
            can_prompt_apply: false,
            notes,
        };
    }

    let (disposition, can_prompt_apply, note) = match capability.apply {
        ApplyCapability::GuidedSettings => (
            ApplyPromptDisposition::GuideOnly,
            true,
            "Platform requires guided settings; do not perform hidden DNS changes.",
        ),
        ApplyCapability::Unsupported => (
            ApplyPromptDisposition::Unsupported,
            false,
            "Platform does not support DNS apply prompts.",
        ),
        _ => (
            ApplyPromptDisposition::Allow,
            true,
            "Platform capability allows an explicit user-approved apply prompt.",
        ),
    };

    ApplyPromptPolicy {
        platform,
        apply_capability: capability.apply,
        disposition,
        can_prompt_apply,
        notes: vec![note.into()],
    }
}

fn score_metric(metric: &BenchmarkMetrics, mode: RecommendationMode) -> f64 {
    let median_dns = latency_score(metric.median_dns_latency_ms, 50.0);
    let p95 = latency_score(metric.p95_dns_latency_ms, 120.0);
    let connect = latency_score(metric.median_connect_latency_ms, 180.0);
    let reliability = metric.reliability();
    let ip_health = metric.ip_health();
    let priority = metric.priority_fit.clamp(0.0, 1.0);

    let weights = match mode {
        RecommendationMode::BestOverall => (0.25, 0.15, 0.25, 0.25, 0.05, 0.05),
        RecommendationMode::FastestRawDns => (0.70, 0.10, 0.05, 0.10, 0.03, 0.02),
        RecommendationMode::MostStable => (0.10, 0.30, 0.10, 0.35, 0.10, 0.05),
        RecommendationMode::BestForAzureMicrosoft
        | RecommendationMode::BestForDeveloperWorkflow => (0.20, 0.15, 0.30, 0.20, 0.05, 0.10),
        RecommendationMode::BestForSecurity | RecommendationMode::BestForFamilyFiltering => {
            (0.15, 0.15, 0.15, 0.25, 0.05, 0.25)
        }
    };

    median_dns * weights.0
        + p95 * weights.1
        + connect * weights.2
        + reliability * weights.3
        + ip_health * weights.4
        + priority * weights.5
}

fn latency_score(latency_ms: f64, expected_good_ms: f64) -> f64 {
    if !latency_ms.is_finite() || latency_ms < 0.0 {
        return 0.0;
    }
    (1.0 / (1.0 + latency_ms / expected_good_ms)).clamp(0.0, 1.0)
}

fn confidence_for(metric: &BenchmarkMetrics, score: f64) -> Confidence {
    if metric.failure_rate > 0.25 || metric.timeout_rate > 0.25 {
        Confidence::Inconclusive
    } else if score >= 0.80 && metric.reliability() >= 0.98 {
        Confidence::High
    } else if score >= 0.60 && metric.reliability() >= 0.95 {
        Confidence::Medium
    } else {
        Confidence::Low
    }
}

fn deserialize_f64_or_infinity<'de, D>(deserializer: D) -> Result<f64, D::Error>
where
    D: Deserializer<'de>,
{
    Ok(Option::<f64>::deserialize(deserializer)?.unwrap_or(f64::INFINITY))
}

fn profile(
    id: &str,
    name: &str,
    description: &str,
    ipv4_servers: &[&str],
    ipv6_servers: &[&str],
    filtering_type: FilteringType,
    tags: &[&str],
) -> DnsProfile {
    DnsProfile {
        id: id.into(),
        name: name.into(),
        description: description.into(),
        ipv4_servers: ipv4_servers.iter().map(|server| (*server).into()).collect(),
        ipv6_servers: ipv6_servers.iter().map(|server| (*server).into()).collect(),
        protocol: DnsProtocol::Plain,
        doh_url: None,
        dot_hostname: None,
        tags: tags.iter().map(|tag| (*tag).into()).collect(),
        use_case: if filtering_type == FilteringType::None {
            "performance".into()
        } else {
            "filtering".into()
        },
        filtering_type,
        security_notes: if filtering_type == FilteringType::None {
            vec![]
        } else {
            vec!["Filtered DNS may intentionally block some domains.".into()]
        },
        provider_metadata: BTreeMap::new(),
        created_at: None,
        updated_at: None,
    }
}

fn suite(id: &str, name: &str, description: &str, domains: &[&str], tags: &[&str]) -> TestSuite {
    TestSuite {
        id: id.into(),
        name: name.into(),
        description: description.into(),
        domains: domains.iter().map(|domain| (*domain).into()).collect(),
        tags: tags.iter().map(|tag| (*tag).into()).collect(),
    }
}
