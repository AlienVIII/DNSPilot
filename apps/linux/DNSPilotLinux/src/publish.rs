use crate::capabilities::{LinuxCapabilityViewModel, LinuxPackageKind};
use crate::i18n::Language;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LinuxPublishCheck {
    pub package_kind: LinuxPackageKind,
    pub language: Language,
    pub automated_gate: Vec<&'static str>,
    pub local_qa_steps: Vec<&'static str>,
    pub manual_gates: Vec<&'static str>,
    pub safety_notes: Vec<&'static str>,
}

pub fn publish_check(
    capability: &LinuxCapabilityViewModel,
    language: Language,
) -> LinuxPublishCheck {
    let automated_gate = vec![
        "cargo fmt --manifest-path apps/linux/DNSPilotLinux/Cargo.toml --check",
        "cargo test --manifest-path apps/linux/DNSPilotLinux/Cargo.toml",
        "cargo clippy --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- -D warnings",
        "cargo build --manifest-path apps/linux/DNSPilotLinux/Cargo.toml --release",
    ];

    match capability.package_kind {
        LinuxPackageKind::Flatpak => LinuxPublishCheck {
            package_kind: capability.package_kind,
            language,
            automated_gate,
            local_qa_steps: vec![
                "Build with Flatpak Builder from apps/linux/packaging/flatpak/io.dnspilot.DNSPilot.yml.",
                "Run appstreamcli validate on shared AppStream metadata.",
                "Run desktop-file-validate on the shared desktop entry.",
                "Confirm Flatpak Builder output launches without tray dependency on GNOME/Wayland.",
            ],
            manual_gates: vec![
                "Flathub credentials.",
                "Screenshots and final release notes.",
                "Flathub submission PR and reviewer notes.",
            ],
            safety_notes: vec![
                "Flatpak is benchmark/guidance only and does not mutate system DNS.",
                "Flatpak manifest must not request system-bus, NetworkManager, or systemd-resolved access.",
            ],
        },
        LinuxPackageKind::Snap => LinuxPublishCheck {
            package_kind: capability.package_kind,
            language,
            automated_gate,
            local_qa_steps: vec![
                "Build release payload and pack with snapcraft from apps/linux/packaging/snap.",
                "Install locally with sudo snap install --dangerous.",
                "Check snap connections; only strict store-safe interfaces should be present.",
                "Confirm DNS apply is unavailable in the strict Snap build.",
            ],
            manual_gates: vec![
                "Snapcraft credentials.",
                "Snap name registration.",
                "Store upload/release and final listing review.",
            ],
            safety_notes: vec![
                "Snap is benchmark/guidance only and does not mutate system DNS.",
                "The privileged network-manager/network-control interfaces are not part of the store-safe Snap.",
            ],
        },
        LinuxPackageKind::Deb => LinuxPublishCheck {
            package_kind: capability.package_kind,
            language,
            automated_gate,
            local_qa_steps: vec![
                "Build with debuild -us -uc after wiring release binaries into the Debian tree.",
                "Install the .deb on a Linux VM or hardware target.",
                "Verify NetworkManager/systemd-resolved detection, helper install path, and polkit policy.",
                "Exercise native helper dry-run and execute mutation gate before enabling real DNS writes.",
            ],
            manual_gates: vec![
                "real Linux package QA.",
                "Repository signing or distribution channel credentials.",
                "Final rollback and permission prompt review.",
            ],
            safety_notes: vec![
                "deb is the native power path; real DNS mutation requires resolver stack plus polkit.",
                "The execute mutation gate must stay closed until native write backend QA passes.",
            ],
        },
        LinuxPackageKind::Rpm => LinuxPublishCheck {
            package_kind: capability.package_kind,
            language,
            automated_gate,
            local_qa_steps: vec![
                "Build with rpmbuild -ba apps/linux/packaging/rpm/dnspilot-linux.spec.",
                "Install the RPM on a Linux VM or hardware target.",
                "Verify NetworkManager/systemd-resolved detection, helper install path, and polkit policy.",
                "Exercise native helper dry-run and execute mutation gate before enabling real DNS writes.",
            ],
            manual_gates: vec![
                "real Linux package QA.",
                "Repository signing or distribution channel credentials.",
                "Final rollback and permission prompt review.",
            ],
            safety_notes: vec![
                "rpm is the native power path; real DNS mutation requires resolver stack plus polkit.",
                "The execute mutation gate must stay closed until native write backend QA passes.",
            ],
        },
    }
}

pub fn render_publish_check(check: &LinuxPublishCheck) -> String {
    let package_label = match check.language {
        Language::English => "Package",
        Language::Vietnamese => "Gói",
    };

    let mut lines = vec![
        "DNS Pilot Linux Publish Check".to_string(),
        format!("{package_label}: {}", check.package_kind.label()),
        "Automated gate:".to_string(),
    ];
    lines.extend(numbered(&check.automated_gate));

    lines.push("Local package QA:".to_string());
    lines.extend(numbered(&check.local_qa_steps));

    lines.push("Manual gates:".to_string());
    lines.extend(numbered(&check.manual_gates));

    lines.push("Safety notes:".to_string());
    lines.extend(check.safety_notes.iter().map(|note| format!("- {note}")));

    lines.join("\n")
}

fn numbered(items: &[&'static str]) -> Vec<String> {
    items
        .iter()
        .enumerate()
        .map(|(index, item)| format!("{}. {item}", index + 1))
        .collect()
}
