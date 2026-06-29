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
            safety_notes: flatpak_safety_notes(language),
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
            safety_notes: snap_safety_notes(language),
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
            safety_notes: native_safety_notes(language, "deb"),
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
            safety_notes: native_safety_notes(language, "rpm"),
        },
    }
}

pub fn render_publish_check(check: &LinuxPublishCheck) -> String {
    let package_label = match check.language {
        Language::English => "Package",
        Language::Vietnamese => "Gói",
    };

    let headings = publish_headings(check.language);
    let mut lines = vec![
        "DNS Pilot Linux Publish Check".to_string(),
        format!("{package_label}: {}", check.package_kind.label()),
        format!("{}:", headings.automated_gate),
    ];
    lines.extend(numbered(&check.automated_gate));

    lines.push(format!("{}:", headings.local_package_qa));
    lines.extend(numbered(&check.local_qa_steps));

    lines.push(format!("{}:", headings.manual_gates));
    lines.extend(numbered(&check.manual_gates));

    lines.push(format!("{}:", headings.safety_notes));
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

struct PublishHeadings {
    automated_gate: &'static str,
    local_package_qa: &'static str,
    manual_gates: &'static str,
    safety_notes: &'static str,
}

fn publish_headings(language: Language) -> PublishHeadings {
    match language {
        Language::English => PublishHeadings {
            automated_gate: "Automated gate",
            local_package_qa: "Local package QA",
            manual_gates: "Manual gates",
            safety_notes: "Safety notes",
        },
        Language::Vietnamese => PublishHeadings {
            automated_gate: "Cổng tự động",
            local_package_qa: "Kiểm thử gói cục bộ",
            manual_gates: "Cổng thủ công",
            safety_notes: "Ghi chú an toàn",
        },
    }
}

fn flatpak_safety_notes(language: Language) -> Vec<&'static str> {
    match language {
        Language::English => vec![
            "Flatpak is benchmark/guidance only and does not mutate system DNS.",
            "Flatpak manifest must not request system-bus, NetworkManager, or systemd-resolved access.",
        ],
        Language::Vietnamese => vec![
            "Flatpak chỉ đo kiểm/hướng dẫn và không tự động đổi DNS hệ thống.",
            "Manifest Flatpak không được xin system-bus, NetworkManager, hoặc systemd-resolved.",
        ],
    }
}

fn snap_safety_notes(language: Language) -> Vec<&'static str> {
    match language {
        Language::English => vec![
            "Snap is benchmark/guidance only and does not mutate system DNS.",
            "The privileged network-manager/network-control interfaces are not part of the store-safe Snap.",
        ],
        Language::Vietnamese => vec![
            "Snap chỉ đo kiểm/hướng dẫn và không tự động đổi DNS hệ thống.",
            "Interface đặc quyền network-manager/network-control không thuộc bản Snap store-safe.",
        ],
    }
}

fn native_safety_notes(language: Language, package_label: &'static str) -> Vec<&'static str> {
    match language {
        Language::English => match package_label {
            "deb" => vec![
                "deb is the native power path; real DNS mutation requires resolver stack plus polkit.",
                "The execute mutation gate must stay closed until native write backend QA passes.",
            ],
            _ => vec![
                "rpm is the native power path; real DNS mutation requires resolver stack plus polkit.",
                "The execute mutation gate must stay closed until native write backend QA passes.",
            ],
        },
        Language::Vietnamese => match package_label {
            "deb" => vec![
                "deb là native power path; đổi DNS thật cần resolver stack và polkit.",
                "execute mutation gate phải đóng cho tới khi backend ghi DNS pass QA.",
            ],
            _ => vec![
                "rpm là native power path; đổi DNS thật cần resolver stack và polkit.",
                "execute mutation gate phải đóng cho tới khi backend ghi DNS pass QA.",
            ],
        },
    }
}
