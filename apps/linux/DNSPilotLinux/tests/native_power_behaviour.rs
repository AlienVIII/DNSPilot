use dnspilot_linux_shell::capabilities::{
    capability_view_model, LinuxEnvironmentProbe, LinuxPackageKind,
};
use dnspilot_linux_shell::native_power::{
    build_native_apply_plan, NativeApplyError, NativeApplyStepKind, NativeResolverStack,
};
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
fn native_apply_plan_requires_polkit_and_resolver_stack() {
    let capability = capability_view_model(probe(LinuxPackageKind::Deb));

    let error =
        build_native_apply_plan(&capability, &profile(), ResolverAddressFamily::Auto).unwrap_err();

    assert_eq!(error, NativeApplyError::MissingNativePowerCapability);
}

#[test]
fn native_apply_plan_prefers_network_manager_and_filters_ipv4_servers() {
    let mut native = probe(LinuxPackageKind::Deb);
    native.network_manager_available = true;
    native.systemd_resolved_available = true;
    native.polkit_available = true;
    native.system_resolver_probe_available = true;
    let capability = capability_view_model(native);

    let plan =
        build_native_apply_plan(&capability, &profile(), ResolverAddressFamily::Ipv4Only).unwrap();

    assert_eq!(plan.resolver_stack, NativeResolverStack::NetworkManager);
    assert_eq!(plan.polkit_action_id, "io.dnspilot.DNSPilot.apply-dns");
    assert_eq!(plan.servers, vec!["1.1.1.1", "9.9.9.9"]);
    assert!(plan.requires_rollback_snapshot);
    assert!(plan.post_apply_validation);
    assert!(plan
        .steps
        .iter()
        .any(|step| step.kind == NativeApplyStepKind::AuthorizeWithPolkit));
    assert!(plan
        .steps
        .iter()
        .any(|step| step.kind == NativeApplyStepKind::WriteNetworkManagerDns));
}

#[test]
fn native_apply_plan_uses_systemd_resolved_fallback_for_ipv6() {
    let mut native = probe(LinuxPackageKind::Rpm);
    native.systemd_resolved_available = true;
    native.polkit_available = true;
    let capability = capability_view_model(native);

    let plan =
        build_native_apply_plan(&capability, &profile(), ResolverAddressFamily::Ipv6Only).unwrap();

    assert_eq!(plan.resolver_stack, NativeResolverStack::SystemdResolved);
    assert_eq!(plan.servers, vec!["2606:4700:4700::1111"]);
    assert!(plan
        .steps
        .iter()
        .any(|step| step.kind == NativeApplyStepKind::WriteSystemdResolvedDns));
}

#[test]
fn native_apply_plan_rejects_profile_without_selected_address_family() {
    let mut native = probe(LinuxPackageKind::Deb);
    native.network_manager_available = true;
    native.polkit_available = true;
    let capability = capability_view_model(native);
    let mut ipv4_only = profile();
    ipv4_only.ipv6_servers.clear();

    let error = build_native_apply_plan(&capability, &ipv4_only, ResolverAddressFamily::Ipv6Only)
        .unwrap_err();

    assert_eq!(error, NativeApplyError::NoServersForSelectedFamily);
}
