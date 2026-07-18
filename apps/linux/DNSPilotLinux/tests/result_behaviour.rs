use dnspilot_linux_shell::capabilities::{
    capability_view_model, LinuxEnvironmentProbe, LinuxPackageKind,
};
use dnspilot_linux_shell::result::{decode_benchmark_decision, PrimaryResultAction};

#[test]
fn result_separates_recommendation_from_fastest_observed_and_chooses_guidance() {
    let decision = decode_benchmark_decision(
        r#"{
          "summary":{"can_recommend":true,"recommended_profile_id":"reliable","health":"healthy","safety_notes":["Reliable result."]},
          "runs":[
            {"profile_id":"fast","metrics":{"median_dns_latency_ms":8.0,"median_connect_latency_ms":30.0,"failure_rate":0.5}},
            {"profile_id":"reliable","metrics":{"median_dns_latency_ms":12.0,"median_connect_latency_ms":20.0,"failure_rate":0.0}}
          ],
          "warning":"Estimate only."
        }"#,
        &flatpak(),
    )
    .unwrap();

    assert_eq!(decision.recommended_profile_id.as_deref(), Some("reliable"));
    assert_eq!(
        decision.fastest_observed_profile_id.as_deref(),
        Some("fast")
    );
    assert_eq!(decision.primary_action, PrimaryResultAction::ApplyGuidance);
    assert_eq!(decision.gate_reasons, vec!["Reliable result."]);
}

#[test]
fn unrecommendable_result_prefers_retest_only_when_supported() {
    let mut environment = LinuxEnvironmentProbe {
        package_kind: LinuxPackageKind::Deb,
        network_manager_available: false,
        systemd_resolved_available: false,
        polkit_available: false,
        system_resolver_probe_available: true,
    };
    let decision = decode_benchmark_decision(
        r#"{"summary":{"can_recommend":false,"recommended_profile_id":null,"health":"inconclusive","safety_notes":["Keep current."]},"runs":[],"warning":"Estimate only."}"#,
        &capability_view_model(environment.clone()),
    )
    .unwrap();
    assert_eq!(
        decision.primary_action,
        PrimaryResultAction::RetestSystemDns
    );

    environment.system_resolver_probe_available = false;
    let decision = decode_benchmark_decision(
        r#"{"summary":{"can_recommend":false,"recommended_profile_id":null,"health":"inconclusive"},"warning":"Estimate only."}"#,
        &capability_view_model(environment),
    )
    .unwrap();
    assert_eq!(decision.primary_action, PrimaryResultAction::None);
}

fn flatpak() -> dnspilot_linux_shell::capabilities::LinuxCapabilityViewModel {
    capability_view_model(LinuxEnvironmentProbe {
        package_kind: LinuxPackageKind::Flatpak,
        network_manager_available: false,
        systemd_resolved_available: false,
        polkit_available: false,
        system_resolver_probe_available: false,
    })
}
