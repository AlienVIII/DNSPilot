#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ReadinessStatus {
    Ready,
    ExternalQaRequired,
}

impl ReadinessStatus {
    pub fn label(self) -> &'static str {
        match self {
            Self::Ready => "ready",
            Self::ExternalQaRequired => "external QA required",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReadinessItem {
    pub name: &'static str,
    pub status: ReadinessStatus,
    pub evidence: &'static str,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LinuxReleaseReadiness {
    pub code_ready: bool,
    pub items: Vec<ReadinessItem>,
    pub external_requirements: Vec<&'static str>,
}

pub fn linux_release_readiness() -> LinuxReleaseReadiness {
    LinuxReleaseReadiness {
        code_ready: true,
        items: vec![
            item(
                "Capability matrix",
                "Flatpak, Snap, deb, rpm modeled and tested as capabilities.",
            ),
            item(
                "Benchmark modes",
                "DNS only, DNS + TCP, and current/system resolver validation are gated and tested.",
            ),
            item(
                "Process UI",
                "Idle/running/success/failed states exist per step and resolver.",
            ),
            item(
                "Diagnostics",
                "Copyable debug report includes capability, process, resolver, and result context.",
            ),
            item(
                "Guided settings",
                "Flatpak/Snap stay benchmark/guidance only and never mutate DNS.",
            ),
            item(
                "Native power path",
                "deb/rpm apply-plan, native-helper request protocol, execute mutation gate, and mock dry-run lifecycle require resolver stack plus polkit and include rollback/validation.",
            ),
            item(
                "Native app surface",
                "Main-window view model, localized primary actions, desktop metadata, and tray-optional invariant are present.",
            ),
            item(
                "Custom DNS profiles",
                "Add/edit/delete/list are persisted and validation-backed.",
            ),
            item(
                "IPv4/IPv6 and A/AAAA controls",
                "Resolver-family and record-family controls have help text and affect plans.",
            ),
            item(
                "Suites",
                "Default suites and catalog-gated Vietnam suite are tested.",
            ),
            item(
                "Localization",
                "English/Vietnamese primary app, permission, and guided-settings surfaces are implemented.",
            ),
            item(
                "Packaging and publish checklist",
                "Flatpak/Snap store-safe templates, deb/rpm native-power templates, helper install paths, AppStream, desktop file, icon, polkit policy, publish-check CLI, and publish checklist are present.",
            ),
        ],
        external_requirements: vec![
            "Flatpak/Snap/deb/rpm real package QA on Linux hardware or VM.",
            "store credentials, signing, screenshots, release notes, and final metadata review.",
            "GTK/libadwaita or Qt rendering adapter if a graphical shell is selected for the release artifact.",
            "Native resolver write backend and Linux QA before enabling real DNS mutation in deb/rpm.",
        ],
    }
}

pub fn render_readiness_report(readiness: &LinuxReleaseReadiness) -> String {
    let mut lines = vec![
        "DNS Pilot Linux Readiness".to_string(),
        format!(
            "Code readiness: {}",
            if readiness.code_ready {
                "ready for manual Linux package QA"
            } else {
                "not ready"
            }
        ),
        "Main goals:".to_string(),
    ];

    for item in &readiness.items {
        lines.push(format!(
            "- {}: {} - {}",
            item.name,
            item.status.label(),
            item.evidence
        ));
    }

    lines.push("Manual/external requirements:".to_string());
    for requirement in &readiness.external_requirements {
        lines.push(format!("- {requirement}"));
    }

    lines.join("\n")
}

fn item(name: &'static str, evidence: &'static str) -> ReadinessItem {
    ReadinessItem {
        name,
        status: ReadinessStatus::Ready,
        evidence,
    }
}
