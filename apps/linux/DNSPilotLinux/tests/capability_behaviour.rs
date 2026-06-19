use dnspilot_linux_shell::capabilities::{
    available_benchmark_modes, capability_view_model, BenchmarkMode, LinuxApplyPath,
    LinuxEnvironmentProbe, LinuxPackageKind,
};

fn probe(package_kind: LinuxPackageKind) -> LinuxEnvironmentProbe {
    LinuxEnvironmentProbe {
        package_kind,
        network_manager_available: false,
        systemd_resolved_available: false,
        polkit_available: false,
        system_resolver_probe_available: false,
    }
}

#[test]
fn flatpak_is_guided_benchmark_first_and_never_real_apply() {
    let capability = capability_view_model(probe(LinuxPackageKind::Flatpak));

    assert!(capability.can_benchmark_dns);
    assert!(capability.can_benchmark_tcp);
    assert!(!capability.can_validate_current_system_resolver);
    assert!(!capability.can_apply_real_dns);
    assert_eq!(capability.apply_path, LinuxApplyPath::GuidedSettings);
    assert!(capability.guided_settings_only);
    assert!(!capability.tray_required);
    assert!(capability
        .notes
        .iter()
        .any(|note| note.contains("Flatpak") && note.contains("guidance")));
}

#[test]
fn snap_does_not_promise_network_manager_apply_without_power_package() {
    let mut snap = probe(LinuxPackageKind::Snap);
    snap.network_manager_available = true;
    snap.polkit_available = true;

    let capability = capability_view_model(snap);

    assert!(capability.can_benchmark_dns);
    assert!(capability.can_benchmark_tcp);
    assert!(!capability.can_apply_real_dns);
    assert_eq!(capability.apply_path, LinuxApplyPath::GuidedSettings);
    assert!(capability.guided_settings_only);
    assert!(capability
        .notes
        .iter()
        .any(|note| note.contains("Snap") && note.contains("not auto-connect")));
}

#[test]
fn deb_or_rpm_can_offer_native_power_apply_when_resolver_stack_and_polkit_exist() {
    for package_kind in [LinuxPackageKind::Deb, LinuxPackageKind::Rpm] {
        let mut native = probe(package_kind);
        native.network_manager_available = true;
        native.polkit_available = true;
        native.system_resolver_probe_available = true;

        let capability = capability_view_model(native);

        assert!(capability.can_benchmark_dns);
        assert!(capability.can_benchmark_tcp);
        assert!(capability.can_validate_current_system_resolver);
        assert!(capability.can_apply_real_dns);
        assert_eq!(capability.apply_path, LinuxApplyPath::NativePowerPackage);
        assert!(!capability.guided_settings_only);
    }
}

#[test]
fn deb_or_rpm_without_resolver_stack_stays_diagnostic_without_guided_settings() {
    let mut native = probe(LinuxPackageKind::Deb);
    native.polkit_available = true;

    let capability = capability_view_model(native);

    assert!(!capability.can_apply_real_dns);
    assert_eq!(capability.apply_path, LinuxApplyPath::Unsupported);
    assert!(!capability.guided_settings_only);
    assert!(capability
        .notes
        .iter()
        .any(|note| note.contains("NetworkManager") && note.contains("systemd-resolved")));
}

#[test]
fn benchmark_modes_are_capability_based() {
    let flatpak = capability_view_model(probe(LinuxPackageKind::Flatpak));
    assert_eq!(
        available_benchmark_modes(&flatpak),
        vec![BenchmarkMode::DnsOnly, BenchmarkMode::DnsAndTcp]
    );

    let mut native = probe(LinuxPackageKind::Deb);
    native.system_resolver_probe_available = true;
    let native = capability_view_model(native);
    assert_eq!(
        available_benchmark_modes(&native),
        vec![
            BenchmarkMode::DnsOnly,
            BenchmarkMode::DnsAndTcp,
            BenchmarkMode::CurrentSystemResolver
        ]
    );
}
