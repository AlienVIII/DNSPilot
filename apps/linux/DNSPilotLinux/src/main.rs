use dnspilot_linux_shell::capabilities::{
    available_benchmark_modes, capability_view_model, LinuxEnvironmentProbe, LinuxPackageKind,
};

fn main() {
    let probe = LinuxEnvironmentProbe {
        package_kind: LinuxPackageKind::Flatpak,
        network_manager_available: false,
        systemd_resolved_available: false,
        polkit_available: false,
        system_resolver_probe_available: false,
    };
    let capability = capability_view_model(probe);
    println!("{capability:#?}");
    println!("{:#?}", available_benchmark_modes(&capability));
}
