use crate::capabilities::{LinuxCapabilityViewModel, LinuxPackageKind};
use crate::profiles::PlainDnsProfile;
use crate::settings::ResolverAddressFamily;

pub const DNS_APPLY_POLKIT_ACTION_ID: &str = "io.dnspilot.DNSPilot.apply-dns";

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NativeResolverStack {
    NetworkManager,
    SystemdResolved,
}

impl NativeResolverStack {
    pub fn label(self) -> &'static str {
        match self {
            Self::NetworkManager => "NetworkManager D-Bus",
            Self::SystemdResolved => "systemd-resolved D-Bus",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NativeApplyStepKind {
    DetectActiveConnection,
    SnapshotExistingDns,
    AuthorizeWithPolkit,
    WriteNetworkManagerDns,
    WriteSystemdResolvedDns,
    FlushResolverCache,
    ValidateCurrentResolver,
    RollbackOnFailure,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NativeApplyStep {
    pub kind: NativeApplyStepKind,
    pub label: &'static str,
    pub detail: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NativeDnsApplyPlan {
    pub package_kind: LinuxPackageKind,
    pub resolver_stack: NativeResolverStack,
    pub polkit_action_id: &'static str,
    pub profile_id: String,
    pub profile_name: String,
    pub servers: Vec<String>,
    pub requires_rollback_snapshot: bool,
    pub post_apply_validation: bool,
    pub steps: Vec<NativeApplyStep>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum NativeApplyError {
    UnsupportedPackage,
    MissingNativePowerCapability,
    NoServersForSelectedFamily,
}

pub fn build_native_apply_plan(
    capability: &LinuxCapabilityViewModel,
    profile: &PlainDnsProfile,
    address_family: ResolverAddressFamily,
) -> Result<NativeDnsApplyPlan, NativeApplyError> {
    if matches!(
        capability.package_kind,
        LinuxPackageKind::Flatpak | LinuxPackageKind::Snap
    ) {
        return Err(NativeApplyError::UnsupportedPackage);
    }

    if !capability.can_apply_real_dns
        || !capability.polkit_available
        || !(capability.network_manager_available || capability.systemd_resolved_available)
    {
        return Err(NativeApplyError::MissingNativePowerCapability);
    }

    let servers = selected_servers(profile, address_family);
    if servers.is_empty() {
        return Err(NativeApplyError::NoServersForSelectedFamily);
    }

    let resolver_stack = if capability.network_manager_available {
        NativeResolverStack::NetworkManager
    } else {
        NativeResolverStack::SystemdResolved
    };
    let post_apply_validation = capability.can_validate_current_system_resolver;

    Ok(NativeDnsApplyPlan {
        package_kind: capability.package_kind,
        resolver_stack,
        polkit_action_id: DNS_APPLY_POLKIT_ACTION_ID,
        profile_id: profile.id.clone(),
        profile_name: profile.name.clone(),
        servers,
        requires_rollback_snapshot: true,
        post_apply_validation,
        steps: steps_for_stack(resolver_stack, post_apply_validation),
    })
}

pub fn render_native_apply_plan(plan: &NativeDnsApplyPlan) -> String {
    let mut lines = vec![
        "Native DNS apply plan".to_string(),
        format!("Package: {}", plan.package_kind.label()),
        format!("Resolver stack: {}", plan.resolver_stack.label()),
        format!("Polkit action: {}", plan.polkit_action_id),
        format!("Profile: {} ({})", plan.profile_name, plan.profile_id),
        format!("Servers: {}", plan.servers.join(", ")),
        format!(
            "Rollback snapshot: {}",
            yes_no(plan.requires_rollback_snapshot)
        ),
        format!(
            "Post-apply validation: {}",
            yes_no(plan.post_apply_validation)
        ),
        "Steps:".to_string(),
    ];

    for (index, step) in plan.steps.iter().enumerate() {
        lines.push(format!("{}. {} - {}", index + 1, step.label, step.detail));
    }

    lines.join("\n")
}

fn selected_servers(
    profile: &PlainDnsProfile,
    address_family: ResolverAddressFamily,
) -> Vec<String> {
    match address_family {
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

fn steps_for_stack(
    resolver_stack: NativeResolverStack,
    post_apply_validation: bool,
) -> Vec<NativeApplyStep> {
    let mut steps = vec![
        step(
            NativeApplyStepKind::DetectActiveConnection,
            "Detect active connection",
            format!("Resolve DNS ownership through {}.", resolver_stack.label()),
        ),
        step(
            NativeApplyStepKind::SnapshotExistingDns,
            "Snapshot current DNS",
            "Store enough resolver state to support rollback.".to_string(),
        ),
        step(
            NativeApplyStepKind::AuthorizeWithPolkit,
            "Authorize with polkit",
            format!("Request action {DNS_APPLY_POLKIT_ACTION_ID}."),
        ),
    ];

    match resolver_stack {
        NativeResolverStack::NetworkManager => steps.push(step(
            NativeApplyStepKind::WriteNetworkManagerDns,
            "Write NetworkManager DNS",
            "Set DNS on the active NetworkManager connection over D-Bus.".to_string(),
        )),
        NativeResolverStack::SystemdResolved => steps.push(step(
            NativeApplyStepKind::WriteSystemdResolvedDns,
            "Write systemd-resolved DNS",
            "Set DNS for the resolved-managed link over D-Bus.".to_string(),
        )),
    }

    steps.push(step(
        NativeApplyStepKind::FlushResolverCache,
        "Flush resolver cache",
        "Flush or refresh resolver state after the write.".to_string(),
    ));
    if post_apply_validation {
        steps.push(step(
            NativeApplyStepKind::ValidateCurrentResolver,
            "Validate current resolver",
            "Rerun current/system resolver validation after apply.".to_string(),
        ));
    }
    steps.push(step(
        NativeApplyStepKind::RollbackOnFailure,
        "Rollback on failure",
        "Restore the DNS snapshot if write or validation fails.".to_string(),
    ));
    steps
}

fn step(kind: NativeApplyStepKind, label: &'static str, detail: String) -> NativeApplyStep {
    NativeApplyStep {
        kind,
        label,
        detail,
    }
}

fn yes_no(value: bool) -> &'static str {
    if value {
        "yes"
    } else {
        "no"
    }
}
