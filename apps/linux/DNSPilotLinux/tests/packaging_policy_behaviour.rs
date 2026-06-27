use std::fs;
use std::path::PathBuf;

fn linux_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .to_path_buf()
}

fn read_packaging_file(path: &str) -> String {
    fs::read_to_string(linux_root().join(path)).unwrap_or_else(|error| {
        panic!("expected packaging file {path} to exist and be readable: {error}")
    })
}

#[test]
fn flatpak_manifest_is_store_safe_and_does_not_request_system_dns_control() {
    let manifest = read_packaging_file("packaging/flatpak/io.dnspilot.DNSPilot.yml");

    assert!(manifest.contains("app-id: io.dnspilot.DNSPilot"));
    assert!(manifest.contains("--share=network"));
    assert!(manifest.contains("--socket=wayland"));
    assert!(manifest.contains("--socket=fallback-x11"));
    assert!(!manifest.contains("--socket=system-bus"));
    assert!(!manifest.contains("org.freedesktop.NetworkManager"));
    assert!(!manifest.contains("org.freedesktop.resolve1"));
}

#[test]
fn snap_manifest_stays_strict_and_avoids_privileged_network_manager_plug() {
    let manifest = read_packaging_file("packaging/snap/snapcraft.yaml");

    assert!(manifest.contains("confinement: strict"));
    assert!(manifest.contains("- network"));
    assert!(manifest.contains("- wayland"));
    assert!(manifest.contains("- x11"));
    assert!(!manifest.contains("- network-manager"));
    assert!(!manifest.contains("- network-control"));
}

#[test]
fn native_package_templates_install_polkit_policy_for_dns_apply() {
    let deb = read_packaging_file("packaging/deb/control");
    let deb_install = read_packaging_file("packaging/deb/dnspilot.install");
    let rpm = read_packaging_file("packaging/rpm/dnspilot-linux.spec");
    let policy = read_packaging_file("packaging/polkit/io.dnspilot.DNSPilot.apply.policy");

    assert!(deb.contains("policykit-1") || deb.contains("polkitd"));
    assert!(deb.contains("network-manager") || deb.contains("systemd-resolved"));
    assert!(deb_install.contains("dnspilot-native-helper usr/libexec/dnspilot/"));
    assert!(deb_install.contains("io.dnspilot.DNSPilot.apply.policy usr/share/polkit-1/actions/"));
    assert!(rpm.contains("Requires: polkit"));
    assert!(rpm.contains("%{_libexecdir}/dnspilot/dnspilot-native-helper"));
    assert!(rpm.contains("polkit-1/actions/io.dnspilot.DNSPilot.apply.policy"));
    assert!(policy.contains("io.dnspilot.DNSPilot.apply-dns"));
    assert!(policy.contains("<allow_active>auth_admin_keep</allow_active>"));
}

#[test]
fn shared_desktop_metadata_is_localized_and_launchable() {
    let desktop = read_packaging_file("packaging/shared/io.dnspilot.DNSPilot.desktop");
    let metainfo = read_packaging_file("packaging/shared/io.dnspilot.DNSPilot.metainfo.xml");

    assert!(desktop.contains("Name=DNS Pilot"));
    assert!(desktop.contains("Comment[vi]="));
    assert!(desktop.contains("Categories=Network;Utility;"));
    assert!(desktop.contains("Terminal=false"));
    assert!(metainfo.contains("<id>io.dnspilot.DNSPilot</id>"));
    assert!(metainfo
        .contains("<launchable type=\"desktop-id\">io.dnspilot.DNSPilot.desktop</launchable>"));
    assert!(metainfo.contains("<content_rating type=\"oars-1.1\" />"));
    assert!(metainfo.contains("xml:lang=\"vi\""));
}
