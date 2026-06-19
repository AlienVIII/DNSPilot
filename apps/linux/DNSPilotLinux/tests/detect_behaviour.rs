use dnspilot_linux_shell::capabilities::LinuxPackageKind;
use dnspilot_linux_shell::detect::{
    detect_linux_environment_from_snapshot, LinuxDetectionSnapshot,
};

#[test]
fn detects_flatpak_from_environment_or_flatpak_info_without_native_apply() {
    let probe = detect_linux_environment_from_snapshot(
        &LinuxDetectionSnapshot::empty()
            .with_env("FLATPAK_ID", "com.example.DNSPilot")
            .with_command("nmcli")
            .with_command("pkcheck"),
    );

    assert_eq!(probe.package_kind, LinuxPackageKind::Flatpak);
    assert!(probe.network_manager_available);
    assert!(probe.polkit_available);

    let probe_from_path = detect_linux_environment_from_snapshot(
        &LinuxDetectionSnapshot::empty().with_path("/.flatpak-info"),
    );
    assert_eq!(probe_from_path.package_kind, LinuxPackageKind::Flatpak);
}

#[test]
fn detects_snap_from_environment_and_keeps_network_manager_as_capability_only() {
    let probe = detect_linux_environment_from_snapshot(
        &LinuxDetectionSnapshot::empty()
            .with_env("SNAP", "/snap/dnspilot/current")
            .with_command("nmcli")
            .with_command("pkcheck"),
    );

    assert_eq!(probe.package_kind, LinuxPackageKind::Snap);
    assert!(probe.network_manager_available);
    assert!(probe.polkit_available);
}

#[test]
fn detects_rpm_native_when_rpm_markers_exist() {
    let probe = detect_linux_environment_from_snapshot(
        &LinuxDetectionSnapshot::empty()
            .with_path("/etc/fedora-release")
            .with_command("resolvectl")
            .with_command("pkcheck"),
    );

    assert_eq!(probe.package_kind, LinuxPackageKind::Rpm);
    assert!(probe.systemd_resolved_available);
    assert!(probe.polkit_available);
}

#[test]
fn defaults_to_deb_native_when_no_sandbox_or_rpm_marker_exists() {
    let probe = detect_linux_environment_from_snapshot(
        &LinuxDetectionSnapshot::empty()
            .with_path("/etc/resolv.conf")
            .with_command("resolvectl"),
    );

    assert_eq!(probe.package_kind, LinuxPackageKind::Deb);
    assert!(probe.systemd_resolved_available);
    assert!(probe.system_resolver_probe_available);
}

#[test]
fn explicit_package_override_wins_for_deterministic_qa() {
    let probe = detect_linux_environment_from_snapshot(
        &LinuxDetectionSnapshot::empty()
            .with_env("DNSPILOT_LINUX_PACKAGE", "rpm")
            .with_env("FLATPAK_ID", "com.example.DNSPilot"),
    );

    assert_eq!(probe.package_kind, LinuxPackageKind::Rpm);
}
