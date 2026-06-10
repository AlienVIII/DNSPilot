use dnspilot_core::{
    apply_prompt_policy_for,
    benchmark_preflight_for,
    built_in_profiles, built_in_test_suites, capability_for, classify_resolution_outcome,
    recommend, recommendation_gate, ApplyCapability, ApplyPromptDisposition, BenchmarkMetrics,
    BenchmarkPreflightScope, Confidence, FilteringType, FlushCapability, FlushRequirement,
    MeasurementScope, NetworkEnvironment, Platform, RecommendationDecision, RecommendationHealth,
    RecommendationIssue, RecommendationMode, ResolutionOutcome,
};

fn metrics(
    profile_id: &str,
    median_dns_ms: f64,
    p95_dns_ms: f64,
    failure_rate: f64,
    timeout_rate: f64,
    connect_ms: f64,
    ipv4_health: f64,
    ipv6_health: f64,
) -> BenchmarkMetrics {
    BenchmarkMetrics {
        profile_id: profile_id.to_string(),
        median_dns_latency_ms: median_dns_ms,
        p95_dns_latency_ms: p95_dns_ms,
        failure_rate,
        timeout_rate,
        median_connect_latency_ms: connect_ms,
        ipv4_health,
        ipv6_health,
        priority_fit: 1.0,
    }
}

#[test]
fn built_in_catalog_contains_required_profiles_and_suites() {
    let profiles = built_in_profiles();
    let suites = built_in_test_suites();

    assert!(profiles.iter().any(|profile| profile.id == "cloudflare"));
    assert!(profiles.iter().any(|profile| profile.id == "google-public-dns"));
    assert!(profiles.iter().any(|profile| profile.id == "quad9"));
    assert!(profiles
        .iter()
        .any(|profile| profile.filtering_type == FilteringType::Family));

    assert!(suites.iter().any(|suite| suite.id == "general"));
    assert!(suites.iter().any(|suite| suite.id == "developer"));
    assert!(suites.iter().any(|suite| suite.id == "azure-microsoft"));
    assert!(suites.iter().any(|suite| suite.id == "google-firebase"));
    assert!(suites.iter().any(|suite| suite.id == "vietnam-daily"));

    let azure = suites
        .iter()
        .find(|suite| suite.id == "azure-microsoft")
        .expect("Azure suite should exist");
    assert!(azure.domains.contains(&"login.microsoftonline.com".to_string()));
    assert!(azure.domains.contains(&"blob.core.windows.net".to_string()));
}

#[test]
fn recommendation_keeps_current_dns_when_improvement_is_not_meaningful() {
    let current = metrics("current", 20.0, 45.0, 0.0, 0.0, 80.0, 1.0, 0.9);
    let candidate = metrics("cloudflare", 18.5, 44.0, 0.0, 0.0, 79.5, 1.0, 0.9);

    let recommendation = recommend(
        &[current.clone(), candidate],
        Some(&current),
        RecommendationMode::BestOverall,
    )
    .expect("recommendation should be produced");

    assert_eq!(recommendation.decision, RecommendationDecision::KeepCurrent);
    assert_eq!(recommendation.confidence, Confidence::Medium);
    assert!(recommendation
        .reasons
        .iter()
        .any(|reason| reason.contains("not meaningful")));
}

#[test]
fn recommendation_selects_better_candidate_with_confidence() {
    let current = metrics("current", 50.0, 140.0, 0.02, 0.01, 170.0, 1.0, 0.7);
    let candidate = metrics("quad9", 18.0, 42.0, 0.0, 0.0, 75.0, 1.0, 0.95);

    let recommendation =
        recommend(&[current.clone(), candidate], Some(&current), RecommendationMode::BestOverall)
            .expect("recommendation should be produced");

    assert_eq!(
        recommendation.decision,
        RecommendationDecision::ApplyProfile("quad9".to_string())
    );
    assert_eq!(recommendation.confidence, Confidence::High);
    assert!(recommendation.score > 0.0);
}

#[test]
fn recommendation_gate_blocks_all_failed_candidates() {
    let first = metrics(
        "first",
        f64::INFINITY,
        f64::INFINITY,
        1.0,
        1.0,
        f64::INFINITY,
        0.0,
        0.0,
    );
    let second = metrics(
        "second",
        f64::INFINITY,
        f64::INFINITY,
        1.0,
        1.0,
        f64::INFINITY,
        0.0,
        0.0,
    );

    let gate = recommendation_gate(&[first, second], MeasurementScope::DnsOnly);

    assert!(!gate.can_recommend);
    assert_eq!(gate.health, RecommendationHealth::Failed);
    assert_eq!(gate.primary_issue, RecommendationIssue::AllResolversFailed);
}

#[test]
fn recommendation_gate_blocks_missing_connection_path_for_path_scope() {
    let first = metrics("first", 5.0, 8.0, 0.0, 0.0, f64::INFINITY, 1.0, 0.0);
    let second = metrics("second", 8.0, 12.0, 0.0, 0.0, f64::INFINITY, 1.0, 0.0);

    let gate = recommendation_gate(&[first, second], MeasurementScope::DnsTcp);

    assert!(!gate.can_recommend);
    assert_eq!(gate.health, RecommendationHealth::Inconclusive);
    assert_eq!(gate.primary_issue, RecommendationIssue::NoConnectTargets);
}

#[test]
fn recommendation_gate_allows_degraded_partial_failure() {
    let failed = metrics("failed", 5.0, 8.0, 1.0, 1.0, f64::INFINITY, 1.0, 0.0);
    let healthy = metrics("healthy", 15.0, 25.0, 0.0, 0.0, 40.0, 1.0, 0.0);

    let gate = recommendation_gate(&[failed, healthy], MeasurementScope::DnsTcp);

    assert!(gate.can_recommend);
    assert_eq!(gate.health, RecommendationHealth::Degraded);
    assert_eq!(gate.primary_issue, RecommendationIssue::PartialFailure);
}

#[test]
fn filtered_dns_expected_block_is_not_a_failure_for_filtering_goal() {
    let outcome = classify_resolution_outcome(
        ResolutionOutcome::Blocked,
        FilteringType::Family,
        RecommendationMode::BestForFamilyFiltering,
    );

    assert!(!outcome.counts_as_failure);
    assert!(outcome.note.contains("expected"));
}

#[test]
fn store_safe_capabilities_match_platform_constraints() {
    assert_eq!(
        capability_for(Platform::MacOSStore).apply,
        ApplyCapability::AppleNetworkExtensionDnsSettings
    );
    assert_eq!(
        capability_for(Platform::IOS).apply,
        ApplyCapability::AppleNetworkExtensionDnsSettings
    );
    assert_eq!(
        capability_for(Platform::WindowsStore).apply,
        ApplyCapability::GuidedSettings
    );
    assert_eq!(
        capability_for(Platform::LinuxFlatpak).apply,
        ApplyCapability::GuidedSettings
    );
    assert_eq!(
        capability_for(Platform::LinuxNativePower).apply,
        ApplyCapability::LinuxNetworkManagerPolkit
    );
}

#[test]
fn flush_capabilities_match_platform_constraints() {
    assert_eq!(
        capability_for(Platform::MacOSStore).flush,
        FlushCapability::GuidedUserAction
    );
    assert_eq!(
        capability_for(Platform::IOS).flush,
        FlushCapability::Unsupported
    );
    assert_eq!(
        capability_for(Platform::WindowsStore).flush,
        FlushCapability::GuidedUserAction
    );
    assert_eq!(
        capability_for(Platform::LinuxNativePower).flush,
        FlushCapability::LinuxSystemResolverPolkit
    );
    assert_eq!(
        capability_for(Platform::MacOSPower).flush,
        FlushCapability::DesktopAdminService
    );
}

#[test]
fn benchmark_preflight_distinguishes_direct_resolver_from_system_validation() {
    let direct = benchmark_preflight_for(
        Platform::MacOSStore,
        BenchmarkPreflightScope::DirectResolverBenchmark,
    );
    assert_eq!(direct.flush_requirement, FlushRequirement::NotNeeded);
    assert_eq!(direct.flush_capability, FlushCapability::GuidedUserAction);
    assert!(direct
        .notes
        .iter()
        .any(|note| note.contains("bypasses the OS DNS cache")));

    let system_validation = benchmark_preflight_for(
        Platform::MacOSStore,
        BenchmarkPreflightScope::SystemDnsValidation,
    );
    assert_eq!(
        system_validation.flush_requirement,
        FlushRequirement::RecommendedBeforeTest
    );
    assert_eq!(
        system_validation.flush_capability,
        FlushCapability::GuidedUserAction
    );

    let ios_validation =
        benchmark_preflight_for(Platform::IOS, BenchmarkPreflightScope::SystemDnsValidation);
    assert_eq!(
        ios_validation.flush_requirement,
        FlushRequirement::RecommendedButUnsupported
    );
    assert_eq!(ios_validation.flush_capability, FlushCapability::Unsupported);
}

#[test]
fn apply_prompt_policy_protects_managed_or_intercepted_networks() {
    let protected = NetworkEnvironment {
        vpn_active: true,
        mdm_profile_active: true,
        corporate_dns_detected: true,
        captive_portal_detected: false,
    };

    let policy = apply_prompt_policy_for(Platform::MacOSStore, &protected);

    assert!(!policy.can_prompt_apply);
    assert_eq!(policy.disposition, ApplyPromptDisposition::ProtectCurrentDns);
    assert_eq!(
        policy.apply_capability,
        ApplyCapability::AppleNetworkExtensionDnsSettings
    );
    assert!(policy.notes.iter().any(|note| note.contains("VPN")));
    assert!(policy.notes.iter().any(|note| note.contains("MDM")));
    assert!(policy.notes.iter().any(|note| note.contains("corporate DNS")));

    let guided = apply_prompt_policy_for(Platform::WindowsStore, &NetworkEnvironment::default());
    assert!(guided.can_prompt_apply);
    assert_eq!(guided.disposition, ApplyPromptDisposition::GuideOnly);
    assert_eq!(guided.apply_capability, ApplyCapability::GuidedSettings);
}

#[test]
fn platform_json_names_are_product_facing() {
    let serialized =
        serde_json::to_string(&Platform::MacOSStore).expect("platform should serialize");

    assert_eq!(serialized, "\"macos-store\"");
}
