use dnspilot_linux_shell::capabilities::{
    capability_view_model, LinuxEnvironmentProbe, LinuxPackageKind,
};
use dnspilot_linux_shell::i18n::Language;
use dnspilot_linux_shell::profiles::{
    CustomProfileStore, PlainDnsProfile, PlainDnsProfileDraft, ProfileValidationIssue,
};
use dnspilot_linux_shell::settings::{
    build_guided_settings_plan, dns_record_family_controls, native_power_path_plan,
    profile_servers_for_family, render_guided_settings_plan, resolver_address_family_controls,
    settings_actions, DnsRecordFamily, GuidedSettingsError, ResolverAddressFamily,
    SettingsActionKind,
};
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

fn draft(id: &str, name: &str, ipv4: Vec<&str>, ipv6: Vec<&str>) -> PlainDnsProfileDraft {
    PlainDnsProfileDraft {
        id: id.to_string(),
        name: name.to_string(),
        ipv4_servers: ipv4.into_iter().map(str::to_string).collect(),
        ipv6_servers: ipv6.into_iter().map(str::to_string).collect(),
    }
}

#[test]
fn custom_plain_dns_profiles_can_add_edit_delete_and_list() {
    let mut store = CustomProfileStore::new();

    store
        .add(draft(
            "home-fast",
            "Home Fast",
            vec!["1.1.1.1", "8.8.8.8"],
            vec!["2606:4700:4700::1111"],
        ))
        .unwrap();
    store
        .edit(draft(
            "home-fast",
            "Home Fast Updated",
            vec!["9.9.9.9"],
            vec!["2620:fe::fe"],
        ))
        .unwrap();

    assert_eq!(store.list().len(), 1);
    assert_eq!(store.list()[0].name, "Home Fast Updated");
    assert_eq!(store.list()[0].ipv4_servers, vec!["9.9.9.9"]);
    assert!(store.delete("home-fast"));
    assert!(store.list().is_empty());
    assert!(!store.delete("missing"));
}

#[test]
fn custom_profile_validation_rejects_family_mismatches_duplicates_and_empty_servers() {
    let mut store = CustomProfileStore::new();

    assert_eq!(
        store.add(draft(
            "bad-v4",
            "Bad v4",
            vec!["2606:4700:4700::1111"],
            vec![]
        )),
        Err(ProfileValidationIssue::InvalidIpv4(
            "2606:4700:4700::1111".to_string()
        ))
    );
    assert_eq!(
        store.add(draft("bad-v6", "Bad v6", vec![], vec!["1.1.1.1"])),
        Err(ProfileValidationIssue::InvalidIpv6("1.1.1.1".to_string()))
    );
    assert_eq!(
        store.add(draft("empty", "Empty", vec![], vec![])),
        Err(ProfileValidationIssue::NoServers)
    );
    assert_eq!(
        store.add(draft(
            "dupe-server",
            "Dupe",
            vec!["1.1.1.1", "1.1.1.1"],
            vec![]
        )),
        Err(ProfileValidationIssue::DuplicateServer(
            "1.1.1.1".to_string()
        ))
    );

    store
        .add(draft("quad9", "Quad9", vec!["9.9.9.9"], vec![]))
        .unwrap();
    assert_eq!(
        store.add(draft(
            "quad9",
            "Quad9 copy",
            vec!["149.112.112.112"],
            vec![]
        )),
        Err(ProfileValidationIssue::DuplicateProfileId(
            "quad9".to_string()
        ))
    );
    assert_eq!(
        store.edit(draft("missing", "Missing", vec!["1.1.1.1"], vec![])),
        Err(ProfileValidationIssue::MissingProfile(
            "missing".to_string()
        ))
    );
}

#[test]
fn ipv4_ipv6_and_record_family_controls_have_hover_help_text() {
    let resolver_controls = resolver_address_family_controls();
    assert_eq!(
        resolver_controls
            .iter()
            .map(|control| control.value)
            .collect::<Vec<_>>(),
        vec![
            ResolverAddressFamily::Auto,
            ResolverAddressFamily::Ipv4Only,
            ResolverAddressFamily::Ipv6Only
        ]
    );
    assert!(resolver_controls
        .iter()
        .any(|control| control.label == "IPv4" && control.help_text.contains("IPv4 DNS servers")));
    assert!(resolver_controls
        .iter()
        .any(|control| control.label == "IPv6" && control.help_text.contains("IPv6 DNS servers")));

    let record_controls = dns_record_family_controls();
    assert_eq!(
        record_controls
            .iter()
            .map(|control| control.value)
            .collect::<Vec<_>>(),
        vec![
            DnsRecordFamily::AAndAaaa,
            DnsRecordFamily::AOnly,
            DnsRecordFamily::AaaaOnly
        ]
    );
    assert!(record_controls
        .iter()
        .any(|control| control.label == "A only" && control.help_text.contains("IPv6")));
}

#[test]
fn store_safe_settings_are_guided_only_and_native_power_is_unavailable() {
    let flatpak = capability_view_model(probe(LinuxPackageKind::Flatpak));
    let flatpak_actions = settings_actions(&flatpak);
    assert_eq!(flatpak_actions.len(), 1);
    assert_eq!(flatpak_actions[0].kind, SettingsActionKind::GuidedSettings);
    assert!(flatpak_actions[0].help_text.contains("does not change DNS"));

    let mut deb = probe(LinuxPackageKind::Deb);
    deb.network_manager_available = true;
    deb.polkit_available = true;
    let deb = capability_view_model(deb);
    let deb_actions = settings_actions(&deb);
    assert!(deb_actions
        .iter()
        .any(|action| action.kind == SettingsActionKind::DiagnosticsOnly));
    assert!(deb_actions
        .iter()
        .any(|action| action.label.contains("diagnostics")));

    let plan = native_power_path_plan();
    assert!(plan
        .steps
        .iter()
        .any(|step| step.contains("NetworkManager D-Bus")));
    assert!(plan
        .steps
        .iter()
        .any(|step| step.contains("systemd-resolved")));
    assert!(plan.steps.iter().any(|step| step.contains("polkit")));
}

#[test]
fn guided_settings_plan_filters_servers_and_keeps_store_build_non_mutating() {
    let flatpak = capability_view_model(probe(LinuxPackageKind::Flatpak));
    let profile = PlainDnsProfile {
        id: "dual-stack".to_string(),
        name: "Dual Stack".to_string(),
        ipv4_servers: vec!["1.1.1.1".to_string()],
        ipv6_servers: vec!["2606:4700:4700::1111".to_string()],
    };

    assert_eq!(
        profile_servers_for_family(&profile, ResolverAddressFamily::Ipv4Only),
        vec!["1.1.1.1"]
    );
    let plan = build_guided_settings_plan(
        &flatpak,
        &profile,
        ResolverAddressFamily::Ipv4Only,
        Language::Vietnamese,
    )
    .expect("Flatpak should produce guided settings");

    assert_eq!(plan.servers, vec!["1.1.1.1"]);
    assert!(plan.safety_note.contains("Không tự động đổi DNS"));
    assert!(plan.steps.iter().any(|step| step.contains("Sao chép")));
    let rendered = render_guided_settings_plan(&plan);
    assert!(rendered.contains("Dual Stack"));
    assert!(rendered.contains("1.1.1.1"));
    assert!(!rendered.contains("2606:4700:4700::1111"));
}

#[test]
fn guided_settings_plan_rejects_native_or_empty_family_selection() {
    let profile = PlainDnsProfile {
        id: "ipv4-only".to_string(),
        name: "IPv4 only".to_string(),
        ipv4_servers: vec!["9.9.9.9".to_string()],
        ipv6_servers: Vec::new(),
    };
    let native = capability_view_model(probe(LinuxPackageKind::Deb));
    assert_eq!(
        build_guided_settings_plan(
            &native,
            &profile,
            ResolverAddressFamily::Ipv4Only,
            Language::English,
        ),
        Err(GuidedSettingsError::UnavailableForPackage)
    );

    let flatpak = capability_view_model(probe(LinuxPackageKind::Flatpak));
    assert_eq!(
        build_guided_settings_plan(
            &flatpak,
            &profile,
            ResolverAddressFamily::Ipv6Only,
            Language::English,
        ),
        Err(GuidedSettingsError::NoServersForSelectedFamily)
    );
}

#[test]
fn default_suites_include_vietnam_only_when_catalog_supports_it() {
    let suites = default_suite_catalog(true);
    assert!(suites.iter().any(|suite| suite.id == "general"));
    assert!(suites.iter().any(|suite| suite.id == "developer"));
    assert!(suites.iter().any(|suite| suite.id == "vietnam-daily"));
    assert!(suites
        .iter()
        .find(|suite| suite.id == "vietnam-daily")
        .unwrap()
        .domains
        .contains(&"zing.vn"));

    let suites_without_vietnam = default_suite_catalog(false);
    assert!(suites_without_vietnam
        .iter()
        .all(|suite| suite.id != "vietnam-daily"));
}
