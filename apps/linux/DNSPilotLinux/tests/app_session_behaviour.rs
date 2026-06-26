use dnspilot_linux_shell::app::LinuxAppSession;
use dnspilot_linux_shell::capabilities::{
    capability_view_model, BenchmarkMode, LinuxEnvironmentProbe, LinuxPackageKind,
};
use dnspilot_linux_shell::profiles::PlainDnsProfile;
use dnspilot_linux_shell::settings::{DnsRecordFamily, ResolverAddressFamily};
use dnspilot_linux_shell::suites::default_suite_catalog;

fn probe(package_kind: LinuxPackageKind) -> LinuxEnvironmentProbe {
    LinuxEnvironmentProbe {
        package_kind,
        network_manager_available: false,
        systemd_resolved_available: false,
        polkit_available: false,
        system_resolver_probe_available: false,
    }
}

fn profile(id: &str, name: &str, ipv4: Vec<&str>, ipv6: Vec<&str>) -> PlainDnsProfile {
    PlainDnsProfile {
        id: id.to_string(),
        name: name.to_string(),
        ipv4_servers: ipv4.into_iter().map(str::to_string).collect(),
        ipv6_servers: ipv6.into_iter().map(str::to_string).collect(),
    }
}

#[test]
fn new_session_defaults_to_dns_tcp_with_first_profiles_and_default_suite() {
    let capability = capability_view_model(probe(LinuxPackageKind::Flatpak));
    let profiles = vec![
        profile(
            "cloudflare",
            "Cloudflare",
            vec!["1.1.1.1"],
            vec!["2606:4700:4700::1111"],
        ),
        profile("quad9", "Quad9", vec!["9.9.9.9"], vec![]),
    ];

    let session = LinuxAppSession::new(capability, default_suite_catalog(true), profiles);

    assert_eq!(session.selected_mode, BenchmarkMode::DnsAndTcp);
    assert_eq!(session.selected_profile_ids, vec!["cloudflare", "quad9"]);
    assert_eq!(session.selected_suite_id.as_deref(), Some("general"));
    assert_eq!(session.resolver_address_family, ResolverAddressFamily::Auto);
    assert_eq!(session.record_family, DnsRecordFamily::AAndAaaa);
    assert_eq!(session.attempts, 3);
    assert!(session.readiness().can_run);
}

#[test]
fn session_rejects_unavailable_system_resolver_mode() {
    let capability = capability_view_model(probe(LinuxPackageKind::Flatpak));
    let mut session = LinuxAppSession::new(
        capability,
        default_suite_catalog(false),
        vec![profile("cloudflare", "Cloudflare", vec!["1.1.1.1"], vec![])],
    );

    let error = session
        .select_mode(BenchmarkMode::CurrentSystemResolver)
        .unwrap_err();

    assert!(error.contains("not available"));
    assert_eq!(session.selected_mode, BenchmarkMode::DnsAndTcp);
}

#[test]
fn readiness_requires_profile_selection_for_direct_benchmarks() {
    let capability = capability_view_model(probe(LinuxPackageKind::Flatpak));
    let mut session = LinuxAppSession::new(
        capability,
        default_suite_catalog(false),
        vec![profile("cloudflare", "Cloudflare", vec!["1.1.1.1"], vec![])],
    );

    session.set_selected_profiles(vec![]);

    let readiness = session.readiness();
    assert!(!readiness.can_run);
    assert!(readiness
        .issues
        .iter()
        .any(|issue| issue.contains("DNS profile")));
}

#[test]
fn readiness_accepts_system_resolver_without_selected_profiles_when_capability_allows_it() {
    let mut env = probe(LinuxPackageKind::Deb);
    env.system_resolver_probe_available = true;
    let capability = capability_view_model(env);
    let mut session = LinuxAppSession::new(capability, default_suite_catalog(false), vec![]);

    session
        .select_mode(BenchmarkMode::CurrentSystemResolver)
        .unwrap();
    session.set_selected_profiles(vec![]);

    assert!(session.readiness().can_run);
}

#[test]
fn readiness_rejects_invalid_custom_domains_before_core_cli_run() {
    let capability = capability_view_model(probe(LinuxPackageKind::Flatpak));
    let mut session = LinuxAppSession::new(
        capability,
        default_suite_catalog(false),
        vec![profile("cloudflare", "Cloudflare", vec!["1.1.1.1"], vec![])],
    );
    session.selected_suite_id = None;
    session.set_custom_domains(vec!["valid.example".to_string(), "bad domain".to_string()]);

    let readiness = session.readiness();

    assert!(!readiness.can_run);
    assert!(readiness
        .issues
        .iter()
        .any(|issue| issue.contains("bad domain")));
}

#[test]
fn build_plan_maps_package_profile_family_domains_and_suite_to_runner_plan() {
    let capability = capability_view_model(probe(LinuxPackageKind::Snap));
    let mut session = LinuxAppSession::new(
        capability,
        default_suite_catalog(true),
        vec![
            profile(
                "cloudflare",
                "Cloudflare",
                vec!["1.1.1.1"],
                vec!["2606:4700:4700::1111"],
            ),
            profile("quad9", "Quad9", vec!["9.9.9.9"], vec!["2620:fe::fe"]),
        ],
    );
    session.set_selected_profiles(vec!["quad9".to_string()]);
    session.resolver_address_family = ResolverAddressFamily::Ipv6Only;
    session.record_family = DnsRecordFamily::AaaaOnly;
    session.selected_suite_id = Some("vietnam-daily".to_string());
    session.set_custom_domains(vec!["login.microsoftonline.com".to_string()]);
    session.attempts = 4;

    let plan = session.build_plan().unwrap();

    assert_eq!(plan.mode, BenchmarkMode::DnsAndTcp);
    assert_eq!(plan.package_platform, "linux-snap");
    assert_eq!(plan.resolvers.len(), 1);
    assert_eq!(plan.resolvers[0].id, "quad9");
    assert_eq!(plan.resolvers[0].resolver_spec, "quad9=2620:fe::fe");
    assert_eq!(plan.record_family, DnsRecordFamily::AaaaOnly);
    assert_eq!(plan.suite_id.as_deref(), Some("vietnam-daily"));
    assert_eq!(plan.domains, vec!["login.microsoftonline.com"]);
    assert_eq!(plan.attempts, 4);
}

#[test]
fn build_plan_reports_selected_profile_missing_requested_address_family() {
    let capability = capability_view_model(probe(LinuxPackageKind::Flatpak));
    let mut session = LinuxAppSession::new(
        capability,
        default_suite_catalog(false),
        vec![profile("quad9", "Quad9", vec!["9.9.9.9"], vec![])],
    );
    session.resolver_address_family = ResolverAddressFamily::Ipv6Only;

    let issues = session.build_plan().unwrap_err();

    assert!(issues
        .iter()
        .any(|issue| issue.contains("Quad9") && issue.contains("IPv6")));
}
