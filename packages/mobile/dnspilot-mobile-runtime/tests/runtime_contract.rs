use dnspilot_mobile_runtime::{dnspilot_free_string, dnspilot_run_action, run_action_json};
use serde_json::{json, Value};
use std::ffi::{CStr, CString};

fn run(action: &str, payload: Value) -> Value {
    serde_json::from_str(&run_action_json(action, &payload.to_string(), None)).unwrap()
}

#[test]
fn catalog_uses_the_shared_core_payload() {
    let result = run("catalog", json!({}));

    assert_eq!(result["ok"], true);
    assert_eq!(result["action"], "catalog");
    assert_eq!(result["data"]["schema_version"], 1);
    assert!(result["data"]["profiles"].as_array().unwrap().len() >= 3);
    assert!(result["data"]["testSuites"].as_array().unwrap().len() >= 2);
}

#[test]
fn capability_contract_accepts_mobile_platform_ids() {
    let ios = run("capability", json!({ "platform": "ios" }));
    let android = run("capability", json!({ "platform": "android-play" }));

    assert_eq!(ios["data"]["platform"], "ios");
    assert_eq!(ios["data"]["apply"], "apple-network-extension-dns-settings");
    assert_eq!(android["data"]["platform"], "android-play");
    assert_eq!(android["data"]["apply"], "guided-settings");
}

#[test]
fn protected_network_policy_is_core_owned() {
    let result = run(
        "applyPolicy",
        json!({
            "platform": "ios",
            "environment": { "vpnActive": true }
        }),
    );

    assert_eq!(result["data"]["disposition"], "protect-current-dns");
    assert_eq!(result["data"]["can_prompt_apply"], false);
}

#[test]
fn apply_plan_uses_native_storage_and_preserves_ios_user_approval() {
    let directory = tempfile::tempdir().unwrap();
    let database = directory.path().join("dnspilot.sqlite");
    let database = database.to_string_lossy();
    let result = serde_json::from_str::<Value>(&run_action_json(
        "applyPlan",
        &json!({
            "platform": "ios",
            "profileId": "cloudflare",
            "testedResolver": "1.1.1.1:53",
            "confidence": "high",
            "gateHealth": "healthy"
        })
        .to_string(),
        Some(&database),
    ))
    .unwrap();

    assert_eq!(result["ok"], true);
    assert_eq!(result["data"]["disposition"], "guide-only");
    assert_eq!(result["data"]["profile_id"], "cloudflare");
    assert_eq!(result["data"]["dns_servers"][0], "1.1.1.1");
}

#[test]
fn recommend_sample_is_computed_by_the_shared_core() {
    let result = run("recommendSample", json!({}));

    assert_eq!(result["ok"], true);
    assert_eq!(result["data"]["profile_id"], "quad9");
    assert_eq!(
        result["data"]["decision"],
        json!({ "apply-profile": "quad9" })
    );
}

#[test]
fn native_compare_reports_per_resolver_progress_without_a_bridge() {
    let directory = tempfile::tempdir().unwrap();
    let database = directory.path().join("dnspilot.sqlite");
    let database = database.to_string_lossy();
    let profile = json!({
        "id": "loopback",
        "name": "Loopback",
        "protocol": "plain",
        "ipv4Servers": ["127.0.0.1"],
        "tags": ["custom"]
    });
    let _ = run_action_json("profileAdd", &profile.to_string(), Some(&database));
    let result = serde_json::from_str::<Value>(&run_action_json(
        "compare",
        &json!({
            "profileIds": ["loopback"],
            "domains": ["example.com"],
            "attempts": 1,
            "ipFamily": "ipv4-only",
            "timeoutMs": 10
        })
        .to_string(),
        Some(&database),
    ))
    .unwrap();

    assert_eq!(result["ok"], true);
    assert_eq!(result["data"]["summary"]["measurement_scope"], "dns-only");
    assert_eq!(result["data"]["runs"][0]["profile_id"], "loopback");
    assert_eq!(result["progress"][0]["type"], "resolver_started");
    assert_eq!(result["progress"][1]["type"], "resolver_finished");
}

#[test]
fn native_path_compare_returns_dns_tcp_diagnostics_without_a_bridge() {
    let directory = tempfile::tempdir().unwrap();
    let database = directory.path().join("dnspilot.sqlite");
    let database = database.to_string_lossy();
    let profile = json!({
        "id": "loopback-path",
        "name": "Loopback Path",
        "protocol": "plain",
        "ipv4Servers": ["127.0.0.1"],
        "tags": ["custom"]
    });
    let _ = run_action_json("profileAdd", &profile.to_string(), Some(&database));
    let result = serde_json::from_str::<Value>(&run_action_json(
        "pathCompare",
        &json!({
            "profileIds": ["loopback-path"],
            "domains": ["example.com"],
            "attempts": 1,
            "ipFamily": "ipv4-only",
            "dnsTimeoutMs": 10,
            "connectTimeoutMs": 10,
            "maxConnectTargetsPerDomain": 1
        })
        .to_string(),
        Some(&database),
    ))
    .unwrap();

    assert_eq!(result["ok"], true);
    assert_eq!(result["data"]["summary"]["measurement_scope"], "dns-tcp");
    assert_eq!(result["data"]["runs"][0]["profile_id"], "loopback-path");
    assert_eq!(result["progress"][1]["type"], "resolver_finished");
}

#[test]
fn invalid_actions_return_a_structured_error() {
    let result = run("not-real", json!({}));

    assert_eq!(result["ok"], false);
    assert!(result["error"]
        .as_str()
        .unwrap()
        .contains("Unsupported action"));
}

#[test]
fn c_abi_returns_owned_json_and_exposes_a_matching_free_function() {
    let action = CString::new("catalog").unwrap();
    let payload = CString::new("{}").unwrap();
    unsafe {
        let output = dnspilot_run_action(action.as_ptr(), payload.as_ptr(), std::ptr::null());
        assert!(!output.is_null());
        let value: Value = serde_json::from_str(CStr::from_ptr(output).to_str().unwrap()).unwrap();
        assert_eq!(value["ok"], true);
        dnspilot_free_string(output);
    }
}

#[test]
fn profile_storage_round_trips_custom_encrypted_dns_with_bootstrap_ips() {
    let directory = tempfile::tempdir().unwrap();
    let database = directory.path().join("dnspilot.sqlite");
    let database = database.to_string_lossy();
    let add = serde_json::from_str::<Value>(&run_action_json(
        "profileAdd",
        &json!({
            "id": "cloudflare-doh",
            "name": "Cloudflare DoH",
            "protocol": "doh",
            "dohUrl": "https://cloudflare-dns.com/dns-query",
            "ipv4Servers": ["1.1.1.1", "1.0.0.1"],
            "tags": ["custom", "encrypted"]
        })
        .to_string(),
        Some(&database),
    ))
    .unwrap();
    let listed =
        serde_json::from_str::<Value>(&run_action_json("profileList", "{}", Some(&database)))
            .unwrap();

    assert_eq!(add["ok"], true);
    let profile = listed["data"]["profiles"]
        .as_array()
        .unwrap()
        .iter()
        .find(|profile| profile["id"] == "cloudflare-doh")
        .unwrap();
    assert_eq!(profile["doh_url"], "https://cloudflare-dns.com/dns-query");
    assert_eq!(profile["ipv4_servers"], json!(["1.1.1.1", "1.0.0.1"]));
}

#[test]
fn suite_storage_rejects_edits_to_core_owned_suites() {
    let directory = tempfile::tempdir().unwrap();
    let database = directory.path().join("dnspilot.sqlite");
    let database = database.to_string_lossy();
    let result = serde_json::from_str::<Value>(&run_action_json(
        "suiteUpdate",
        &json!({
            "id": "general",
            "name": "Changed",
            "domains": ["example.com"],
            "tags": ["custom"]
        })
        .to_string(),
        Some(&database),
    ))
    .unwrap();

    assert_eq!(result["ok"], false);
    assert!(
        result["error"].as_str().unwrap().contains("core-owned"),
        "{result}"
    );
}
