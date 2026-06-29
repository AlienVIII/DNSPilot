use crate::capabilities::{LinuxCapabilityViewModel, LinuxPackageKind};
use crate::profiles::PlainDnsProfile;
use crate::settings::ResolverAddressFamily;
use serde_json::Value;

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

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NativeMutationMode {
    DryRun,
    Execute,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NativeHelperApplyRequest {
    pub resolver_stack: NativeResolverStack,
    pub polkit_action_id: String,
    pub servers: Vec<String>,
    pub rollback_snapshot: bool,
    pub validate_after_apply: bool,
    pub mutation_mode: NativeMutationMode,
    pub confirm_system_dns_mutation: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NativeHelperRunResult {
    pub applied: bool,
    pub rolled_back: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum NativeHelperRunError {
    InvalidJson(String),
    UnsupportedSchema,
    InvalidPolkitAction,
    InvalidResolverStack,
    InvalidMutationMode,
    NoServers,
    RollbackSnapshotRequired,
    MutationNotConfirmed,
    SnapshotFailed(String),
    AuthorizationFailed(String),
    WriteFailed(String),
    FlushFailed(String),
    ValidationFailed(String),
    RollbackFailed(String),
}

pub trait NativeHelperExecutor {
    fn snapshot_existing_dns(
        &mut self,
        stack: NativeResolverStack,
    ) -> Result<(), NativeHelperRunError>;

    fn authorize(&mut self, action_id: &str) -> Result<(), NativeHelperRunError>;

    fn write_dns(
        &mut self,
        stack: NativeResolverStack,
        servers: &[String],
    ) -> Result<(), NativeHelperRunError>;

    fn flush_resolver_cache(
        &mut self,
        stack: NativeResolverStack,
    ) -> Result<(), NativeHelperRunError>;

    fn validate_current_resolver(
        &mut self,
        stack: NativeResolverStack,
    ) -> Result<(), NativeHelperRunError>;

    fn rollback_dns(&mut self, stack: NativeResolverStack) -> Result<(), NativeHelperRunError>;
}

pub fn parse_native_apply_request_json(
    json: &str,
) -> Result<NativeHelperApplyRequest, NativeHelperRunError> {
    let value = serde_json::from_str::<Value>(json)
        .map_err(|error| NativeHelperRunError::InvalidJson(error.to_string()))?;

    if value
        .get("schema_version")
        .and_then(Value::as_u64)
        .filter(|version| *version == 1)
        .is_none()
    {
        return Err(NativeHelperRunError::UnsupportedSchema);
    }

    let polkit_action_id = value
        .get("polkit_action_id")
        .and_then(Value::as_str)
        .ok_or(NativeHelperRunError::InvalidPolkitAction)?;
    if polkit_action_id != DNS_APPLY_POLKIT_ACTION_ID {
        return Err(NativeHelperRunError::InvalidPolkitAction);
    }

    let resolver_stack = value
        .get("resolver_stack")
        .and_then(Value::as_str)
        .and_then(parse_native_stack)
        .ok_or(NativeHelperRunError::InvalidResolverStack)?;

    let servers = value
        .get("servers")
        .and_then(Value::as_array)
        .ok_or(NativeHelperRunError::NoServers)?
        .iter()
        .filter_map(Value::as_str)
        .map(ToString::to_string)
        .collect::<Vec<_>>();
    if servers.is_empty() {
        return Err(NativeHelperRunError::NoServers);
    }

    let rollback_snapshot = value
        .get("rollback_snapshot")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    if !rollback_snapshot {
        return Err(NativeHelperRunError::RollbackSnapshotRequired);
    }

    let mutation_mode = value
        .get("mutation_mode")
        .and_then(Value::as_str)
        .map(parse_mutation_mode)
        .transpose()?
        .unwrap_or(NativeMutationMode::DryRun);
    let confirm_system_dns_mutation = value
        .get("confirm_system_dns_mutation")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    if mutation_mode == NativeMutationMode::Execute && !confirm_system_dns_mutation {
        return Err(NativeHelperRunError::MutationNotConfirmed);
    }

    Ok(NativeHelperApplyRequest {
        resolver_stack,
        polkit_action_id: polkit_action_id.to_string(),
        servers,
        rollback_snapshot,
        validate_after_apply: value
            .get("validate_after_apply")
            .and_then(Value::as_bool)
            .unwrap_or(false),
        mutation_mode,
        confirm_system_dns_mutation,
    })
}

pub fn execute_native_apply_request(
    request: &NativeHelperApplyRequest,
    executor: &mut impl NativeHelperExecutor,
) -> Result<NativeHelperRunResult, NativeHelperRunError> {
    if request.mutation_mode != NativeMutationMode::Execute || !request.confirm_system_dns_mutation
    {
        return Err(NativeHelperRunError::MutationNotConfirmed);
    }

    executor.snapshot_existing_dns(request.resolver_stack)?;
    executor.authorize(&request.polkit_action_id)?;

    if let Err(error) = executor.write_dns(request.resolver_stack, &request.servers) {
        rollback_after_failure(request, executor)?;
        return Err(error);
    }

    if let Err(error) = executor.flush_resolver_cache(request.resolver_stack) {
        rollback_after_failure(request, executor)?;
        return Err(error);
    }

    if request.validate_after_apply {
        if let Err(error) = executor.validate_current_resolver(request.resolver_stack) {
            rollback_after_failure(request, executor)?;
            return Err(error);
        }
    }

    Ok(NativeHelperRunResult {
        applied: true,
        rolled_back: false,
    })
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

fn parse_native_stack(value: &str) -> Option<NativeResolverStack> {
    match value {
        "networkmanager" | "network-manager" | "nm" => Some(NativeResolverStack::NetworkManager),
        "systemd-resolved" | "resolved" => Some(NativeResolverStack::SystemdResolved),
        _ => None,
    }
}

fn parse_mutation_mode(value: &str) -> Result<NativeMutationMode, NativeHelperRunError> {
    match value {
        "dry-run" | "dry_run" | "preview" => Ok(NativeMutationMode::DryRun),
        "execute" => Ok(NativeMutationMode::Execute),
        _ => Err(NativeHelperRunError::InvalidMutationMode),
    }
}

fn rollback_after_failure(
    request: &NativeHelperApplyRequest,
    executor: &mut impl NativeHelperExecutor,
) -> Result<(), NativeHelperRunError> {
    executor.rollback_dns(request.resolver_stack)
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
