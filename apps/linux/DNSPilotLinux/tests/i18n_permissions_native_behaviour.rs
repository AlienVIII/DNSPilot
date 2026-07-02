use dnspilot_linux_shell::capabilities::{
    capability_view_model, LinuxEnvironmentProbe, LinuxPackageKind,
};
use dnspilot_linux_shell::i18n::{localized_text, Language, TextKey};
use dnspilot_linux_shell::native_app::{build_native_app_model, NativeAppSectionKind};
use dnspilot_linux_shell::permissions::{permission_plan, PermissionKind, PermissionStatus};

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
fn vietnamese_strings_are_available_for_native_app_core_actions() {
    assert_eq!(Language::parse("vi"), Some(Language::Vietnamese));
    assert_eq!(Language::parse("en"), Some(Language::English));
    assert_eq!(
        localized_text(TextKey::AppTitle, Language::Vietnamese),
        "DNS Pilot"
    );
    assert_eq!(
        localized_text(TextKey::GuidedSettings, Language::Vietnamese),
        "Hướng dẫn cài đặt"
    );
    assert_eq!(
        localized_text(TextKey::CopyDebugReport, Language::Vietnamese),
        "Sao chép báo cáo debug"
    );
    assert_eq!(
        localized_text(TextKey::Process, Language::Vietnamese),
        "Tiến trình"
    );
    assert_eq!(
        localized_text(TextKey::Status, Language::Vietnamese),
        "Trạng thái"
    );
}

#[test]
fn flatpak_permission_plan_is_store_safe_and_never_requests_system_dns_mutation() {
    let capability = capability_view_model(probe(LinuxPackageKind::Flatpak));
    let plan = permission_plan(&capability, Language::English);

    assert_eq!(plan.package_kind, LinuxPackageKind::Flatpak);
    assert!(plan
        .requests
        .iter()
        .any(|request| request.kind == PermissionKind::Network
            && request.status == PermissionStatus::Required));
    assert!(plan
        .requests
        .iter()
        .any(|request| request.kind == PermissionKind::WaylandWindow
            && request.status == PermissionStatus::Required));
    assert!(plan
        .requests
        .iter()
        .any(|request| request.kind == PermissionKind::SystemDnsMutation
            && request.status == PermissionStatus::NotRequested));
    assert!(plan
        .warnings
        .iter()
        .any(|warning| warning.contains("does not change DNS automatically")));
}

#[test]
fn snap_permission_plan_marks_network_manager_as_manual_not_auto_connected() {
    let mut snap = probe(LinuxPackageKind::Snap);
    snap.network_manager_available = true;
    snap.polkit_available = true;
    let capability = capability_view_model(snap);
    let plan = permission_plan(&capability, Language::English);

    assert!(plan
        .requests
        .iter()
        .any(|request| request.kind == PermissionKind::Network
            && request.status == PermissionStatus::Required));
    assert!(plan.requests.iter().any(|request| request.kind
        == PermissionKind::NetworkManagerControl
        && request.status == PermissionStatus::ManualConnectionOnly
        && request.rationale.contains("not auto-connected")));
    assert!(!plan.can_apply_dns);
}

#[test]
fn native_power_permission_plan_requires_polkit_and_resolver_stack() {
    let mut native = probe(LinuxPackageKind::Deb);
    native.network_manager_available = true;
    native.polkit_available = true;
    native.system_resolver_probe_available = true;
    let capability = capability_view_model(native);
    let plan = permission_plan(&capability, Language::English);

    assert!(plan.can_apply_dns);
    assert!(plan.requests.iter().any(|request| request.kind
        == PermissionKind::PolkitAuthorization
        && request.status == PermissionStatus::Required));
    assert!(plan.requests.iter().any(|request| request.kind
        == PermissionKind::NetworkManagerControl
        && request.status == PermissionStatus::Required));
    assert!(plan.requests.iter().any(|request| request.kind
        == PermissionKind::SystemdResolvedControl
        && request.status == PermissionStatus::OptionalFallback));
}

#[test]
fn native_app_model_has_full_main_window_without_tray_dependency() {
    let capability = capability_view_model(probe(LinuxPackageKind::Flatpak));
    let model = build_native_app_model(&capability, Language::Vietnamese);

    assert!(!model.tray_required);
    assert!(model.tray_note.contains("GNOME"));
    assert!(model
        .sections
        .iter()
        .any(|section| section.kind == NativeAppSectionKind::Benchmark));
    assert!(model
        .sections
        .iter()
        .any(|section| section.kind == NativeAppSectionKind::Profiles));
    assert!(model
        .sections
        .iter()
        .any(|section| section.kind == NativeAppSectionKind::Settings));
    assert!(model
        .sections
        .iter()
        .any(|section| section.kind == NativeAppSectionKind::Diagnostics));
    assert!(model
        .primary_actions
        .iter()
        .any(|action| action.id == "guided-settings" && action.enabled));
}
