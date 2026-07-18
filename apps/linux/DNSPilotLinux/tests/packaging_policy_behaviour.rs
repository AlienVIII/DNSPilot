use std::fs;
use std::path::PathBuf;
use std::process::Command;

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
    assert!(manifest.contains("runtime: org.freedesktop.Platform"));
    assert!(manifest.contains("sdk: org.freedesktop.Sdk"));
    assert!(manifest.contains("runtime-version: '25.08'"));
    assert!(!manifest.contains("org.gnome.Platform"));
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

    assert!(manifest.contains("grade: stable"));
    assert!(manifest.contains("confinement: strict"));
    assert!(manifest.contains("- network"));
    assert!(manifest.contains("- wayland"));
    assert!(manifest.contains("- x11"));
    assert!(!manifest.contains("- network-manager"));
    assert!(!manifest.contains("- network-control"));
}

#[test]
fn default_native_package_templates_exclude_unavailable_power_files() {
    let deb = read_packaging_file("packaging/deb/control");
    let deb_install = read_packaging_file("packaging/deb/dnspilot.install");
    let rpm = read_packaging_file("packaging/rpm/dnspilot-linux.spec");
    assert!(deb_install.contains("dnspilot-linux-gui usr/bin/"));
    assert!(deb_install.contains("dnspilot-linux-shell usr/bin/"));
    assert!(!deb_install.contains("dnspilot-native-helper"));
    assert!(!deb_install.contains("polkit-1/actions"));
    assert!(!deb.contains("Recommends: polkit"));
    assert!(!deb.contains("Recommends: network-manager"));
    assert!(!rpm.contains("Recommends: polkit"));
    assert!(!rpm.contains("Recommends: NetworkManager"));
    assert!(rpm.contains("install -Dm755 %{SOURCE0}"));
    assert!(rpm.contains("%{_bindir}/dnspilot-linux-gui"));
    assert!(!rpm.contains("dnspilot-native-helper"));
    assert!(!rpm.contains("polkit-1/actions"));
}

#[test]
fn shared_desktop_metadata_is_localized_and_launchable() {
    let desktop = read_packaging_file("packaging/shared/io.dnspilot.DNSPilot.desktop");
    let metainfo = read_packaging_file("packaging/shared/io.dnspilot.DNSPilot.metainfo.xml");

    assert!(desktop.contains("Name=DNS Pilot"));
    assert!(desktop.contains("Comment[vi]="));
    assert!(desktop.contains("Exec=dnspilot-linux-gui"));
    assert!(desktop.contains("Categories=Network;Utility;"));
    assert!(desktop.contains("Terminal=false"));
    assert!(metainfo.contains("<id>io.dnspilot.DNSPilot</id>"));
    assert!(metainfo
        .contains("<launchable type=\"desktop-id\">io.dnspilot.DNSPilot.desktop</launchable>"));
    assert!(metainfo.contains("<content_rating type=\"oars-1.1\" />"));
    assert!(metainfo.contains("xml:lang=\"vi\""));
}

#[test]
fn store_package_templates_launch_gui_binary_and_keep_shell_for_qa() {
    let flatpak = read_packaging_file("packaging/flatpak/io.dnspilot.DNSPilot.yml");
    let snap = read_packaging_file("packaging/snap/snapcraft.yaml");
    let cargo = fs::read_to_string(PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("Cargo.toml"))
        .expect("expected Cargo.toml to be readable");

    assert!(cargo.contains("name = \"dnspilot-linux-gui\""));
    assert!(flatpak.contains("command: dnspilot-linux-gui"));
    assert!(flatpak.contains("install -Dm755 dnspilot-linux-gui /app/bin/dnspilot-linux-gui"));
    assert!(flatpak.contains("install -Dm755 dnspilot-linux-shell /app/bin/dnspilot-linux-shell"));
    assert!(snap.contains("command: bin/dnspilot-linux-gui"));
    assert!(snap.contains("dnspilot-linux-gui: bin/dnspilot-linux-gui"));
    assert!(snap.contains("dnspilot-linux-shell: bin/dnspilot-linux-shell"));
}

#[test]
fn every_linux_package_ships_the_core_cli_engine() {
    let flatpak = read_packaging_file("packaging/flatpak/io.dnspilot.DNSPilot.yml");
    let snap = read_packaging_file("packaging/snap/snapcraft.yaml");
    let deb_install = read_packaging_file("packaging/deb/dnspilot.install");
    let rpm = read_packaging_file("packaging/rpm/dnspilot-linux.spec");

    assert!(flatpak.contains("dnspilot-cli /app/bin/dnspilot-cli"));
    assert!(flatpak.contains("target/release/dnspilot-cli"));
    assert!(snap.contains("dnspilot-cli: bin/dnspilot-cli"));
    assert!(deb_install.contains("dnspilot-cli usr/bin/"));
    assert!(rpm.contains("%{_bindir}/dnspilot-cli"));
}

#[test]
fn package_build_script_stages_one_linux_payload_and_exposes_every_format() {
    let script_path = linux_root().join("scripts/build-packages.sh");
    let syntax = Command::new("bash")
        .arg("-n")
        .arg(&script_path)
        .output()
        .expect("bash should validate package script");
    assert!(
        syntax.status.success(),
        "package script syntax failed: {}",
        String::from_utf8_lossy(&syntax.stderr)
    );

    let help = Command::new("bash")
        .arg(&script_path)
        .arg("--help")
        .output()
        .expect("package script help should run");
    assert!(help.status.success());
    let help = String::from_utf8(help.stdout).expect("help should be UTF-8");
    for mode in ["stage", "flatpak", "snap", "deb", "rpm", "all"] {
        assert!(help.contains(mode), "help should include {mode}");
    }

    let script = read_packaging_file("scripts/build-packages.sh");
    assert!(script.contains("cargo build --locked --release -p dnspilot-cli"));
    assert!(script.contains("cargo build --locked --release --manifest-path"));
    assert!(script.contains("ELF"));
    assert!(script.contains("flatpak-builder"));
    assert!(script.contains("snapcraft"));
    assert!(script.contains("dpkg-deb"));
    assert!(script.contains("rpmbuild"));
}

#[test]
fn native_package_recipes_are_buildable_from_the_staged_payload() {
    let deb = read_packaging_file("packaging/deb/control.binary");
    let rpm = read_packaging_file("packaging/rpm/dnspilot-linux.spec");

    assert!(deb.contains("Package: dnspilot"));
    assert!(deb.contains("Native DNS"));
    assert!(!deb.contains("polkit"));
    assert!(!deb.contains("network-manager"));
    for source in [
        "Source0: dnspilot-linux-gui",
        "Source1: dnspilot-linux-shell",
        "Source2: dnspilot-cli",
        "Source3: io.dnspilot.DNSPilot.desktop",
    ] {
        assert!(rpm.contains(source), "rpm recipe should include {source}");
    }
}
