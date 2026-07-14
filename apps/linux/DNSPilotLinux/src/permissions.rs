use crate::capabilities::{LinuxCapabilityViewModel, LinuxPackageKind};
use crate::i18n::{localized_text, Language, TextKey};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PermissionKind {
    Network,
    WaylandWindow,
    X11FallbackWindow,
    DesktopPortal,
    NetworkManagerControl,
    SystemdResolvedControl,
    PolkitAuthorization,
    SystemDnsMutation,
}

impl PermissionKind {
    pub fn label(self) -> &'static str {
        match self {
            Self::Network => "network",
            Self::WaylandWindow => "Wayland window",
            Self::X11FallbackWindow => "X11 fallback window",
            Self::DesktopPortal => "desktop portal",
            Self::NetworkManagerControl => "NetworkManager D-Bus",
            Self::SystemdResolvedControl => "systemd-resolved D-Bus",
            Self::PolkitAuthorization => "polkit authorization",
            Self::SystemDnsMutation => "system DNS mutation",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PermissionStatus {
    Required,
    OptionalFallback,
    ManualConnectionOnly,
    NotRequested,
    Unavailable,
}

impl PermissionStatus {
    pub fn label(self) -> &'static str {
        match self {
            Self::Required => "required",
            Self::OptionalFallback => "optional fallback",
            Self::ManualConnectionOnly => "manual connection only",
            Self::NotRequested => "not requested",
            Self::Unavailable => "unavailable",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PermissionRequest {
    pub kind: PermissionKind,
    pub status: PermissionStatus,
    pub label: String,
    pub rationale: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LinuxPermissionPlan {
    pub package_kind: LinuxPackageKind,
    pub title: String,
    pub can_apply_dns: bool,
    pub requests: Vec<PermissionRequest>,
    pub warnings: Vec<String>,
}

pub fn permission_plan(
    capability: &LinuxCapabilityViewModel,
    language: Language,
) -> LinuxPermissionPlan {
    match capability.package_kind {
        LinuxPackageKind::Flatpak => flatpak_plan(capability, language),
        LinuxPackageKind::Snap => snap_plan(capability, language),
        LinuxPackageKind::Deb | LinuxPackageKind::Rpm => native_plan(capability, language),
    }
}

pub fn render_permission_plan(plan: &LinuxPermissionPlan) -> String {
    let mut lines = vec![
        plan.title.clone(),
        format!("Package: {}", plan.package_kind.label()),
        format!(
            "Real DNS apply: {}",
            if plan.can_apply_dns {
                "available"
            } else {
                "not available"
            }
        ),
        "Requests:".to_string(),
    ];

    for request in &plan.requests {
        lines.push(format!(
            "- {} [{}]: {}",
            request.label,
            request.status.label(),
            request.rationale
        ));
    }

    if !plan.warnings.is_empty() {
        lines.push("Warnings:".to_string());
        lines.extend(plan.warnings.iter().map(|warning| format!("- {warning}")));
    }

    lines.join("\n")
}

fn flatpak_plan(capability: &LinuxCapabilityViewModel, language: Language) -> LinuxPermissionPlan {
    let mut warnings = vec![
        "Flatpak store build does not change DNS automatically; it benchmarks and guides settings only."
            .to_string(),
    ];
    warnings.extend(capability.notes.clone());

    LinuxPermissionPlan {
        package_kind: capability.package_kind,
        title: localized_text(TextKey::Permissions, language).to_string(),
        can_apply_dns: false,
        requests: vec![
            request(
                PermissionKind::Network,
                PermissionStatus::Required,
                "Benchmark resolver latency and TCP reachability.",
            ),
            request(
                PermissionKind::WaylandWindow,
                PermissionStatus::Required,
                "Show the native main window on Wayland sessions.",
            ),
            request(
                PermissionKind::X11FallbackWindow,
                PermissionStatus::OptionalFallback,
                "Support X11 fallback when Wayland is unavailable.",
            ),
            request(
                PermissionKind::DesktopPortal,
                PermissionStatus::Required,
                "Open URLs/settings guidance through desktop portals.",
            ),
            request(
                PermissionKind::SystemDnsMutation,
                PermissionStatus::NotRequested,
                "System resolver writes belong to the native power package.",
            ),
        ],
        warnings,
    }
}

fn snap_plan(capability: &LinuxCapabilityViewModel, language: Language) -> LinuxPermissionPlan {
    let mut warnings = vec![
        "Snap store-safe build uses the auto-connected network interface for benchmarks."
            .to_string(),
        "Snap network-manager is privileged and not auto-connected; DNS apply is not promised."
            .to_string(),
    ];
    warnings.extend(capability.notes.clone());

    LinuxPermissionPlan {
        package_kind: capability.package_kind,
        title: localized_text(TextKey::Permissions, language).to_string(),
        can_apply_dns: false,
        requests: vec![
            request(
                PermissionKind::Network,
                PermissionStatus::Required,
                "Use outbound network access for DNS and TCP benchmarks.",
            ),
            request(
                PermissionKind::WaylandWindow,
                PermissionStatus::Required,
                "Show the native main window on Wayland sessions.",
            ),
            request(
                PermissionKind::X11FallbackWindow,
                PermissionStatus::OptionalFallback,
                "Support X11 fallback when Wayland is unavailable.",
            ),
            request(
                PermissionKind::NetworkManagerControl,
                PermissionStatus::ManualConnectionOnly,
                "Privileged network-manager interface is not auto-connected; use native power packages for apply.",
            ),
            request(
                PermissionKind::SystemDnsMutation,
                PermissionStatus::NotRequested,
                "Store-safe Snap does not mutate system DNS.",
            ),
        ],
        warnings,
    }
}

fn native_plan(capability: &LinuxCapabilityViewModel, language: Language) -> LinuxPermissionPlan {
    let can_apply_dns = false;
    let mut warnings = vec![
        "Native DNS Power is unavailable in this build; no NetworkManager, systemd-resolved, polkit, or DNS-mutation privilege is requested."
            .to_string(),
    ];
    warnings.extend(capability.notes.clone());

    LinuxPermissionPlan {
        package_kind: capability.package_kind,
        title: localized_text(TextKey::Permissions, language).to_string(),
        can_apply_dns,
        requests: vec![
            request(
                PermissionKind::Network,
                PermissionStatus::Required,
                "Benchmark DNS and TCP connectivity before and after apply.",
            ),
            request(
                PermissionKind::NetworkManagerControl,
                PermissionStatus::NotRequested,
                "Reserved for the separately verified native Power service.",
            ),
            request(
                PermissionKind::SystemdResolvedControl,
                PermissionStatus::NotRequested,
                "Reserved for the separately verified native Power service.",
            ),
            request(
                PermissionKind::PolkitAuthorization,
                PermissionStatus::NotRequested,
                "Reserved for caller-bound authorization in a future native Power service.",
            ),
            request(
                PermissionKind::SystemDnsMutation,
                PermissionStatus::NotRequested,
                "This build never changes system DNS automatically.",
            ),
        ],
        warnings,
    }
}

fn request(
    kind: PermissionKind,
    status: PermissionStatus,
    rationale: impl Into<String>,
) -> PermissionRequest {
    PermissionRequest {
        kind,
        status,
        label: kind.label().to_string(),
        rationale: rationale.into(),
    }
}
