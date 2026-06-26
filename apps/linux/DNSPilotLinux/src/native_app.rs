use crate::capabilities::LinuxCapabilityViewModel;
use crate::i18n::{localized_text, Language, TextKey};
use crate::permissions::{permission_plan, LinuxPermissionPlan};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NativeAppSectionKind {
    Benchmark,
    Profiles,
    Settings,
    Diagnostics,
    Permissions,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NativeAppSection {
    pub kind: NativeAppSectionKind,
    pub title: String,
    pub help_text: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NativeAppAction {
    pub id: &'static str,
    pub label: String,
    pub help_text: String,
    pub enabled: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LinuxNativeAppViewModel {
    pub title: String,
    pub language: Language,
    pub package_label: String,
    pub tray_required: bool,
    pub tray_note: String,
    pub sections: Vec<NativeAppSection>,
    pub primary_actions: Vec<NativeAppAction>,
    pub permission_plan: LinuxPermissionPlan,
}

pub fn build_native_app_model(
    capability: &LinuxCapabilityViewModel,
    language: Language,
) -> LinuxNativeAppViewModel {
    let mut primary_actions = vec![
        NativeAppAction {
            id: "run-benchmark",
            label: localized_text(TextKey::RunBenchmark, language).to_string(),
            help_text: "Start the selected benchmark mode for selected DNS profiles.".to_string(),
            enabled: capability.can_benchmark_dns,
        },
        NativeAppAction {
            id: "copy-debug-report",
            label: localized_text(TextKey::CopyDebugReport, language).to_string(),
            help_text: "Copy capability, process, resolver, and result diagnostics.".to_string(),
            enabled: true,
        },
    ];

    if capability.guided_settings_only {
        primary_actions.push(NativeAppAction {
            id: "guided-settings",
            label: localized_text(TextKey::GuidedSettings, language).to_string(),
            help_text: "Open manual DNS settings guidance without mutating system DNS.".to_string(),
            enabled: true,
        });
    } else if capability.can_apply_real_dns {
        primary_actions.push(NativeAppAction {
            id: "native-apply",
            label: localized_text(TextKey::NativeApply, language).to_string(),
            help_text: "Use the native helper path with resolver-stack checks and polkit consent."
                .to_string(),
            enabled: true,
        });
    }

    LinuxNativeAppViewModel {
        title: localized_text(TextKey::AppTitle, language).to_string(),
        language,
        package_label: capability.package_kind.label().to_string(),
        tray_required: false,
        tray_note: "Tray integration is optional; the GNOME/Wayland-safe main window is the primary surface."
            .to_string(),
        sections: vec![
            section(
                NativeAppSectionKind::Benchmark,
                localized_text(TextKey::Benchmark, language),
                "Mode, resolver, suite, IPv4/IPv6, and A/AAAA controls.",
            ),
            section(
                NativeAppSectionKind::Profiles,
                localized_text(TextKey::Profiles, language),
                "Add, edit, delete, and validate custom DNS profiles.",
            ),
            section(
                NativeAppSectionKind::Settings,
                localized_text(TextKey::Settings, language),
                "Capability-based apply path and guided/native DNS controls.",
            ),
            section(
                NativeAppSectionKind::Diagnostics,
                localized_text(TextKey::Diagnostics, language),
                "Per-step status, per-resolver status, and copyable debug report.",
            ),
            section(
                NativeAppSectionKind::Permissions,
                localized_text(TextKey::Permissions, language),
                "Package-specific permission requests and rationale.",
            ),
        ],
        primary_actions,
        permission_plan: permission_plan(capability, language),
    }
}

pub fn render_native_app_model(model: &LinuxNativeAppViewModel) -> String {
    let mut lines = vec![
        model.title.clone(),
        format!("Language: {}", model.language.code()),
        format!("Package: {}", model.package_label),
        format!(
            "Tray: {}",
            if model.tray_required {
                "required"
            } else {
                "optional"
            }
        ),
        model.tray_note.clone(),
        "Sections:".to_string(),
    ];

    for section in &model.sections {
        lines.push(format!("- {}: {}", section.title, section.help_text));
    }

    lines.push("Primary actions:".to_string());
    for action in &model.primary_actions {
        lines.push(format!(
            "- {} [{}]: {}",
            action.label,
            if action.enabled {
                "enabled"
            } else {
                "disabled"
            },
            action.help_text
        ));
    }

    lines.join("\n")
}

fn section(
    kind: NativeAppSectionKind,
    title: &'static str,
    help_text: &'static str,
) -> NativeAppSection {
    NativeAppSection {
        kind,
        title: title.to_string(),
        help_text: help_text.to_string(),
    }
}
