use dnspilot_core::{
    apply_plan_payload_for, apply_prompt_policy_payload_for, benchmark_preflight_payload_for,
    built_in_profiles, built_in_test_suites, capability_for, capability_matrix_payload,
    catalog_payload,
    connect_probe::{ConnectProbeOutcome, ConnectProbeSample, TcpConnectTarget},
    connection_path::{run_udp_connection_path_estimate, ConnectionPathConfig, ConnectionPathRun},
    dns_benchmark::{
        run_udp_dns_benchmark, DnsBenchmarkConfig, DnsBenchmarkSample, DnsRecordFamily,
        DnsSampleOutcome,
    },
    dns_wire::{validate_domain_name, RecordType},
    recommend, recommendation_gate,
    system_dns::run_system_dns_benchmark,
    tls_probe::{TlsProbeOutcome, TlsProbeSample},
    BenchmarkHistoryRecord, BenchmarkMetrics, BenchmarkPreflightScope, Confidence, DnsProfile,
    DnsProtocol, FilteringType, MeasurementScope, NetworkEnvironment, Platform, Recommendation,
    RecommendationDecision, RecommendationGate, RecommendationHealth, RecommendationIssue,
    RecommendationMode, SqliteStorage, StorageSnapshot, TestSuite, STORAGE_SCHEMA_VERSION,
};
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::BTreeMap;
use std::ffi::{CStr, CString};
use std::net::{IpAddr, SocketAddr};
use std::os::raw::c_char;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

pub fn run_action_json(action: &str, payload_json: &str, db_path: Option<&str>) -> String {
    let result =
        parse_payload(payload_json).and_then(|payload| run_action(action, &payload, db_path));
    match result {
        Ok(data) => {
            let progress = data
                .get("progress")
                .cloned()
                .unwrap_or_else(|| Value::Array(Vec::new()));
            json!({
                "ok": true,
                "action": action,
                "args": ["native", action],
                "data": data,
                "progress": progress,
            })
            .to_string()
        }
        Err(error) => json!({
            "ok": false,
            "action": action,
            "error": error.to_string(),
        })
        .to_string(),
    }
}

/// Runs a mobile action through the stable C ABI.
///
/// # Safety
/// `action` and `payload_json` must point to valid null-terminated UTF-8 strings.
/// `db_path` may be null or point to a valid null-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C" fn dnspilot_run_action(
    action: *const c_char,
    payload_json: *const c_char,
    db_path: *const c_char,
) -> *mut c_char {
    let output = catch_unwind(AssertUnwindSafe(|| {
        let action = unsafe { required_c_string(action, "action") }?;
        let payload_json = unsafe { required_c_string(payload_json, "payload_json") }?;
        let db_path = unsafe { optional_c_string(db_path) }?;
        Ok::<_, RuntimeError>(run_action_json(&action, &payload_json, db_path.as_deref()))
    }))
    .unwrap_or_else(|_| Ok(panic_response()))
    .unwrap_or_else(|error| error_response("native", error));

    CString::new(output)
        .unwrap_or_else(|_| {
            CString::new(error_response("native", RuntimeError::InteriorNul)).unwrap()
        })
        .into_raw()
}

/// Releases a string returned by [`dnspilot_run_action`].
///
/// # Safety
/// `value` must be null or a pointer returned by [`dnspilot_run_action`] that
/// has not already been released.
#[no_mangle]
pub unsafe extern "C" fn dnspilot_free_string(value: *mut c_char) {
    if !value.is_null() {
        drop(unsafe { CString::from_raw(value) });
    }
}

fn run_action(action: &str, payload: &Value, db_path: Option<&str>) -> Result<Value, RuntimeError> {
    match action {
        "catalog" => value(catalog_payload()),
        "capabilities" => value(capability_matrix_payload()),
        "capability" => value(capability_for(platform(payload)?)),
        "preflight" => value(benchmark_preflight_payload_for(
            platform(payload)?,
            enum_field(payload, "scope", "direct-resolver-benchmark")?,
        )),
        "applyPolicy" => value(apply_prompt_policy_payload_for(
            platform(payload)?,
            &network_environment(payload)?,
        )),
        "applyPlan" => apply_plan(payload, db_path),
        "recommendSample" => recommend_sample(),
        "benchmark" => benchmark(payload, db_path),
        "compare" => compare(payload, db_path),
        "systemBenchmark" => system_benchmark(payload, db_path),
        "pathEstimate" => path_estimate(payload, db_path),
        "pathCompare" => path_compare(payload, db_path),
        "storageSmoke" => storage_smoke(storage(payload, db_path)?),
        "profileList" => profile_list(storage(payload, db_path)?),
        "profileAdd" => profile_add(storage(payload, db_path)?, payload),
        "profileUpdate" => profile_update(storage(payload, db_path)?, payload),
        "profileDelete" => profile_delete(storage(payload, db_path)?, payload),
        "suiteList" => suite_list(storage(payload, db_path)?),
        "suiteAdd" => suite_add(storage(payload, db_path)?, payload),
        "suiteUpdate" => suite_update(storage(payload, db_path)?, payload),
        "suiteDelete" => suite_delete(storage(payload, db_path)?, payload),
        "historyList" => history_list(storage(payload, db_path)?),
        "historyDelete" => history_delete(storage(payload, db_path)?, payload),
        "historyClear" => history_clear(storage(payload, db_path)?),
        _ => Err(RuntimeError::UnsupportedAction(action.to_owned())),
    }
}

fn apply_plan(payload: &Value, db_path: Option<&str>) -> Result<Value, RuntimeError> {
    let profiles = apply_plan_profiles(payload, db_path)?;
    let profile_id = optional_string(payload, "profileId");
    let confidence: Confidence = enum_field(payload, "confidence", "high")?;
    let gate_health: RecommendationHealth = enum_field(payload, "gateHealth", "healthy")?;
    let recommendation = profile_id.as_ref().map(|profile_id| Recommendation {
        decision: RecommendationDecision::ApplyProfile(profile_id.clone()),
        profile_id: profile_id.clone(),
        score: 1.0,
        confidence,
        reasons: vec!["Mobile apply-plan recommendation input.".into()],
        caveats: Vec::new(),
    });
    value(apply_plan_payload_for(
        platform(payload)?,
        &network_environment(payload)?,
        &apply_plan_gate(gate_health),
        recommendation.as_ref(),
        optional_string(payload, "testedResolver").as_deref(),
        &profiles,
    ))
}

fn apply_plan_profiles(
    payload: &Value,
    db_path: Option<&str>,
) -> Result<Vec<DnsProfile>, RuntimeError> {
    let path = db_path.or_else(|| payload.get("dbPath").and_then(Value::as_str));
    let Some(path) = path else {
        return Ok(built_in_profiles());
    };
    Ok(load_snapshot_or_builtin(&storage_for_path(path)?)?.profiles)
}

fn apply_plan_gate(health: RecommendationHealth) -> RecommendationGate {
    let can_recommend = matches!(
        health,
        RecommendationHealth::Healthy | RecommendationHealth::Degraded
    );
    let primary_issue = match health {
        RecommendationHealth::Healthy => RecommendationIssue::None,
        RecommendationHealth::Degraded => RecommendationIssue::PartialFailure,
        RecommendationHealth::Failed => RecommendationIssue::AllResolversFailed,
        RecommendationHealth::Inconclusive => RecommendationIssue::NoResolvers,
    };
    let notes = match health {
        RecommendationHealth::Healthy => Vec::new(),
        RecommendationHealth::Degraded => {
            vec!["At least one candidate had partial failure or timeout.".into()]
        }
        RecommendationHealth::Failed => vec!["Every candidate failed the measured scope.".into()],
        RecommendationHealth::Inconclusive => vec!["Benchmark result was inconclusive.".into()],
    };
    RecommendationGate {
        can_recommend,
        health,
        primary_issue,
        notes,
    }
}

fn recommend_sample() -> Result<Value, RuntimeError> {
    let current = BenchmarkMetrics {
        profile_id: "current".into(),
        median_dns_latency_ms: 50.0,
        p95_dns_latency_ms: 140.0,
        failure_rate: 0.02,
        timeout_rate: 0.01,
        median_connect_latency_ms: 170.0,
        ipv4_health: 1.0,
        ipv6_health: 0.7,
        priority_fit: 1.0,
    };
    let quad9 = BenchmarkMetrics {
        profile_id: "quad9".into(),
        median_dns_latency_ms: 18.0,
        p95_dns_latency_ms: 42.0,
        failure_rate: 0.0,
        timeout_rate: 0.0,
        median_connect_latency_ms: 75.0,
        ipv4_health: 1.0,
        ipv6_health: 0.95,
        priority_fit: 1.0,
    };
    let recommendation = recommend(
        &[current.clone(), quad9],
        Some(&current),
        RecommendationMode::BestOverall,
    )
    .map_err(|error| RuntimeError::Core(error.to_string()))?;
    value(recommendation)
}

fn benchmark(payload: &Value, db_path: Option<&str>) -> Result<Value, RuntimeError> {
    let snapshot = benchmark_snapshot(payload, db_path)?;
    let profile_id = optional_string(payload, "profileId").unwrap_or_else(|| "cloudflare".into());
    let resolver =
        resolve_plain_resolver(&snapshot.profiles, &profile_id, resolver_port(payload)?)?;
    let domains = resolve_domains(payload, &snapshot)?;
    let attempts = positive_usize(payload, "attempts", 1)?;
    let timeout_ms = positive_u64(payload, "timeoutMs", 800)?;
    let run = run_udp_dns_benchmark(
        &DnsBenchmarkConfig {
            profile_id: profile_id.clone(),
            domains: domains.clone(),
            attempts_per_record: attempts,
            timeout: Duration::from_millis(timeout_ms),
            first_transaction_id: 0x5000,
            record_family: record_family(payload)?,
        },
        resolver,
    );
    let gate = recommendation_gate(
        std::slice::from_ref(&run.metrics),
        MeasurementScope::DnsOnly,
    );
    let saved_history_id = save_history(
        payload,
        db_path,
        BenchmarkHistoryRecord {
            id: history_id("benchmark"),
            started_at: timestamp_id("started"),
            scope: MeasurementScope::DnsOnly,
            mode: RecommendationMode::FastestRawDns,
            domains,
            resolver_profile_ids: vec![profile_id],
            metrics: vec![run.metrics.clone()],
            recommendation_profile_id: gate.can_recommend.then(|| run.metrics.profile_id.clone()),
            gate,
            notes: vec!["Saved by DNSPilot Mobile native benchmark.".into()],
        },
    )?;
    Ok(json!({
        "metrics": run.metrics,
        "samples": run.samples.iter().map(dns_sample_json).collect::<Vec<_>>(),
        "ip_family": record_family_name(payload)?,
        "saved_history_id": saved_history_id,
        "warning": "Live DNS results estimate resolver behavior on this network; they do not prove full browser or app speed.",
    }))
}

fn compare(payload: &Value, db_path: Option<&str>) -> Result<Value, RuntimeError> {
    let snapshot = benchmark_snapshot(payload, db_path)?;
    let profile_ids = profile_ids(payload)?;
    let domains = resolve_domains(payload, &snapshot)?;
    let attempts = positive_usize(payload, "attempts", 1)?;
    let timeout_ms = positive_u64(payload, "timeoutMs", 800)?;
    let record_family = record_family(payload)?;
    let resolver_port = resolver_port(payload)?;
    let resolver_count = profile_ids.len();
    let mut metrics = Vec::with_capacity(resolver_count);
    let mut runs = Vec::with_capacity(resolver_count);
    let mut progress = Vec::with_capacity(resolver_count * 2);

    for (index, profile_id) in profile_ids.iter().enumerate() {
        let resolver = resolve_plain_resolver(&snapshot.profiles, profile_id, resolver_port)?;
        progress.push(progress_event(ProgressEvent {
            event_type: "resolver_started",
            scope: MeasurementScope::DnsOnly,
            profile_id,
            resolver,
            index: index + 1,
            total: resolver_count,
            metrics: None,
            elapsed: None,
        }));
        let started = Instant::now();
        let run = run_udp_dns_benchmark(
            &DnsBenchmarkConfig {
                profile_id: profile_id.clone(),
                domains: domains.clone(),
                attempts_per_record: attempts,
                timeout: Duration::from_millis(timeout_ms),
                first_transaction_id: 0x9000_u16.wrapping_add((index as u16).wrapping_mul(0x0100)),
                record_family,
            },
            resolver,
        );
        progress.push(progress_event(ProgressEvent {
            event_type: "resolver_finished",
            scope: MeasurementScope::DnsOnly,
            profile_id,
            resolver,
            index: index + 1,
            total: resolver_count,
            metrics: Some(&run.metrics),
            elapsed: Some(started.elapsed()),
        }));
        metrics.push(run.metrics.clone());
        runs.push(json!({
            "profile_id": profile_id,
            "resolver": resolver.to_string(),
            "metrics": run.metrics,
            "samples": run.samples.iter().map(dns_sample_json).collect::<Vec<_>>(),
        }));
    }

    let gate = recommendation_gate(&metrics, MeasurementScope::DnsOnly);
    let recommendation = gate
        .can_recommend
        .then(|| recommend(&metrics, None, RecommendationMode::FastestRawDns))
        .transpose()
        .map_err(|error| RuntimeError::Core(error.to_string()))?;
    let saved_history_id = save_history(
        payload,
        db_path,
        BenchmarkHistoryRecord {
            id: history_id("compare"),
            started_at: timestamp_id("started"),
            scope: MeasurementScope::DnsOnly,
            mode: RecommendationMode::FastestRawDns,
            domains: domains.clone(),
            resolver_profile_ids: profile_ids,
            metrics,
            recommendation_profile_id: recommendation.as_ref().map(|item| item.profile_id.clone()),
            gate: gate.clone(),
            notes: vec!["Saved by DNSPilot Mobile native comparison.".into()],
        },
    )?;
    Ok(json!({
        "summary": {
            "measurement_scope": "dns-only",
            "mode": "fastest-raw-dns",
            "health": gate.health,
            "primary_issue": gate.primary_issue,
            "can_recommend": gate.can_recommend,
            "safety_notes": gate.notes,
            "resolver_count": resolver_count,
            "domain_count": domains.len(),
            "attempts_per_record": attempts,
            "ip_family": record_family_name(payload)?,
            "timeout_ms": timeout_ms,
            "recommended_profile_id": recommendation.as_ref().map(|item| item.profile_id.clone()),
        },
        "runs": runs,
        "recommendation": recommendation,
        "saved_history_id": saved_history_id,
        "progress": progress,
        "warning": "DNS-only comparison estimates resolver lookup latency and reliability; it does not include TCP, TLS, HTTP, QUIC, browser cache, VPN, MDM, captive portal, or app-specific behavior.",
    }))
}

fn system_benchmark(payload: &Value, db_path: Option<&str>) -> Result<Value, RuntimeError> {
    let snapshot = benchmark_snapshot(payload, db_path)?;
    let domains = resolve_domains(payload, &snapshot)?;
    let attempts = positive_usize(payload, "attempts", 1)?;
    let timeout_ms = positive_u64(payload, "timeoutMs", 800)?;
    let run = run_system_dns_benchmark(&DnsBenchmarkConfig {
        profile_id: "system-dns".into(),
        domains: domains.clone(),
        attempts_per_record: attempts,
        timeout: Duration::from_millis(timeout_ms),
        first_transaction_id: 0x6000,
        record_family: record_family(payload)?,
    });
    let gate = recommendation_gate(
        std::slice::from_ref(&run.metrics),
        MeasurementScope::DnsOnly,
    );
    let mut safety_notes = benchmark_preflight_payload_for(
        platform(payload)?,
        BenchmarkPreflightScope::SystemDnsValidation,
    )
    .preflight
    .notes;
    for note in gate.notes.iter().chain(std::iter::once(
        &"System DNS validation does not produce a resolver recommendation.".into(),
    )) {
        if !safety_notes.contains(note) {
            safety_notes.push(note.clone());
        }
    }
    Ok(json!({
        "scope": "system-dns-validation",
        "summary": {
            "measurement_scope": "dns-only",
            "mode": "fastest-raw-dns",
            "health": gate.health,
            "primary_issue": gate.primary_issue,
            "can_recommend": false,
            "safety_notes": safety_notes,
            "resolver_count": 1,
            "domain_count": domains.len(),
            "attempts_per_record": attempts,
            "timeout_ms": timeout_ms,
            "ip_family": record_family_name(payload)?,
            "recommended_profile_id": Value::Null,
        },
        "runs": [{
            "profile_id": "system-dns",
            "resolver": "system resolver",
            "metrics": run.metrics,
            "caveats": safety_notes,
        }],
        "recommendation": Value::Null,
        "preflight": benchmark_preflight_payload_for(platform(payload)?, BenchmarkPreflightScope::SystemDnsValidation).preflight,
        "samples": run.samples.iter().map(dns_sample_json).collect::<Vec<_>>(),
        "ip_family": record_family_name(payload)?,
        "warning": "System DNS validation measures the OS resolver path after DNS changes; flush cache first, and still expect browser Secure DNS, VPN, MDM, captive portal, and app caches to distort results.",
    }))
}

fn path_estimate(payload: &Value, db_path: Option<&str>) -> Result<Value, RuntimeError> {
    let snapshot = benchmark_snapshot(payload, db_path)?;
    let profile_id = optional_string(payload, "profileId").unwrap_or_else(|| "cloudflare".into());
    let resolver =
        resolve_plain_resolver(&snapshot.profiles, &profile_id, resolver_port(payload)?)?;
    let domains = resolve_domains(payload, &snapshot)?;
    let run = run_path(payload, profile_id, domains, 0x7000, resolver)?;
    let tls_enabled = optional_positive_u64(payload, "tlsHandshakeTimeoutMs")?.is_some();
    Ok(json!({
        "summary": path_summary(&run, tls_enabled, Some(payload))?,
        "metrics": run.metrics,
        "dns_samples": run.dns.samples.iter().map(dns_sample_json).collect::<Vec<_>>(),
        "connect_samples": run.connect.samples.iter().map(connect_sample_json).collect::<Vec<_>>(),
        "tls_samples": tls_samples_json(&run),
        "connect_targets": run.connect_targets.iter().map(connect_target_json).collect::<Vec<_>>(),
        "caveats": run.caveats,
        "warning": path_warning(tls_enabled),
    }))
}

fn path_compare(payload: &Value, db_path: Option<&str>) -> Result<Value, RuntimeError> {
    let snapshot = benchmark_snapshot(payload, db_path)?;
    let profile_ids = profile_ids(payload)?;
    let domains = resolve_domains(payload, &snapshot)?;
    let resolver_port = resolver_port(payload)?;
    let resolver_count = profile_ids.len();
    let tls_enabled = optional_positive_u64(payload, "tlsHandshakeTimeoutMs")?.is_some();
    let scope = if tls_enabled {
        MeasurementScope::DnsTcpTls
    } else {
        MeasurementScope::DnsTcp
    };
    let mut metrics = Vec::with_capacity(resolver_count);
    let mut runs = Vec::with_capacity(resolver_count);
    let mut progress = Vec::with_capacity(resolver_count * 2);

    for (index, profile_id) in profile_ids.iter().enumerate() {
        let resolver = resolve_plain_resolver(&snapshot.profiles, profile_id, resolver_port)?;
        progress.push(progress_event(ProgressEvent {
            event_type: "resolver_started",
            scope,
            profile_id,
            resolver,
            index: index + 1,
            total: resolver_count,
            metrics: None,
            elapsed: None,
        }));
        let started = Instant::now();
        let run = run_path(
            payload,
            profile_id.clone(),
            domains.clone(),
            0xa000_u16.wrapping_add((index as u16).wrapping_mul(0x0100)),
            resolver,
        )?;
        progress.push(progress_event(ProgressEvent {
            event_type: "resolver_finished",
            scope,
            profile_id,
            resolver,
            index: index + 1,
            total: resolver_count,
            metrics: Some(&run.metrics),
            elapsed: Some(started.elapsed()),
        }));
        metrics.push(run.metrics.clone());
        runs.push(json!({
            "profile_id": profile_id,
            "resolver": resolver.to_string(),
            "summary": path_summary(&run, tls_enabled, None::<&Value>)?,
            "metrics": run.metrics,
            "dns_samples": run.dns.samples.iter().map(dns_sample_json).collect::<Vec<_>>(),
            "connect_samples": run.connect.samples.iter().map(connect_sample_json).collect::<Vec<_>>(),
            "tls_samples": tls_samples_json(&run),
            "connect_targets": run.connect_targets.iter().map(connect_target_json).collect::<Vec<_>>(),
            "caveats": run.caveats,
        }));
    }

    let gate = recommendation_gate(&metrics, scope);
    let recommendation = gate
        .can_recommend
        .then(|| recommend(&metrics, None, RecommendationMode::BestOverall))
        .transpose()
        .map_err(|error| RuntimeError::Core(error.to_string()))?;
    let saved_history_id = save_history(
        payload,
        db_path,
        BenchmarkHistoryRecord {
            id: history_id("path-compare"),
            started_at: timestamp_id("started"),
            scope,
            mode: RecommendationMode::BestOverall,
            domains: domains.clone(),
            resolver_profile_ids: profile_ids,
            metrics,
            recommendation_profile_id: recommendation.as_ref().map(|item| item.profile_id.clone()),
            gate: gate.clone(),
            notes: vec!["Saved by DNSPilot Mobile native connection-path comparison.".into()],
        },
    )?;
    Ok(json!({
        "summary": {
            "measurement_scope": measurement_scope_name(scope),
            "mode": "best-overall",
            "health": gate.health,
            "primary_issue": gate.primary_issue,
            "can_recommend": gate.can_recommend,
            "safety_notes": gate.notes,
            "tls_enabled": tls_enabled,
            "trust_store": if tls_enabled { Value::String("mozilla-webpki-roots".into()) } else { Value::Null },
            "resolver_count": resolver_count,
            "domain_count": domains.len(),
            "attempts_per_record": positive_usize(payload, "attempts", 1)?,
            "ip_family": record_family_name(payload)?,
            "dns_timeout_ms": positive_u64(payload, "dnsTimeoutMs", 800)?,
            "connect_timeout_ms": positive_u64(payload, "connectTimeoutMs", 1000)?,
            "tls_handshake_timeout_ms": optional_positive_u64(payload, "tlsHandshakeTimeoutMs")?,
            "connect_port": positive_u16(payload, "connectPort", 443)?,
            "max_connect_targets_per_domain": positive_usize(payload, "maxConnectTargetsPerDomain", 4)?,
            "recommended_profile_id": recommendation.as_ref().map(|item| item.profile_id.clone()),
        },
        "runs": runs,
        "recommendation": recommendation,
        "saved_history_id": saved_history_id,
        "progress": progress,
        "warning": path_compare_warning(tls_enabled),
    }))
}

fn run_path(
    payload: &Value,
    profile_id: String,
    domains: Vec<String>,
    first_transaction_id: u16,
    resolver: SocketAddr,
) -> Result<ConnectionPathRun, RuntimeError> {
    let dns_timeout_ms = positive_u64(payload, "dnsTimeoutMs", 800)?;
    let connect_timeout_ms = positive_u64(payload, "connectTimeoutMs", 1000)?;
    Ok(run_udp_connection_path_estimate(
        &ConnectionPathConfig {
            profile_id,
            domains,
            attempts_per_record: positive_usize(payload, "attempts", 1)?,
            dns_timeout: Duration::from_millis(dns_timeout_ms),
            connect_timeout: Duration::from_millis(connect_timeout_ms),
            first_transaction_id,
            connect_port: positive_u16(payload, "connectPort", 443)?,
            max_connect_targets_per_domain: positive_usize(
                payload,
                "maxConnectTargetsPerDomain",
                4,
            )?,
            tls_handshake_timeout: optional_positive_u64(payload, "tlsHandshakeTimeoutMs")?
                .map(Duration::from_millis),
            record_family: record_family(payload)?,
        },
        resolver,
    ))
}

fn path_summary(
    run: &ConnectionPathRun,
    tls_enabled: bool,
    payload: Option<&Value>,
) -> Result<Value, RuntimeError> {
    let (health, primary_issue) = path_health_summary(run);
    let mut summary = json!({
        "measurement_scope": if tls_enabled { "dns-tcp-tls" } else { "dns-tcp" },
        "health": health,
        "primary_issue": primary_issue,
        "tls_enabled": tls_enabled,
        "trust_store": if tls_enabled { Value::String("mozilla-webpki-roots".into()) } else { Value::Null },
        "domain_count": run.dns.samples.iter().map(|sample| &sample.domain).collect::<std::collections::BTreeSet<_>>().len(),
        "dns_sample_count": run.dns.samples.len(),
        "connect_target_count": run.connect_targets.len(),
        "connect_sample_count": run.connect.samples.len(),
        "tls_sample_count": run.tls.as_ref().map(|tls| tls.samples.len()).unwrap_or(0),
        "caveat_count": run.caveats.len(),
    });
    if let Some(payload) = payload {
        summary["ip_family"] = Value::String(record_family_name(payload)?.into());
    }
    Ok(summary)
}

fn path_health_summary(run: &ConnectionPathRun) -> (&'static str, &'static str) {
    if run.connect_targets.is_empty() {
        return ("inconclusive", "no-connect-targets");
    }
    if run.dns.metrics.failure_rate >= 1.0 {
        return ("failed", "dns-failure");
    }
    if run.connect.failure_rate >= 1.0 {
        return ("failed", "connect-failure");
    }
    if let Some(tls) = &run.tls {
        if tls.certificate_failure_rate > 0.0 {
            return ("failed", "tls-certificate-failure");
        }
        if tls.failure_rate >= 1.0 {
            return ("failed", "tls-handshake-failure");
        }
        if tls.failure_rate > 0.0 {
            return ("degraded", "tls-handshake-failure");
        }
    }
    if run.metrics.failure_rate > 0.0 || run.metrics.timeout_rate > 0.0 {
        return ("degraded", "partial-failure");
    }
    ("healthy", "none")
}

fn connect_sample_json(sample: &ConnectProbeSample) -> Value {
    json!({
        "domain": sample.domain,
        "endpoint": sample.endpoint.to_string(),
        "elapsed_ms": sample.elapsed.map(|elapsed| elapsed.as_secs_f64() * 1000.0),
        "outcome": match sample.outcome { ConnectProbeOutcome::Success => "success", ConnectProbeOutcome::Timeout => "timeout", ConnectProbeOutcome::Failure => "failure" },
    })
}

fn connect_target_json(target: &TcpConnectTarget) -> Value {
    json!({ "domain": target.domain, "endpoint": target.endpoint.to_string() })
}

fn tls_samples_json(run: &ConnectionPathRun) -> Vec<Value> {
    run.tls
        .as_ref()
        .map(|tls| tls.samples.iter().map(tls_sample_json).collect())
        .unwrap_or_default()
}

fn tls_sample_json(sample: &TlsProbeSample) -> Value {
    json!({
        "domain": sample.domain,
        "server_name": sample.server_name,
        "endpoint": sample.endpoint.to_string(),
        "elapsed_ms": sample.elapsed.map(|elapsed| elapsed.as_secs_f64() * 1000.0),
        "outcome": match sample.outcome {
            TlsProbeOutcome::Success => "success",
            TlsProbeOutcome::Timeout => "timeout",
            TlsProbeOutcome::CertificateFailure => "certificate-failure",
            TlsProbeOutcome::HandshakeFailure => "handshake-failure",
        },
    })
}

fn path_warning(tls_enabled: bool) -> &'static str {
    if tls_enabled {
        "Connection-path estimates use DNS, TCP connect, and TLS/SNI handshake timing only; they do not prove full browser, app, HTTP, or QUIC performance."
    } else {
        "Connection-path estimates use DNS plus TCP connect timing only; they do not prove full browser, app, TLS, HTTP, or QUIC performance."
    }
}

fn path_compare_warning(tls_enabled: bool) -> &'static str {
    if tls_enabled {
        "Path comparison estimates DNS, TCP connect, and TLS/SNI handshake timing only; it does not include HTTP, QUIC, browser cache, VPN, MDM, captive portal, or app-specific behavior."
    } else {
        "Path comparison estimates DNS plus TCP connect timing only; it does not include TLS, HTTP, QUIC, browser cache, VPN, MDM, captive portal, or app-specific behavior."
    }
}

fn benchmark_snapshot(
    payload: &Value,
    db_path: Option<&str>,
) -> Result<StorageSnapshot, RuntimeError> {
    let path = db_path.or_else(|| payload.get("dbPath").and_then(Value::as_str));
    match path {
        Some(path) => load_snapshot_or_builtin(&storage_for_path(path)?),
        None => Ok(builtin_snapshot()),
    }
}

fn resolve_domains(
    payload: &Value,
    snapshot: &StorageSnapshot,
) -> Result<Vec<String>, RuntimeError> {
    let mut domains = Vec::new();
    if let Some(suite_id) = optional_string(payload, "suiteId") {
        let suite = snapshot
            .test_suites
            .iter()
            .find(|suite| suite.id == suite_id)
            .ok_or_else(|| RuntimeError::NotFound(format!("test suite '{suite_id}' not found")))?;
        domains.extend(suite.domains.clone());
    }
    domains.extend(string_array(payload, "domains")?);
    if domains.is_empty() {
        return Err(RuntimeError::RequiredField("domains or suiteId".into()));
    }
    let mut unique = std::collections::BTreeSet::new();
    for domain in &domains {
        validate_domain_name(domain).map_err(|error| RuntimeError::InvalidDomain {
            domain: domain.clone(),
            reason: error.to_string(),
        })?;
        let normalized = domain.trim_end_matches('.').to_ascii_lowercase();
        if !unique.insert(normalized) {
            return Err(RuntimeError::Conflict(format!(
                "duplicate domain '{domain}'"
            )));
        }
    }
    Ok(domains)
}

fn profile_ids(payload: &Value) -> Result<Vec<String>, RuntimeError> {
    let ids = string_array(payload, "profileIds")?;
    let ids = if ids.is_empty() {
        optional_string(payload, "profileId").into_iter().collect()
    } else {
        ids
    };
    if ids.is_empty() {
        return Err(RuntimeError::RequiredField("profileIds".into()));
    }
    let mut unique = std::collections::BTreeSet::new();
    for id in &ids {
        if !unique.insert(id.clone()) {
            return Err(RuntimeError::Conflict(format!(
                "duplicate DNS profile '{id}'"
            )));
        }
    }
    Ok(ids)
}

fn resolve_plain_resolver(
    profiles: &[DnsProfile],
    profile_id: &str,
    port: u16,
) -> Result<SocketAddr, RuntimeError> {
    let profile = profiles
        .iter()
        .find(|profile| profile.id == profile_id)
        .ok_or_else(|| RuntimeError::NotFound(format!("DNS profile '{profile_id}' not found")))?;
    if profile.protocol != DnsProtocol::Plain {
        return Err(RuntimeError::UnsupportedResolverProtocol(profile_id.into()));
    }
    let server = profile
        .ipv4_servers
        .iter()
        .chain(profile.ipv6_servers.iter())
        .next()
        .ok_or_else(|| RuntimeError::ResolverAddressMissing(profile_id.into()))?;
    let ip = server
        .parse::<IpAddr>()
        .map_err(|error| RuntimeError::InvalidResolverAddress {
            server: server.clone(),
            reason: error.to_string(),
        })?;
    Ok(SocketAddr::new(ip, port))
}

fn record_family(payload: &Value) -> Result<DnsRecordFamily, RuntimeError> {
    match payload
        .get("ipFamily")
        .and_then(Value::as_str)
        .unwrap_or("both")
    {
        "both" => Ok(DnsRecordFamily::Both),
        "ipv4-only" => Ok(DnsRecordFamily::Ipv4Only),
        "ipv6-only" => Ok(DnsRecordFamily::Ipv6Only),
        value => Err(RuntimeError::InvalidField {
            field: "ipFamily".into(),
            reason: format!("unsupported record family '{value}'"),
        }),
    }
}

fn record_family_name(payload: &Value) -> Result<&'static str, RuntimeError> {
    match record_family(payload)? {
        DnsRecordFamily::Both => Ok("both"),
        DnsRecordFamily::Ipv4Only => Ok("ipv4-only"),
        DnsRecordFamily::Ipv6Only => Ok("ipv6-only"),
    }
}

fn resolver_port(payload: &Value) -> Result<u16, RuntimeError> {
    let port = positive_u64(payload, "resolverPort", 53)?;
    u16::try_from(port).map_err(|_| RuntimeError::InvalidField {
        field: "resolverPort".into(),
        reason: "must be between 1 and 65535".into(),
    })
}

fn positive_usize(payload: &Value, field: &str, default: usize) -> Result<usize, RuntimeError> {
    let value = payload
        .get(field)
        .and_then(Value::as_u64)
        .unwrap_or(default as u64);
    usize::try_from(value)
        .ok()
        .filter(|value| *value > 0)
        .ok_or_else(|| RuntimeError::InvalidField {
            field: field.into(),
            reason: "must be a positive whole number".into(),
        })
}

fn positive_u64(payload: &Value, field: &str, default: u64) -> Result<u64, RuntimeError> {
    payload
        .get(field)
        .and_then(Value::as_u64)
        .unwrap_or(default)
        .checked_sub(0)
        .filter(|value| *value > 0)
        .ok_or_else(|| RuntimeError::InvalidField {
            field: field.into(),
            reason: "must be a positive whole number".into(),
        })
}

fn positive_u16(payload: &Value, field: &str, default: u16) -> Result<u16, RuntimeError> {
    let value = positive_u64(payload, field, u64::from(default))?;
    u16::try_from(value).map_err(|_| RuntimeError::InvalidField {
        field: field.into(),
        reason: "must be between 1 and 65535".into(),
    })
}

fn optional_positive_u64(payload: &Value, field: &str) -> Result<Option<u64>, RuntimeError> {
    match payload.get(field) {
        None | Some(Value::Null) => Ok(None),
        Some(value) => value
            .as_u64()
            .filter(|value| *value > 0)
            .map(Some)
            .ok_or_else(|| RuntimeError::InvalidField {
                field: field.into(),
                reason: "must be a positive whole number".into(),
            }),
    }
}

fn string_array(payload: &Value, field: &str) -> Result<Vec<String>, RuntimeError> {
    let Some(value) = payload.get(field) else {
        return Ok(Vec::new());
    };
    let values = value.as_array().ok_or_else(|| RuntimeError::InvalidField {
        field: field.into(),
        reason: "must be an array of strings".into(),
    })?;
    values
        .iter()
        .map(|value| {
            value
                .as_str()
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(str::to_owned)
                .ok_or_else(|| RuntimeError::InvalidField {
                    field: field.into(),
                    reason: "must contain non-empty strings".into(),
                })
        })
        .collect()
}

fn save_history(
    payload: &Value,
    db_path: Option<&str>,
    record: BenchmarkHistoryRecord,
) -> Result<Option<String>, RuntimeError> {
    if !payload
        .get("saveHistory")
        .and_then(Value::as_bool)
        .unwrap_or(false)
    {
        return Ok(None);
    }
    let storage = storage(payload, db_path)?;
    let mut snapshot = load_snapshot_or_builtin(&storage)?;
    let id = optional_string(payload, "historyId").unwrap_or_else(|| record.id.clone());
    if snapshot.benchmark_history.iter().any(|item| item.id == id) {
        return Err(RuntimeError::Conflict(format!(
            "benchmark history '{id}' already exists"
        )));
    }
    let mut record = record;
    record.id = id.clone();
    snapshot.benchmark_history.push(record);
    save_snapshot(&storage, &snapshot)?;
    Ok(Some(id))
}

fn history_id(prefix: &str) -> String {
    timestamp_id(prefix)
}

fn timestamp_id(prefix: &str) -> String {
    let milliseconds = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis())
        .unwrap_or(0);
    format!("{prefix}-{milliseconds}")
}

struct ProgressEvent<'a> {
    event_type: &'a str,
    scope: MeasurementScope,
    profile_id: &'a str,
    resolver: SocketAddr,
    index: usize,
    total: usize,
    metrics: Option<&'a BenchmarkMetrics>,
    elapsed: Option<Duration>,
}

fn progress_event(input: ProgressEvent<'_>) -> Value {
    let mut event = json!({
        "type": input.event_type,
        "measurement_scope": measurement_scope_name(input.scope),
        "profile_id": input.profile_id,
        "resolver": input.resolver.to_string(),
        "index": input.index,
        "total": input.total,
    });
    if let Some(metrics) = input.metrics {
        event["status"] = Value::String(progress_status(metrics).into());
        event["failure_rate"] = Value::from(metrics.failure_rate);
        event["timeout_rate"] = Value::from(metrics.timeout_rate);
    }
    if let Some(elapsed) = input.elapsed {
        event["elapsed_ms"] = Value::from(elapsed.as_secs_f64() * 1000.0);
    }
    event
}

fn measurement_scope_name(scope: MeasurementScope) -> &'static str {
    match scope {
        MeasurementScope::DnsOnly => "dns-only",
        MeasurementScope::DnsTcp => "dns-tcp",
        MeasurementScope::DnsTcpTls => "dns-tcp-tls",
    }
}

fn progress_status(metrics: &BenchmarkMetrics) -> &'static str {
    if metrics.failure_rate >= 1.0 {
        "failed"
    } else if metrics.failure_rate > 0.0 || metrics.timeout_rate > 0.0 {
        "degraded"
    } else {
        "success"
    }
}

fn dns_sample_json(sample: &DnsBenchmarkSample) -> Value {
    json!({
        "domain": sample.domain,
        "record_type": match sample.record_type { RecordType::A => "A", RecordType::Aaaa => "AAAA" },
        "transaction_id": sample.transaction_id,
        "elapsed_ms": sample.elapsed.map(|elapsed| elapsed.as_secs_f64() * 1000.0),
        "outcome": match sample.outcome { DnsSampleOutcome::Success => "success", DnsSampleOutcome::Timeout => "timeout", DnsSampleOutcome::Failure => "failure" },
    })
}

fn storage(payload: &Value, db_path: Option<&str>) -> Result<SqliteStorage, RuntimeError> {
    let path = db_path.or_else(|| payload.get("dbPath").and_then(Value::as_str));
    let path = path.ok_or(RuntimeError::DatabasePathRequired)?;
    storage_for_path(path)
}

fn storage_for_path(path: &str) -> Result<SqliteStorage, RuntimeError> {
    SqliteStorage::open(path).map_err(|error| RuntimeError::Storage(error.to_string()))
}

fn builtin_snapshot() -> StorageSnapshot {
    StorageSnapshot {
        schema_version: STORAGE_SCHEMA_VERSION,
        profiles: built_in_profiles(),
        test_suites: built_in_test_suites(),
        benchmark_history: Vec::new(),
    }
}

fn load_snapshot_or_builtin(storage: &SqliteStorage) -> Result<StorageSnapshot, RuntimeError> {
    match storage.load_snapshot() {
        Ok(snapshot) => Ok(snapshot),
        Err(error) if error.to_string().contains("Query returned no rows") => {
            Ok(builtin_snapshot())
        }
        Err(error) => Err(RuntimeError::Storage(error.to_string())),
    }
}

fn save_snapshot(storage: &SqliteStorage, snapshot: &StorageSnapshot) -> Result<(), RuntimeError> {
    storage
        .save_snapshot(snapshot)
        .map_err(|error| RuntimeError::Storage(error.to_string()))
}

fn storage_smoke(storage: SqliteStorage) -> Result<Value, RuntimeError> {
    let snapshot = builtin_snapshot();
    save_snapshot(&storage, &snapshot)?;
    let loaded = load_snapshot_or_builtin(&storage)?;
    Ok(json!({
        "schema_version": loaded.schema_version,
        "profile_count": loaded.profiles.len(),
        "test_suite_count": loaded.test_suites.len(),
        "benchmark_history_count": loaded.benchmark_history.len(),
    }))
}

fn profile_list(storage: SqliteStorage) -> Result<Value, RuntimeError> {
    let snapshot = load_snapshot_or_builtin(&storage)?;
    Ok(json!({
        "schema_version": snapshot.schema_version,
        "profile_count": snapshot.profiles.len(),
        "profiles": snapshot.profiles,
    }))
}

fn profile_add(storage: SqliteStorage, payload: &Value) -> Result<Value, RuntimeError> {
    let mut snapshot = load_snapshot_or_builtin(&storage)?;
    let profile = custom_profile(payload)?;
    if snapshot.profiles.iter().any(|item| item.id == profile.id) {
        return Err(RuntimeError::Conflict(format!(
            "DNS profile '{}' already exists",
            profile.id
        )));
    }
    let id = profile.id.clone();
    snapshot.profiles.push(profile);
    save_snapshot(&storage, &snapshot)?;
    Ok(json!({ "profile_id": id, "profile_count": snapshot.profiles.len() }))
}

fn profile_update(storage: SqliteStorage, payload: &Value) -> Result<Value, RuntimeError> {
    let mut snapshot = load_snapshot_or_builtin(&storage)?;
    let profile = custom_profile(payload)?;
    let index = snapshot
        .profiles
        .iter()
        .position(|item| item.id == profile.id)
        .ok_or_else(|| RuntimeError::NotFound(format!("DNS profile '{}' not found", profile.id)))?;
    if !is_custom_profile(&snapshot.profiles[index]) {
        return Err(RuntimeError::ProtectedBuiltIn(format!(
            "DNS profile '{}'",
            profile.id
        )));
    }
    let id = profile.id.clone();
    snapshot.profiles[index] = profile;
    save_snapshot(&storage, &snapshot)?;
    Ok(json!({ "profile_id": id, "profile_count": snapshot.profiles.len() }))
}

fn profile_delete(storage: SqliteStorage, payload: &Value) -> Result<Value, RuntimeError> {
    let mut snapshot = load_snapshot_or_builtin(&storage)?;
    let id = required_string(payload, "id")?;
    let index = snapshot
        .profiles
        .iter()
        .position(|item| item.id == id)
        .ok_or_else(|| RuntimeError::NotFound(format!("DNS profile '{id}' not found")))?;
    if !is_custom_profile(&snapshot.profiles[index]) {
        return Err(RuntimeError::ProtectedBuiltIn(format!(
            "DNS profile '{id}'"
        )));
    }
    snapshot.profiles.remove(index);
    save_snapshot(&storage, &snapshot)?;
    Ok(json!({ "profile_id": id, "profile_count": snapshot.profiles.len() }))
}

fn suite_list(storage: SqliteStorage) -> Result<Value, RuntimeError> {
    let snapshot = load_snapshot_or_builtin(&storage)?;
    Ok(json!({
        "schema_version": snapshot.schema_version,
        "test_suite_count": snapshot.test_suites.len(),
        "test_suites": snapshot.test_suites,
    }))
}

fn suite_add(storage: SqliteStorage, payload: &Value) -> Result<Value, RuntimeError> {
    let mut snapshot = load_snapshot_or_builtin(&storage)?;
    let suite = custom_suite(payload)?;
    if snapshot.test_suites.iter().any(|item| item.id == suite.id) {
        return Err(RuntimeError::Conflict(format!(
            "test suite '{}' already exists",
            suite.id
        )));
    }
    let id = suite.id.clone();
    snapshot.test_suites.push(suite);
    save_snapshot(&storage, &snapshot)?;
    Ok(json!({ "test_suite_id": id, "test_suite_count": snapshot.test_suites.len() }))
}

fn suite_update(storage: SqliteStorage, payload: &Value) -> Result<Value, RuntimeError> {
    let mut snapshot = load_snapshot_or_builtin(&storage)?;
    let suite = custom_suite(payload)?;
    let index = snapshot
        .test_suites
        .iter()
        .position(|item| item.id == suite.id)
        .ok_or_else(|| RuntimeError::NotFound(format!("test suite '{}' not found", suite.id)))?;
    if !is_custom_suite(&snapshot.test_suites[index]) {
        return Err(RuntimeError::ProtectedBuiltIn(format!(
            "test suite '{}'",
            suite.id
        )));
    }
    let id = suite.id.clone();
    snapshot.test_suites[index] = suite;
    save_snapshot(&storage, &snapshot)?;
    Ok(json!({ "test_suite_id": id, "test_suite_count": snapshot.test_suites.len() }))
}

fn suite_delete(storage: SqliteStorage, payload: &Value) -> Result<Value, RuntimeError> {
    let mut snapshot = load_snapshot_or_builtin(&storage)?;
    let id = required_string(payload, "id")?;
    let index = snapshot
        .test_suites
        .iter()
        .position(|item| item.id == id)
        .ok_or_else(|| RuntimeError::NotFound(format!("test suite '{id}' not found")))?;
    if !is_custom_suite(&snapshot.test_suites[index]) {
        return Err(RuntimeError::ProtectedBuiltIn(format!("test suite '{id}'")));
    }
    snapshot.test_suites.remove(index);
    save_snapshot(&storage, &snapshot)?;
    Ok(json!({ "test_suite_id": id, "test_suite_count": snapshot.test_suites.len() }))
}

fn history_list(storage: SqliteStorage) -> Result<Value, RuntimeError> {
    let snapshot = load_snapshot_or_builtin(&storage)?;
    Ok(json!({
        "schema_version": snapshot.schema_version,
        "benchmark_history_count": snapshot.benchmark_history.len(),
        "benchmark_history": snapshot.benchmark_history,
    }))
}

fn history_delete(storage: SqliteStorage, payload: &Value) -> Result<Value, RuntimeError> {
    let mut snapshot = load_snapshot_or_builtin(&storage)?;
    let id = required_string(payload, "id")?;
    let index = snapshot
        .benchmark_history
        .iter()
        .position(|item| item.id == id)
        .ok_or_else(|| RuntimeError::NotFound(format!("benchmark history '{id}' not found")))?;
    snapshot.benchmark_history.remove(index);
    save_snapshot(&storage, &snapshot)?;
    Ok(json!({ "history_id": id, "benchmark_history_count": snapshot.benchmark_history.len() }))
}

fn history_clear(storage: SqliteStorage) -> Result<Value, RuntimeError> {
    let mut snapshot = load_snapshot_or_builtin(&storage)?;
    snapshot.benchmark_history.clear();
    save_snapshot(&storage, &snapshot)?;
    Ok(json!({ "benchmark_history_count": snapshot.benchmark_history.len() }))
}

fn custom_profile(payload: &Value) -> Result<DnsProfile, RuntimeError> {
    let input: MobileProfileInput =
        serde_json::from_value(payload.clone()).map_err(RuntimeError::InvalidPayload)?;
    let profile = DnsProfile {
        id: input.id,
        name: input.name,
        description: "Custom DNS profile.".into(),
        ipv4_servers: input.ipv4_servers,
        ipv6_servers: input.ipv6_servers,
        protocol: input.protocol,
        doh_url: input.doh_url,
        dot_hostname: input.dot_hostname,
        tags: input.tags,
        use_case: "custom".into(),
        filtering_type: input.filtering,
        security_notes: security_notes(input.filtering),
        provider_metadata: BTreeMap::new(),
        created_at: None,
        updated_at: None,
    };
    profile
        .validate()
        .map_err(|error| RuntimeError::Storage(error.to_string()))?;
    Ok(profile)
}

fn custom_suite(payload: &Value) -> Result<TestSuite, RuntimeError> {
    let input: MobileSuiteInput =
        serde_json::from_value(payload.clone()).map_err(RuntimeError::InvalidPayload)?;
    let suite = TestSuite {
        id: input.id,
        name: input.name,
        description: "Custom domain test suite.".into(),
        domains: input.domains,
        tags: input.tags,
    };
    suite
        .validate()
        .map_err(|error| RuntimeError::Storage(error.to_string()))?;
    Ok(suite)
}

fn is_custom_profile(profile: &DnsProfile) -> bool {
    profile.use_case == "custom" || profile.tags.iter().any(|tag| tag == "custom")
}

fn is_custom_suite(suite: &TestSuite) -> bool {
    suite.description == "Custom domain test suite." || suite.tags.iter().any(|tag| tag == "custom")
}

fn required_string(payload: &Value, field: &str) -> Result<String, RuntimeError> {
    payload
        .get(field)
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_owned)
        .ok_or_else(|| RuntimeError::RequiredField(field.to_owned()))
}

fn optional_string(payload: &Value, field: &str) -> Option<String> {
    payload
        .get(field)
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_owned)
}

fn security_notes(filtering: FilteringType) -> Vec<String> {
    if filtering == FilteringType::None {
        Vec::new()
    } else {
        vec!["Filtered DNS may intentionally block some domains.".into()]
    }
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct MobileProfileInput {
    id: String,
    name: String,
    protocol: DnsProtocol,
    #[serde(default)]
    ipv4_servers: Vec<String>,
    #[serde(default)]
    ipv6_servers: Vec<String>,
    #[serde(default)]
    doh_url: Option<String>,
    #[serde(default)]
    dot_hostname: Option<String>,
    #[serde(default = "default_filtering")]
    filtering: FilteringType,
    #[serde(default)]
    tags: Vec<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct MobileSuiteInput {
    id: String,
    name: String,
    #[serde(default)]
    domains: Vec<String>,
    #[serde(default)]
    tags: Vec<String>,
}

fn default_filtering() -> FilteringType {
    FilteringType::None
}

fn parse_payload(payload_json: &str) -> Result<Value, RuntimeError> {
    let value: Value = serde_json::from_str(payload_json).map_err(RuntimeError::InvalidPayload)?;
    if !value.is_object() {
        return Err(RuntimeError::ExpectedObject);
    }
    Ok(value)
}

fn value(input: impl serde::Serialize) -> Result<Value, RuntimeError> {
    serde_json::to_value(input).map_err(RuntimeError::Serialize)
}

fn platform(payload: &Value) -> Result<Platform, RuntimeError> {
    enum_field(payload, "platform", "ios")
}

fn enum_field<T>(payload: &Value, field: &str, fallback: &str) -> Result<T, RuntimeError>
where
    T: for<'de> Deserialize<'de>,
{
    let value = payload
        .get(field)
        .cloned()
        .unwrap_or_else(|| Value::String(fallback.to_owned()));
    serde_json::from_value(value).map_err(|error| RuntimeError::InvalidField {
        field: field.to_owned(),
        reason: error.to_string(),
    })
}

fn network_environment(payload: &Value) -> Result<NetworkEnvironment, RuntimeError> {
    let source = payload.get("environment").unwrap_or(payload).clone();
    let environment: MobileNetworkEnvironment =
        serde_json::from_value(source).map_err(RuntimeError::InvalidPayload)?;
    Ok(NetworkEnvironment {
        vpn_active: environment.vpn_active,
        mdm_profile_active: environment.mdm_profile_active,
        corporate_dns_detected: environment.corporate_dns_detected,
        captive_portal_detected: environment.captive_portal_detected,
    })
}

#[derive(Debug, Default, Deserialize)]
#[serde(default, rename_all = "camelCase")]
struct MobileNetworkEnvironment {
    vpn_active: bool,
    mdm_profile_active: bool,
    corporate_dns_detected: bool,
    captive_portal_detected: bool,
}

#[derive(Debug, thiserror::Error)]
enum RuntimeError {
    #[error("Unsupported action '{0}'")]
    UnsupportedAction(String),
    #[error("Invalid action payload: {0}")]
    InvalidPayload(serde_json::Error),
    #[error("Action payload must be a JSON object")]
    ExpectedObject,
    #[error("Invalid '{field}': {reason}")]
    InvalidField { field: String, reason: String },
    #[error("Could not serialize action result: {0}")]
    Serialize(serde_json::Error),
    #[error("'{0}' pointer is null")]
    NullPointer(&'static str),
    #[error("Native string is not valid UTF-8: {0}")]
    InvalidUtf8(std::str::Utf8Error),
    #[error("Native response contained an interior null byte")]
    InteriorNul,
    #[error("A native mobile database path is required")]
    DatabasePathRequired,
    #[error("Storage error: {0}")]
    Storage(String),
    #[error("Core error: {0}")]
    Core(String),
    #[error("{0}")]
    Conflict(String),
    #[error("{0}")]
    NotFound(String),
    #[error("cannot modify core-owned {0}")]
    ProtectedBuiltIn(String),
    #[error("Required field '{0}' is missing")]
    RequiredField(String),
    #[error("Invalid domain '{domain}': {reason}")]
    InvalidDomain { domain: String, reason: String },
    #[error(
        "DNS profile '{0}' is not plain DNS and cannot be measured by the UDP resolver benchmark"
    )]
    UnsupportedResolverProtocol(String),
    #[error("DNS profile '{0}' has no resolver addresses")]
    ResolverAddressMissing(String),
    #[error("Invalid DNS profile resolver '{server}': {reason}")]
    InvalidResolverAddress { server: String, reason: String },
}

unsafe fn required_c_string(
    value: *const c_char,
    name: &'static str,
) -> Result<String, RuntimeError> {
    if value.is_null() {
        return Err(RuntimeError::NullPointer(name));
    }
    unsafe { CStr::from_ptr(value) }
        .to_str()
        .map(str::to_owned)
        .map_err(RuntimeError::InvalidUtf8)
}

unsafe fn optional_c_string(value: *const c_char) -> Result<Option<String>, RuntimeError> {
    if value.is_null() {
        return Ok(None);
    }
    unsafe { required_c_string(value, "db_path") }.map(Some)
}

fn error_response(action: &str, error: RuntimeError) -> String {
    json!({ "ok": false, "action": action, "error": error.to_string() }).to_string()
}

fn panic_response() -> String {
    json!({
        "ok": false,
        "action": "native",
        "error": "Native runtime panicked while handling the action",
    })
    .to_string()
}

#[cfg(target_os = "android")]
mod android {
    use super::run_action_json;
    use jni::objects::{JClass, JString};
    use jni::sys::jstring;
    use jni::JNIEnv;

    #[no_mangle]
    pub extern "system" fn Java_expo_modules_dnspilotruntime_DNSPilotRuntimeModule_nativeRunAction(
        mut env: JNIEnv,
        _class: JClass,
        action: JString,
        payload_json: JString,
        db_path: JString,
    ) -> jstring {
        let output = (|| {
            let action: String = env.get_string(&action).ok()?.into();
            let payload_json: String = env.get_string(&payload_json).ok()?.into();
            let db_path = if db_path.is_null() {
                None
            } else {
                Some(String::from(env.get_string(&db_path).ok()?))
            };
            Some(run_action_json(&action, &payload_json, db_path.as_deref()))
        })()
        .unwrap_or_else(|| {
            serde_json::json!({
                "ok": false,
                "action": "native",
                "error": "Invalid JNI string input",
            })
            .to_string()
        });

        env.new_string(output)
            .map(|value| value.into_raw())
            .unwrap_or(std::ptr::null_mut())
    }
}
