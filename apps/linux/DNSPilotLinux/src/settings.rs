use crate::capabilities::{LinuxCapabilityViewModel, LinuxPackageKind};
use crate::i18n::Language;
use crate::profiles::PlainDnsProfile;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ResolverAddressFamily {
    Auto,
    Ipv4Only,
    Ipv6Only,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DnsRecordFamily {
    AAndAaaa,
    AOnly,
    AaaaOnly,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ChoiceControlViewModel<T> {
    pub value: T,
    pub label: &'static str,
    pub help_text: &'static str,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SettingsActionKind {
    GuidedSettings,
    NativePowerApply,
    DiagnosticsOnly,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SettingsActionViewModel {
    pub kind: SettingsActionKind,
    pub label: &'static str,
    pub help_text: &'static str,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NativePowerPathPlan {
    pub title: &'static str,
    pub steps: Vec<&'static str>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GuidedSettingsPlan {
    pub package_kind: LinuxPackageKind,
    pub language: Language,
    pub title: &'static str,
    pub profile_id: String,
    pub profile_name: String,
    pub servers: Vec<String>,
    pub steps: Vec<&'static str>,
    pub safety_note: &'static str,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GuidedSettingsError {
    UnavailableForPackage,
    NoServersForSelectedFamily,
}

pub fn resolver_address_family_controls() -> Vec<ChoiceControlViewModel<ResolverAddressFamily>> {
    vec![
        ChoiceControlViewModel {
            value: ResolverAddressFamily::Auto,
            label: "Auto",
            help_text: "Use all DNS server addresses in the selected profile.",
        },
        ChoiceControlViewModel {
            value: ResolverAddressFamily::Ipv4Only,
            label: "IPv4",
            help_text: "Use only IPv4 DNS servers when IPv6 routing or DNS is unreliable.",
        },
        ChoiceControlViewModel {
            value: ResolverAddressFamily::Ipv6Only,
            label: "IPv6",
            help_text: "Use only IPv6 DNS servers when validating IPv6 reachability.",
        },
    ]
}

pub fn dns_record_family_controls() -> Vec<ChoiceControlViewModel<DnsRecordFamily>> {
    vec![
        ChoiceControlViewModel {
            value: DnsRecordFamily::AAndAaaa,
            label: "A + AAAA",
            help_text: "Measure both IPv4 and IPv6 DNS answers for a balanced result.",
        },
        ChoiceControlViewModel {
            value: DnsRecordFamily::AOnly,
            label: "A only",
            help_text:
                "Measure IPv4 answers only; useful when IPv6 is broken on the current network.",
        },
        ChoiceControlViewModel {
            value: DnsRecordFamily::AaaaOnly,
            label: "AAAA only",
            help_text: "Measure IPv6 answers only for IPv6-specific troubleshooting.",
        },
    ]
}

pub fn settings_actions(capability: &LinuxCapabilityViewModel) -> Vec<SettingsActionViewModel> {
    if capability.guided_settings_only {
        vec![SettingsActionViewModel {
            kind: SettingsActionKind::GuidedSettings,
            label: "Open guided settings",
            help_text: "Copies DNS values and opens OS settings guidance; it does not change DNS.",
        }]
    } else if capability.can_apply_real_dns {
        vec![SettingsActionViewModel {
            kind: SettingsActionKind::NativePowerApply,
            label: "Review native apply",
            help_text:
                "Uses the native power package path with resolver-stack checks and polkit consent.",
        }]
    } else {
        vec![SettingsActionViewModel {
            kind: SettingsActionKind::DiagnosticsOnly,
            label: "Show diagnostics",
            help_text:
                "Real DNS apply is unavailable until a supported resolver stack is detected.",
        }]
    }
}

pub fn profile_servers_for_family(
    profile: &PlainDnsProfile,
    family: ResolverAddressFamily,
) -> Vec<String> {
    match family {
        ResolverAddressFamily::Auto => profile
            .ipv4_servers
            .iter()
            .chain(profile.ipv6_servers.iter())
            .cloned()
            .collect(),
        ResolverAddressFamily::Ipv4Only => profile.ipv4_servers.clone(),
        ResolverAddressFamily::Ipv6Only => profile.ipv6_servers.clone(),
    }
}

pub fn build_guided_settings_plan(
    capability: &LinuxCapabilityViewModel,
    profile: &PlainDnsProfile,
    family: ResolverAddressFamily,
    language: Language,
) -> Result<GuidedSettingsPlan, GuidedSettingsError> {
    if !capability.guided_settings_only {
        return Err(GuidedSettingsError::UnavailableForPackage);
    }
    let servers = profile_servers_for_family(profile, family);
    if servers.is_empty() {
        return Err(GuidedSettingsError::NoServersForSelectedFamily);
    }

    let (title, steps, safety_note) = match language {
        Language::English => (
            "Guided settings",
            vec![
                "Copy the DNS servers.",
                "Open the desktop network settings.",
                "Edit the active connection and paste the DNS servers.",
                "Save the connection, then reconnect if the desktop asks.",
                "Retest with current/system resolver validation when supported.",
            ],
            "This guide does not change DNS automatically.",
        ),
        Language::Vietnamese => (
            "Hướng dẫn cài đặt DNS",
            vec![
                "Sao chép DNS server.",
                "Mở cài đặt mạng của desktop.",
                "Sửa kết nối đang dùng và dán DNS server.",
                "Lưu kết nối, sau đó kết nối lại nếu desktop yêu cầu.",
                "Đo lại bằng xác thực resolver hệ thống khi được hỗ trợ.",
            ],
            "Không tự động đổi DNS hệ thống.",
        ),
    };

    Ok(GuidedSettingsPlan {
        package_kind: capability.package_kind,
        language,
        title,
        profile_id: profile.id.clone(),
        profile_name: profile.name.clone(),
        servers,
        steps,
        safety_note,
    })
}

pub fn render_guided_settings_plan(plan: &GuidedSettingsPlan) -> String {
    let mut lines = match plan.language {
        Language::English => vec![
            plan.title.to_string(),
            format!("Package: {}", plan.package_kind.label()),
            format!("Profile: {} ({})", plan.profile_name, plan.profile_id),
            plan.safety_note.to_string(),
            format!("Copy DNS servers: {}", plan.servers.join(", ")),
            "Steps:".to_string(),
        ],
        Language::Vietnamese => vec![
            plan.title.to_string(),
            format!("Gói: {}", plan.package_kind.label()),
            format!("Hồ sơ: {} ({})", plan.profile_name, plan.profile_id),
            plan.safety_note.to_string(),
            format!("Sao chép DNS server: {}", plan.servers.join(", ")),
            "Các bước:".to_string(),
        ],
    };
    lines.extend(
        plan.steps
            .iter()
            .enumerate()
            .map(|(index, step)| format!("{}. {step}", index + 1)),
    );
    lines.join("\n")
}

pub fn native_power_path_plan() -> NativePowerPathPlan {
    NativePowerPathPlan {
        title: "Native Linux DNS apply path",
        steps: vec![
            "Detect active connection and DNS ownership through NetworkManager D-Bus.",
            "Fallback to systemd-resolved for resolved-managed links and DNS state validation.",
            "Require polkit authorization before writing resolver settings.",
            "Flush/validate through supported resolver stack, then rerun current/system resolver validation.",
        ],
    }
}
