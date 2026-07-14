use dnspilot_linux_shell::capabilities::{
    capability_view_model, LinuxEnvironmentProbe, LinuxPackageKind,
};
use dnspilot_linux_shell::native_power::{build_native_apply_plan, NativeApplyError};
use dnspilot_linux_shell::profiles::PlainDnsProfile;
use dnspilot_linux_shell::settings::ResolverAddressFamily;

fn probe(package_kind: LinuxPackageKind) -> LinuxEnvironmentProbe {
    LinuxEnvironmentProbe {
        package_kind,
        network_manager_available: false,
        systemd_resolved_available: false,
        polkit_available: false,
        system_resolver_probe_available: false,
    }
}

fn profile() -> PlainDnsProfile {
    PlainDnsProfile {
        id: "local".to_string(),
        name: "Local DNS".to_string(),
        ipv4_servers: vec!["1.1.1.1".to_string(), "9.9.9.9".to_string()],
        ipv6_servers: vec!["2606:4700:4700::1111".to_string()],
    }
}

#[test]
fn native_apply_plan_rejects_store_packages_before_any_dns_write() {
    let capability = capability_view_model(probe(LinuxPackageKind::Flatpak));

    let error =
        build_native_apply_plan(&capability, &profile(), ResolverAddressFamily::Auto).unwrap_err();

    assert_eq!(error, NativeApplyError::UnsupportedPackage);
}

#[test]
fn native_apply_plan_stays_unavailable_even_when_a_native_stack_is_detected() {
    let mut native = probe(LinuxPackageKind::Deb);
    native.network_manager_available = true;
    native.systemd_resolved_available = true;
    native.polkit_available = true;
    native.system_resolver_probe_available = true;
    let capability = capability_view_model(native);

    let error = build_native_apply_plan(&capability, &profile(), ResolverAddressFamily::Ipv4Only)
        .unwrap_err();

    assert_eq!(error, NativeApplyError::PowerExecutionUnavailable);
}
