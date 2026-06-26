use crate::capabilities::LinuxCapabilityViewModel;

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
            label: "Apply with native helper",
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
