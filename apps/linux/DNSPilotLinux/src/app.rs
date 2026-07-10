use crate::benchmark::LinuxBenchmarkPlan;
use crate::benchmark::ResolverSelection;
use crate::capabilities::{
    available_benchmark_modes, BenchmarkMode, LinuxCapabilityViewModel, LinuxPackageKind,
};
use crate::profiles::PlainDnsProfile;
use crate::settings::{profile_servers_for_family, DnsRecordFamily, ResolverAddressFamily};
use crate::suites::SuiteViewModel;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LinuxAppSession {
    pub capability: LinuxCapabilityViewModel,
    pub suites: Vec<SuiteViewModel>,
    pub profiles: Vec<PlainDnsProfile>,
    pub selected_mode: BenchmarkMode,
    pub selected_profile_ids: Vec<String>,
    pub selected_suite_id: Option<String>,
    pub custom_domains: Vec<String>,
    pub resolver_address_family: ResolverAddressFamily,
    pub record_family: DnsRecordFamily,
    pub attempts: u16,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RunReadiness {
    pub can_run: bool,
    pub issues: Vec<String>,
}

impl LinuxAppSession {
    pub fn new(
        capability: LinuxCapabilityViewModel,
        suites: Vec<SuiteViewModel>,
        profiles: Vec<PlainDnsProfile>,
    ) -> Self {
        let selected_profile_ids = profiles.iter().map(|profile| profile.id.clone()).collect();
        let selected_suite_id = suites.first().map(|suite| suite.id.to_string());
        Self {
            capability,
            suites,
            profiles,
            selected_mode: BenchmarkMode::DnsAndTcp,
            selected_profile_ids,
            selected_suite_id,
            custom_domains: Vec::new(),
            resolver_address_family: ResolverAddressFamily::Auto,
            record_family: DnsRecordFamily::AAndAaaa,
            attempts: 3,
        }
    }

    pub fn select_mode(&mut self, mode: BenchmarkMode) -> Result<(), String> {
        if available_benchmark_modes(&self.capability).contains(&mode) {
            self.selected_mode = mode;
            Ok(())
        } else {
            Err(format!("{} is not available", mode.label()))
        }
    }

    pub fn set_selected_profiles(&mut self, profile_ids: Vec<String>) {
        self.selected_profile_ids = profile_ids;
    }

    pub fn set_custom_domains(&mut self, domains: Vec<String>) {
        self.custom_domains = domains;
    }

    pub fn readiness(&self) -> RunReadiness {
        let issues = self.validation_issues();
        RunReadiness {
            can_run: issues.is_empty(),
            issues,
        }
    }

    pub fn build_plan(&self) -> Result<LinuxBenchmarkPlan, Vec<String>> {
        let mut issues = self.validation_issues();
        let resolvers = if self.selected_mode == BenchmarkMode::CurrentSystemResolver {
            Vec::new()
        } else {
            self.selected_resolvers(&mut issues)
        };

        if !issues.is_empty() {
            return Err(issues);
        }

        Ok(LinuxBenchmarkPlan {
            mode: self.selected_mode,
            package_platform: package_platform(self.capability.package_kind).to_string(),
            resolvers,
            domains: self.custom_domains.clone(),
            suite_id: self.selected_suite_id.clone(),
            suite_db: None,
            profile_db: None,
            attempts: self.attempts,
            record_family: self.record_family,
        })
    }
}

impl LinuxAppSession {
    fn validation_issues(&self) -> Vec<String> {
        let mut issues = Vec::new();
        if !available_benchmark_modes(&self.capability).contains(&self.selected_mode) {
            issues.push(format!("{} is not available", self.selected_mode.label()));
        }

        if self.attempts == 0 {
            issues.push("Attempts must be at least 1".to_string());
        }

        if self.selected_mode != BenchmarkMode::CurrentSystemResolver
            && self.selected_profile_ids.is_empty()
        {
            issues.push("Select at least one DNS profile".to_string());
        }

        for profile_id in &self.selected_profile_ids {
            if !self
                .profiles
                .iter()
                .any(|profile| profile.id == *profile_id)
            {
                issues.push(format!("Selected DNS profile '{profile_id}' is missing"));
            }
        }

        if let Some(suite_id) = &self.selected_suite_id {
            if !self.suites.iter().any(|suite| suite.id == suite_id) {
                issues.push(format!("Selected suite '{suite_id}' is missing"));
            }
        }

        if self.selected_suite_id.is_none() && self.custom_domains.is_empty() {
            issues.push("Select a suite or enter at least one custom domain".to_string());
        }

        for domain in &self.custom_domains {
            if !is_valid_domain(domain) {
                issues.push(format!("Invalid domain: {domain}"));
            }
        }

        issues
    }

    fn selected_resolvers(&self, issues: &mut Vec<String>) -> Vec<ResolverSelection> {
        let mut resolvers = Vec::new();
        for profile_id in &self.selected_profile_ids {
            let Some(profile) = self
                .profiles
                .iter()
                .find(|profile| profile.id == *profile_id)
            else {
                continue;
            };
            let servers = profile_servers_for_family(profile, self.resolver_address_family);
            if servers.is_empty() {
                issues.push(format!(
                    "{} has no {} DNS servers",
                    profile.name,
                    resolver_family_label(self.resolver_address_family)
                ));
                continue;
            }
            resolvers.push(ResolverSelection {
                id: profile.id.clone(),
                label: profile.name.clone(),
                resolver_spec: format!("{}={}", profile.id, servers.join(",")),
            });
        }
        resolvers
    }
}

fn resolver_family_label(family: ResolverAddressFamily) -> &'static str {
    match family {
        ResolverAddressFamily::Auto => "IPv4 or IPv6",
        ResolverAddressFamily::Ipv4Only => "IPv4",
        ResolverAddressFamily::Ipv6Only => "IPv6",
    }
}

fn package_platform(package_kind: LinuxPackageKind) -> &'static str {
    match package_kind {
        LinuxPackageKind::Flatpak => "linux-flatpak",
        LinuxPackageKind::Snap => "linux-snap",
        LinuxPackageKind::Deb | LinuxPackageKind::Rpm => "linux-native-power",
    }
}

fn is_valid_domain(domain: &str) -> bool {
    let domain = domain.trim();
    if domain.is_empty() || domain.len() > 253 || !domain.contains('.') {
        return false;
    }

    domain.split('.').all(|label| {
        !label.is_empty()
            && label.len() <= 63
            && !label.starts_with('-')
            && !label.ends_with('-')
            && label
                .chars()
                .all(|ch| ch.is_ascii_alphanumeric() || ch == '-')
    })
}
