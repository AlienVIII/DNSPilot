//! Shared DNS Pilot core.
//!
//! This crate intentionally contains no OS mutation code. Store-safe and power
//! editions call platform adapters around this core.

use serde::{Deserialize, Deserializer, Serialize};
use std::collections::{BTreeMap, BTreeSet};
use std::net::{Ipv4Addr, Ipv6Addr};

pub mod connect_probe;
pub mod connection_path;
pub mod dns_benchmark;
pub mod dns_resolver;
pub mod dns_wire;
pub mod storage;
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
            return Err(DnsPilotError::InvalidProfile("profile name is required".into()));
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

        if self.protocol == DnsProtocol::Doh && self.doh_url.is_none() {
            return Err(DnsPilotError::InvalidProfile("DoH URL is required".into()));
        }

        if self.protocol == DnsProtocol::Dot && self.dot_hostname.is_none() {
            return Err(DnsPilotError::InvalidProfile("DoT hostname is required".into()));
        }

        Ok(())
    }
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

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RecommendationGate {
    pub can_recommend: bool,
    pub health: RecommendationHealth,
    pub primary_issue: RecommendationIssue,
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
    ]
}

pub fn built_in_test_suites() -> Vec<TestSuite> {
    vec![
        suite(
            "general",
            "General Browsing",
            "Common browsing, video, Apple, and CDN checks.",
            &["google.com", "youtube.com", "facebook.com", "apple.com", "cloudflare.com"],
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
            &["vnexpress.net", "shopee.vn", "tiki.vn", "zalo.me", "google.com", "youtube.com"],
            &["vietnam", "daily"],
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

    let mut reasons = vec![format!(
        "Best connection-path estimate for {:?} mode.",
        mode
    )];
    let mut caveats = vec![
        "This estimates DNS and HTTPS connection behavior, not full browser or app speed.".into(),
    ];

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

pub fn recommendation_gate(
    metrics: &[BenchmarkMetrics],
    scope: MeasurementScope,
) -> RecommendationGate {
    if metrics.is_empty() {
        return RecommendationGate {
            can_recommend: false,
            health: RecommendationHealth::Inconclusive,
            primary_issue: RecommendationIssue::NoResolvers,
            notes: vec!["No benchmark candidates were provided.".into()],
        };
    }

    if metrics.iter().all(|metric| metric.failure_rate >= 1.0) {
        return RecommendationGate {
            can_recommend: false,
            health: RecommendationHealth::Failed,
            primary_issue: RecommendationIssue::AllResolversFailed,
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
            notes: vec!["No candidate produced a usable connection-path target.".into()],
        };
    }

    if metrics.iter().all(|metric| metric.reliability() < 0.95) {
        return RecommendationGate {
            can_recommend: true,
            health: RecommendationHealth::Degraded,
            primary_issue: RecommendationIssue::AllResolversLowReliability,
            notes: vec![
                "All candidates have reduced reliability; apply prompts should be conservative."
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
            notes: vec!["At least one candidate had partial failure or timeout.".into()],
        };
    }

    RecommendationGate {
        can_recommend: true,
        health: RecommendationHealth::Healthy,
        primary_issue: RecommendationIssue::None,
        notes: Vec::new(),
    }
}

pub fn classify_resolution_outcome(
    outcome: ResolutionOutcome,
    filtering_type: FilteringType,
    mode: RecommendationMode,
) -> ClassifiedOutcome {
    let expected_filtering_block = outcome == ResolutionOutcome::Blocked
        && matches!(filtering_type, FilteringType::Family | FilteringType::Malware | FilteringType::Ads | FilteringType::Security)
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
        RecommendationMode::BestForSecurity
        | RecommendationMode::BestForFamilyFiltering => (0.15, 0.15, 0.15, 0.25, 0.05, 0.25),
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

fn suite(
    id: &str,
    name: &str,
    description: &str,
    domains: &[&str],
    tags: &[&str],
) -> TestSuite {
    TestSuite {
        id: id.into(),
        name: name.into(),
        description: description.into(),
        domains: domains.iter().map(|domain| (*domain).into()).collect(),
        tags: tags.iter().map(|tag| (*tag).into()).collect(),
    }
}
