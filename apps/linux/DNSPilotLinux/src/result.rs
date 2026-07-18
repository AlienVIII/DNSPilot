use crate::capabilities::LinuxCapabilityViewModel;
use serde_json::Value;

#[derive(Debug, Clone, PartialEq)]
pub struct ResolverResult {
    pub profile_id: String,
    pub median_dns_latency_ms: f64,
    pub median_connect_latency_ms: f64,
    pub failure_rate: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PrimaryResultAction {
    ApplyGuidance,
    RetestSystemDns,
    None,
}

#[derive(Debug, Clone, PartialEq)]
pub struct BenchmarkDecision {
    pub recommended_profile_id: Option<String>,
    pub fastest_observed_profile_id: Option<String>,
    pub can_recommend: bool,
    pub health: String,
    pub gate_reasons: Vec<String>,
    pub warning: String,
    pub primary_action: PrimaryResultAction,
    pub resolvers: Vec<ResolverResult>,
}

pub fn decode_benchmark_decision(
    payload: &str,
    capability: &LinuxCapabilityViewModel,
) -> Result<BenchmarkDecision, String> {
    let value: Value = serde_json::from_str(payload).map_err(|error| error.to_string())?;
    let summary = value
        .get("summary")
        .ok_or_else(|| "missing benchmark summary".to_string())?;
    let resolvers = value
        .get("runs")
        .and_then(Value::as_array)
        .map(|runs| runs.iter().filter_map(parse_resolver).collect::<Vec<_>>())
        .unwrap_or_default();
    let recommended_profile_id = optional_string(summary, "recommended_profile_id");
    let can_recommend = summary
        .get("can_recommend")
        .and_then(Value::as_bool)
        .ok_or_else(|| "missing benchmark can_recommend".to_string())?;
    let gate_reasons = summary
        .get("safety_notes")
        .and_then(Value::as_array)
        .map(|values| string_array(values))
        .unwrap_or_default();
    let fastest_observed_profile_id = resolvers
        .iter()
        .filter(|resolver| resolver.median_dns_latency_ms.is_finite())
        .min_by(|left, right| {
            left.median_dns_latency_ms
                .total_cmp(&right.median_dns_latency_ms)
        })
        .map(|resolver| resolver.profile_id.clone());
    let primary_action =
        if can_recommend && recommended_profile_id.is_some() && capability.guided_settings_only {
            PrimaryResultAction::ApplyGuidance
        } else if capability.can_validate_current_system_resolver {
            PrimaryResultAction::RetestSystemDns
        } else {
            PrimaryResultAction::None
        };

    Ok(BenchmarkDecision {
        recommended_profile_id,
        fastest_observed_profile_id,
        can_recommend,
        health: summary
            .get("health")
            .and_then(Value::as_str)
            .unwrap_or("unknown")
            .to_string(),
        gate_reasons,
        warning: value
            .get("warning")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_string(),
        primary_action,
        resolvers,
    })
}

fn parse_resolver(value: &Value) -> Option<ResolverResult> {
    let metrics = value.get("metrics")?;
    Some(ResolverResult {
        profile_id: value.get("profile_id")?.as_str()?.to_string(),
        median_dns_latency_ms: metrics.get("median_dns_latency_ms")?.as_f64()?,
        median_connect_latency_ms: metrics
            .get("median_connect_latency_ms")
            .and_then(Value::as_f64)
            .unwrap_or(f64::INFINITY),
        failure_rate: metrics
            .get("failure_rate")
            .and_then(Value::as_f64)
            .unwrap_or(1.0),
    })
}

fn optional_string(value: &Value, key: &str) -> Option<String> {
    value
        .get(key)
        .and_then(Value::as_str)
        .map(ToString::to_string)
}

fn string_array(values: &[Value]) -> Vec<String> {
    values
        .iter()
        .filter_map(Value::as_str)
        .map(ToString::to_string)
        .collect()
}
