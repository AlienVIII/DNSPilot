use dnspilot_core::{
    apply_plan_for, apply_prompt_policy_for, apply_prompt_policy_payload_for,
    benchmark_preflight_for, benchmark_preflight_payload_for, built_in_profiles,
    built_in_test_suites, capability_for, capability_matrix_payload, catalog_payload,
    classify_resolution_outcome, recommend, recommendation_gate, ApplyCapability,
    ApplyPlanDisposition, ApplyPromptDisposition, BenchmarkMetrics, BenchmarkPreflightScope,
    CapabilityNote, Confidence, DnsProtocol, FilteringType, FlushCapability, FlushRequirement,
    MeasurementScope, NetworkEnvironment, Platform, RecommendationDecision, RecommendationGate,
    RecommendationHealth, RecommendationIssue, RecommendationMode, RecommendationNote,
    ResolutionOutcome,
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
    assert!(profiles
        .iter()
        .any(|profile| profile.id == "google-public-dns"));
    assert!(profiles.iter().any(|profile| profile.id == "quad9"));
    assert!(profiles
        .iter()
        .any(|profile| profile.id == "fpt-telecom-dns"));
    assert!(profiles.iter().any(|profile| profile.id == "vnpt-dns"));
    assert!(profiles.iter().any(|profile| profile.id == "viettel-dns"));
    assert!(profiles
        .iter()
        .any(|profile| profile.filtering_type == FilteringType::Family));

    assert!(suites.iter().any(|suite| suite.id == "general"));
    assert!(suites.iter().any(|suite| suite.id == "developer"));
    assert!(suites.iter().any(|suite| suite.id == "azure-microsoft"));
    assert!(suites
        .iter()
        .any(|suite| suite.id == "youtube-google-video"));
    assert!(suites.iter().any(|suite| suite.id == "github-developer"));
    assert!(suites.iter().any(|suite| suite.id == "chatgpt-openai"));
    assert!(suites.iter().any(|suite| suite.id == "google-firebase"));
    assert!(suites.iter().any(|suite| suite.id == "vietnam-daily"));
    assert!(suites.iter().any(|suite| suite.id == "gaming-steam-valve"));
    assert!(suites.iter().any(|suite| suite.id == "gaming-dota2-sea"));
    assert!(suites.iter().any(|suite| suite.id == "gaming-cs2"));
    assert!(suites.iter().any(|suite| suite.id == "gaming-riot-lol"));

    let azure = suites
        .iter()
        .find(|suite| suite.id == "azure-microsoft")
        .expect("Azure suite should exist");
    assert!(azure
        .domains
        .contains(&"login.microsoftonline.com".to_string()));
    assert!(azure.domains.contains(&"blob.core.windows.net".to_string()));

    let youtube = suites
        .iter()
        .find(|suite| suite.id == "youtube-google-video")
        .expect("YouTube suite should exist");
    assert!(youtube.domains.contains(&"youtube.com".to_string()));
    assert!(youtube.domains.contains(&"googlevideo.com".to_string()));

    let github = suites
        .iter()
        .find(|suite| suite.id == "github-developer")
        .expect("GitHub suite should exist");
    assert!(github.domains.contains(&"github.com".to_string()));
    assert!(github
        .domains
        .contains(&"raw.githubusercontent.com".to_string()));

    let chatgpt = suites
        .iter()
        .find(|suite| suite.id == "chatgpt-openai")
        .expect("ChatGPT suite should exist");
    assert!(chatgpt.domains.contains(&"chatgpt.com".to_string()));
    assert!(chatgpt.domains.contains(&"api.openai.com".to_string()));
    assert!(chatgpt.domains.contains(&"oaistatic.com".to_string()));

    let dota = suites
        .iter()
        .find(|suite| suite.id == "gaming-dota2-sea")
        .expect("Dota 2 SEA suite should exist");
    assert!(dota.tags.contains(&"gaming".to_string()));
    assert!(dota.tags.contains(&"sea".to_string()));
    assert!(dota.domains.contains(&"dota2.com".to_string()));
    assert!(dota.domains.contains(&"steamcommunity.com".to_string()));

    let riot = suites
        .iter()
        .find(|suite| suite.id == "gaming-riot-lol")
        .expect("Riot LoL suite should exist");
    assert!(riot.domains.contains(&"leagueoflegends.com".to_string()));
    assert!(riot.domains.contains(&"riotgames.com".to_string()));
}

#[test]
fn catalog_payload_matches_builtin_catalog_contract() {
    let payload = catalog_payload();
    let json = serde_json::to_value(&payload).expect("catalog payload should serialize");

    assert_eq!(payload.schema_version, 1);
    assert_eq!(payload.profiles, built_in_profiles());
    assert_eq!(payload.test_suites, built_in_test_suites());
    assert_eq!(json["schema_version"], 1);
    assert!(json.get("profiles").is_some());
    assert!(json.get("testSuites").is_some());
    assert!(json.get("test_suites").is_none());
}

#[test]
fn capability_matrix_payload_matches_platform_capability_contract() {
    let payload = capability_matrix_payload();
    let expected = dnspilot_core::all_platforms()
        .iter()
        .copied()
        .map(capability_for)
        .collect::<Vec<_>>();
    let json = serde_json::to_value(&payload).expect("capability payload should serialize");

    assert_eq!(payload.schema_version, 1);
    assert_eq!(payload.capabilities, expected);
    assert_eq!(
        payload.capabilities.len(),
        dnspilot_core::all_platforms().len()
    );
    assert_eq!(json["schema_version"], 1);
    assert!(json.get("capabilities").is_some());
    let macos = payload
        .capabilities
        .iter()
        .find(|capability| capability.platform == Platform::MacOSStore)
        .expect("macOS Store capability");
    assert_eq!(
        macos.note_ids,
        vec![
            CapabilityNote::AppleDnsSettingsUserEnablement,
            CapabilityNote::StoreGuidedCacheFlush,
        ]
    );
    assert_eq!(
        json["capabilities"].as_array().expect("capabilities array")[0]["note_ids"],
        serde_json::json!([
            "apple-dns-settings-user-enablement",
            "store-guided-cache-flush"
        ])
    );
}

#[test]
fn dns_profile_validation_rejects_mismatched_or_duplicate_server_families() {
    let mut mismatched = built_in_profiles()
        .into_iter()
        .find(|profile| profile.id == "cloudflare")
        .expect("cloudflare profile");
    mismatched.id = "bad-v4".into();
    mismatched.ipv4_servers = vec!["::1".into()];
    mismatched.ipv6_servers = vec![];

    let mismatched_error = mismatched
        .validate()
        .expect_err("IPv6 address in IPv4 list should be rejected");
    assert!(mismatched_error.to_string().contains("IPv4 DNS server"));

    let mut duplicate = built_in_profiles()
        .into_iter()
        .find(|profile| profile.id == "cloudflare")
        .expect("cloudflare profile");
    duplicate.id = "duplicate-v4".into();
    duplicate.ipv4_servers = vec!["1.1.1.1".into(), "1.1.1.1".into()];
    duplicate.ipv6_servers = vec![];

    let duplicate_error = duplicate
        .validate()
        .expect_err("duplicate DNS server should be rejected");
    assert!(duplicate_error.to_string().contains("duplicate DNS server"));
}

#[test]
fn dns_profile_validation_rejects_invalid_encrypted_endpoints() {
    let mut doh = built_in_profiles()
        .into_iter()
        .find(|profile| profile.id == "cloudflare")
        .expect("cloudflare profile");
    doh.id = "bad-doh".into();
    doh.protocol = DnsProtocol::Doh;
    doh.doh_url = Some("http://dns.example/dns-query".into());

    let doh_error = doh
        .validate()
        .expect_err("insecure DoH URL should be rejected");
    assert!(doh_error.to_string().contains("DoH URL must use https"));

    let mut dot = built_in_profiles()
        .into_iter()
        .find(|profile| profile.id == "cloudflare")
        .expect("cloudflare profile");
    dot.id = "bad-dot".into();
    dot.protocol = DnsProtocol::Dot;
    dot.dot_hostname = Some("bad host".into());

    let dot_error = dot
        .validate()
        .expect_err("invalid DoT hostname should be rejected");
    assert!(dot_error.to_string().contains("invalid DoT hostname"));
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

    let recommendation = recommend(
        &[current.clone(), candidate],
        Some(&current),
        RecommendationMode::BestOverall,
    )
    .expect("recommendation should be produced");

    assert_eq!(
        recommendation.decision,
        RecommendationDecision::ApplyProfile("quad9".to_string())
    );
    assert_eq!(recommendation.confidence, Confidence::High);
    assert!(recommendation.score > 0.0);
}

#[test]
fn recommendation_reason_uses_dns_lookup_text_for_raw_dns_mode() {
    let candidate = metrics("cloudflare", 18.0, 42.0, 0.0, 0.0, 75.0, 1.0, 0.95);

    let recommendation = recommend(&[candidate], None, RecommendationMode::FastestRawDns)
        .expect("recommendation should be produced");

    assert!(recommendation
        .reasons
        .contains(&"Best DNS lookup estimate for FastestRawDns mode.".to_string()));
    assert!(!recommendation
        .reasons
        .iter()
        .any(|reason| reason.contains("connection-path")));
}

#[test]
fn recommendation_caveat_uses_tcp_text_for_connection_path_mode() {
    let candidate = metrics("cloudflare", 18.0, 42.0, 0.0, 0.0, 75.0, 1.0, 0.95);

    let recommendation = recommend(&[candidate], None, RecommendationMode::BestOverall)
        .expect("recommendation should be produced");

    assert!(recommendation.caveats.contains(
        &"This estimates DNS and TCP connection behavior, not full HTTPS, browser, or app speed."
            .to_string()
    ));
    assert!(!recommendation
        .caveats
        .iter()
        .any(|caveat| caveat.contains("DNS and HTTPS connection behavior")));
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
    assert_eq!(
        gate.note_ids,
        vec![RecommendationNote::EveryCandidateFailed]
    );
}

#[test]
fn recommendation_gate_blocks_missing_connection_path_for_path_scope() {
    let first = metrics("first", 5.0, 8.0, 0.0, 0.0, f64::INFINITY, 1.0, 0.0);
    let second = metrics("second", 8.0, 12.0, 0.0, 0.0, f64::INFINITY, 1.0, 0.0);

    let gate = recommendation_gate(&[first, second], MeasurementScope::DnsTcp);

    assert!(!gate.can_recommend);
    assert_eq!(gate.health, RecommendationHealth::Inconclusive);
    assert_eq!(gate.primary_issue, RecommendationIssue::NoConnectTargets);
    assert_eq!(
        gate.note_ids,
        vec![RecommendationNote::NoConnectionPathTarget]
    );
}

#[test]
fn recommendation_gate_allows_degraded_partial_failure() {
    let failed = metrics("failed", 5.0, 8.0, 1.0, 1.0, f64::INFINITY, 1.0, 0.0);
    let healthy = metrics("healthy", 15.0, 25.0, 0.0, 0.0, 40.0, 1.0, 0.0);

    let gate = recommendation_gate(&[failed, healthy], MeasurementScope::DnsTcp);

    assert!(gate.can_recommend);
    assert_eq!(gate.health, RecommendationHealth::Degraded);
    assert_eq!(gate.primary_issue, RecommendationIssue::PartialFailure);
    assert_eq!(
        gate.note_ids,
        vec![RecommendationNote::PartialFailureOrTimeout]
    );
}

#[test]
fn recommendation_gate_blocks_when_every_candidate_has_low_reliability() {
    let first = metrics("first", 55.0, 70.0, 0.5, 0.5, 35.0, 1.0, 0.0);
    let second = metrics("second", 31.0, 42.0, 0.5, 0.5, 40.0, 1.0, 0.0);

    let gate = recommendation_gate(&[first, second], MeasurementScope::DnsTcp);

    assert!(!gate.can_recommend);
    assert_eq!(gate.health, RecommendationHealth::Degraded);
    assert_eq!(
        gate.primary_issue,
        RecommendationIssue::AllResolversLowReliability
    );
    assert_eq!(
        gate.note_ids,
        vec![RecommendationNote::AllCandidatesLowReliability]
    );
    assert!(gate
        .notes
        .iter()
        .any(|note| note.contains("Keep current DNS")));
}

#[test]
fn recommendation_gate_accepts_history_written_before_note_ids() {
    let gate: RecommendationGate = serde_json::from_value(serde_json::json!({
        "can_recommend": false,
        "health": "failed",
        "primary_issue": "all-resolvers-failed",
        "notes": ["Every candidate failed the measured scope."]
    }))
    .expect("legacy gate should remain readable");

    assert!(gate.note_ids.is_empty());
    assert_eq!(gate.notes.len(), 1);
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
    assert_eq!(
        ios_validation.flush_capability,
        FlushCapability::Unsupported
    );
}

#[test]
fn benchmark_preflight_payload_versions_shell_contract() {
    let payload = benchmark_preflight_payload_for(
        Platform::MacOSStore,
        BenchmarkPreflightScope::SystemDnsValidation,
    );
    let json = serde_json::to_value(&payload).expect("preflight payload should serialize");

    assert_eq!(payload.schema_version, 1);
    assert_eq!(payload.preflight.platform, Platform::MacOSStore);
    assert_eq!(
        payload.preflight.flush_requirement,
        FlushRequirement::RecommendedBeforeTest
    );
    assert_eq!(json["schema_version"], 1);
    assert_eq!(json["platform"], "macos-store");
    assert_eq!(json["scope"], "system-dns-validation");
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
    assert_eq!(
        policy.disposition,
        ApplyPromptDisposition::ProtectCurrentDns
    );
    assert_eq!(
        policy.apply_capability,
        ApplyCapability::AppleNetworkExtensionDnsSettings
    );
    assert!(policy.notes.iter().any(|note| note.contains("VPN")));
    assert!(policy.notes.iter().any(|note| note.contains("MDM")));
    assert!(policy
        .notes
        .iter()
        .any(|note| note.contains("corporate DNS")));

    let guided = apply_prompt_policy_for(Platform::WindowsStore, &NetworkEnvironment::default());
    assert!(guided.can_prompt_apply);
    assert_eq!(guided.disposition, ApplyPromptDisposition::GuideOnly);
    assert_eq!(guided.apply_capability, ApplyCapability::GuidedSettings);
}

#[test]
fn apply_prompt_policy_payload_versions_shell_contract() {
    let environment = NetworkEnvironment {
        vpn_active: true,
        ..NetworkEnvironment::default()
    };
    let payload = apply_prompt_policy_payload_for(Platform::MacOSStore, &environment);
    let json = serde_json::to_value(&payload).expect("apply policy payload should serialize");

    assert_eq!(payload.schema_version, 1);
    assert_eq!(
        payload.policy.disposition,
        ApplyPromptDisposition::ProtectCurrentDns
    );
    assert_eq!(json["schema_version"], 1);
    assert_eq!(json["platform"], "macos-store");
    assert_eq!(json["disposition"], "protect-current-dns");
}

#[test]
fn apply_plan_guides_plain_dns_for_store_safe_platforms() {
    let profiles = built_in_profiles();
    let recommendation = recommend(
        &[metrics("cloudflare", 12.0, 18.0, 0.0, 0.0, 35.0, 1.0, 1.0)],
        None,
        RecommendationMode::BestOverall,
    )
    .expect("recommendation should be produced");
    let gate = healthy_gate();

    let plan = apply_plan_for(
        Platform::MacOSStore,
        &NetworkEnvironment::default(),
        &gate,
        Some(&recommendation),
        None,
        &profiles,
    );

    assert_eq!(plan.disposition, ApplyPlanDisposition::GuideOnly);
    assert_eq!(
        plan.apply_capability,
        ApplyCapability::AppleNetworkExtensionDnsSettings
    );
    assert!(!plan.can_apply);
    assert_eq!(plan.profile_id.as_deref(), Some("cloudflare"));
    assert!(plan.dns_servers.contains(&"1.1.1.1".to_string()));
    assert!(plan
        .notes
        .iter()
        .any(|note| note.contains("guide plain DNS changes")));
}

#[test]
fn apply_plan_allows_power_plain_dns_with_user_approval() {
    let profiles = built_in_profiles();
    let recommendation = recommend(
        &[metrics("quad9", 12.0, 18.0, 0.0, 0.0, 35.0, 1.0, 1.0)],
        None,
        RecommendationMode::BestOverall,
    )
    .expect("recommendation should be produced");
    let gate = healthy_gate();

    let plan = apply_plan_for(
        Platform::LinuxNativePower,
        &NetworkEnvironment::default(),
        &gate,
        Some(&recommendation),
        None,
        &profiles,
    );

    assert_eq!(
        plan.disposition,
        ApplyPlanDisposition::ApplyWithUserApproval
    );
    assert_eq!(
        plan.apply_capability,
        ApplyCapability::LinuxNetworkManagerPolkit
    );
    assert!(plan.can_apply);
    assert_eq!(plan.profile_name.as_deref(), Some("Quad9"));
}

#[test]
fn apply_plan_protects_managed_networks_before_profile_apply() {
    let profiles = built_in_profiles();
    let recommendation = recommend(
        &[metrics("cloudflare", 12.0, 18.0, 0.0, 0.0, 35.0, 1.0, 1.0)],
        None,
        RecommendationMode::BestOverall,
    )
    .expect("recommendation should be produced");
    let gate = healthy_gate();
    let environment = NetworkEnvironment {
        vpn_active: true,
        ..NetworkEnvironment::default()
    };

    let plan = apply_plan_for(
        Platform::MacOSPower,
        &environment,
        &gate,
        Some(&recommendation),
        None,
        &profiles,
    );

    assert_eq!(plan.disposition, ApplyPlanDisposition::ProtectCurrentDns);
    assert!(!plan.can_apply);
    assert!(plan.notes.iter().any(|note| note.contains("VPN")));
}

#[test]
fn apply_plan_blocks_unhealthy_or_low_confidence_recommendations() {
    let profiles = built_in_profiles();
    let recommendation = recommend(
        &[metrics("cloudflare", 12.0, 18.0, 0.0, 0.0, 35.0, 1.0, 1.0)],
        None,
        RecommendationMode::BestOverall,
    )
    .expect("recommendation should be produced");
    let degraded_gate = RecommendationGate {
        can_recommend: true,
        health: RecommendationHealth::Degraded,
        primary_issue: RecommendationIssue::PartialFailure,
        note_ids: vec![RecommendationNote::PartialFailureOrTimeout],
        notes: vec!["At least one candidate had partial failure or timeout.".into()],
    };

    let plan = apply_plan_for(
        Platform::MacOSPower,
        &NetworkEnvironment::default(),
        &degraded_gate,
        Some(&recommendation),
        None,
        &profiles,
    );

    assert_eq!(plan.disposition, ApplyPlanDisposition::NotRecommended);
    assert!(!plan.can_apply);
    assert!(plan
        .notes
        .iter()
        .any(|note| note.contains("not healthy enough")));
}

fn healthy_gate() -> RecommendationGate {
    RecommendationGate {
        can_recommend: true,
        health: RecommendationHealth::Healthy,
        primary_issue: RecommendationIssue::None,
        note_ids: Vec::new(),
        notes: Vec::new(),
    }
}

#[test]
fn platform_json_names_are_product_facing() {
    let serialized =
        serde_json::to_string(&Platform::MacOSStore).expect("platform should serialize");

    assert_eq!(serialized, "\"macos-store\"");
}
