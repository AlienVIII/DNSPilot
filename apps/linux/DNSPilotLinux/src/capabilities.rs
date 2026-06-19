#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LinuxPackageKind {
    Flatpak,
    Snap,
    Deb,
    Rpm,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LinuxApplyPath {
    GuidedSettings,
    NativePowerPackage,
    Unsupported,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BenchmarkMode {
    DnsOnly,
    DnsAndTcp,
    CurrentSystemResolver,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LinuxEnvironmentProbe {
    pub package_kind: LinuxPackageKind,
    pub network_manager_available: bool,
    pub systemd_resolved_available: bool,
    pub polkit_available: bool,
    pub system_resolver_probe_available: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LinuxCapabilityViewModel {
    pub package_kind: LinuxPackageKind,
    pub can_benchmark_dns: bool,
    pub can_benchmark_tcp: bool,
    pub can_validate_current_system_resolver: bool,
    pub can_apply_real_dns: bool,
    pub apply_path: LinuxApplyPath,
    pub guided_settings_only: bool,
    pub tray_required: bool,
    pub notes: Vec<String>,
}

pub fn capability_view_model(probe: LinuxEnvironmentProbe) -> LinuxCapabilityViewModel {
    let has_native_resolver_stack =
        probe.network_manager_available || probe.systemd_resolved_available;
    let has_native_power_path = has_native_resolver_stack && probe.polkit_available;
    let mut notes = Vec::new();

    let (can_apply_real_dns, apply_path, guided_settings_only) = match probe.package_kind {
        LinuxPackageKind::Flatpak => {
            notes.push(
                "Flatpak build is store-safe: benchmark first, then guided settings guidance."
                    .to_string(),
            );
            (false, LinuxApplyPath::GuidedSettings, true)
        }
        LinuxPackageKind::Snap => {
            notes.push(
                "Snap network-manager interface is privileged and not auto-connect; do not promise apply."
                    .to_string(),
            );
            (false, LinuxApplyPath::GuidedSettings, true)
        }
        LinuxPackageKind::Deb | LinuxPackageKind::Rpm if has_native_power_path => {
            notes.push(
                "Native package can route real DNS apply through NetworkManager or systemd-resolved with polkit."
                    .to_string(),
            );
            (true, LinuxApplyPath::NativePowerPackage, false)
        }
        LinuxPackageKind::Deb | LinuxPackageKind::Rpm => {
            notes.push(
                "NetworkManager or systemd-resolved plus polkit is required before real DNS apply is offered."
                    .to_string(),
            );
            (false, LinuxApplyPath::GuidedSettings, true)
        }
    };

    LinuxCapabilityViewModel {
        package_kind: probe.package_kind,
        can_benchmark_dns: true,
        can_benchmark_tcp: true,
        can_validate_current_system_resolver: probe.system_resolver_probe_available,
        can_apply_real_dns,
        apply_path,
        guided_settings_only,
        tray_required: false,
        notes,
    }
}

pub fn available_benchmark_modes(capability: &LinuxCapabilityViewModel) -> Vec<BenchmarkMode> {
    let mut modes = vec![BenchmarkMode::DnsOnly, BenchmarkMode::DnsAndTcp];
    if capability.can_validate_current_system_resolver {
        modes.push(BenchmarkMode::CurrentSystemResolver);
    }
    modes
}
