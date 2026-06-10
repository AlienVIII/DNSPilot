use dnspilot_core::{
    built_in_profiles, built_in_test_suites, validate_storage_snapshot, BenchmarkHistoryRecord,
    BenchmarkMetrics, MeasurementScope, RecommendationGate, RecommendationHealth,
    RecommendationIssue, RecommendationMode, SqliteStorage, StorageSnapshot,
    STORAGE_SCHEMA_VERSION,
};

#[test]
fn storage_snapshot_roundtrips_profiles_suites_and_history() {
    let snapshot = StorageSnapshot {
        schema_version: STORAGE_SCHEMA_VERSION,
        profiles: built_in_profiles(),
        test_suites: built_in_test_suites(),
        benchmark_history: vec![history_record("run-1")],
    };

    validate_storage_snapshot(&snapshot).expect("snapshot should be valid");

    let encoded = serde_json::to_string(&snapshot).expect("serialize snapshot");
    let decoded: StorageSnapshot = serde_json::from_str(&encoded).expect("decode snapshot");

    assert_eq!(decoded.schema_version, STORAGE_SCHEMA_VERSION);
    assert_eq!(decoded.benchmark_history[0].id, "run-1");
    assert_eq!(
        decoded.benchmark_history[0].scope,
        MeasurementScope::DnsTcpTls
    );
}

#[test]
fn storage_snapshot_rejects_unknown_schema_version() {
    let snapshot = StorageSnapshot {
        schema_version: STORAGE_SCHEMA_VERSION + 1,
        profiles: built_in_profiles(),
        test_suites: built_in_test_suites(),
        benchmark_history: vec![],
    };

    let error = validate_storage_snapshot(&snapshot).expect_err("schema should be rejected");

    assert!(error.to_string().contains("unsupported storage schema"));
}

#[test]
fn storage_snapshot_rejects_duplicate_profile_ids() {
    let mut profiles = built_in_profiles();
    let duplicate = profiles[0].clone();
    profiles.push(duplicate);
    let snapshot = StorageSnapshot {
        schema_version: STORAGE_SCHEMA_VERSION,
        profiles,
        test_suites: built_in_test_suites(),
        benchmark_history: vec![],
    };

    let error = validate_storage_snapshot(&snapshot).expect_err("duplicate id should be rejected");

    assert!(error.to_string().contains("duplicate profile id"));
}

#[test]
fn storage_snapshot_rejects_invalid_or_duplicate_suite_domains() {
    let mut invalid_suites = built_in_test_suites();
    invalid_suites.push(dnspilot_core::TestSuite {
        id: "invalid-suite".into(),
        name: "Invalid Suite".into(),
        description: "Invalid domains should be rejected.".into(),
        domains: vec!["good.example".into(), "bad domain".into()],
        tags: vec![],
    });
    let invalid_snapshot = StorageSnapshot {
        schema_version: STORAGE_SCHEMA_VERSION,
        profiles: built_in_profiles(),
        test_suites: invalid_suites,
        benchmark_history: vec![],
    };

    let invalid_error = validate_storage_snapshot(&invalid_snapshot)
        .expect_err("invalid suite domain should be rejected");
    assert!(invalid_error.to_string().contains("invalid test suite domain"));

    let mut duplicate_suites = built_in_test_suites();
    duplicate_suites.push(dnspilot_core::TestSuite {
        id: "duplicate-suite".into(),
        name: "Duplicate Suite".into(),
        description: "Duplicate domains should be rejected.".into(),
        domains: vec!["github.com".into(), "github.com".into()],
        tags: vec![],
    });
    let duplicate_snapshot = StorageSnapshot {
        schema_version: STORAGE_SCHEMA_VERSION,
        profiles: built_in_profiles(),
        test_suites: duplicate_suites,
        benchmark_history: vec![],
    };

    let duplicate_error = validate_storage_snapshot(&duplicate_snapshot)
        .expect_err("duplicate suite domain should be rejected");
    assert!(duplicate_error.to_string().contains("duplicate test suite domain"));
}

#[test]
fn sqlite_storage_saves_and_loads_snapshot() {
    let snapshot = StorageSnapshot {
        schema_version: STORAGE_SCHEMA_VERSION,
        profiles: built_in_profiles(),
        test_suites: built_in_test_suites(),
        benchmark_history: vec![history_record("run-1")],
    };
    let storage = SqliteStorage::open_in_memory().expect("open sqlite");

    storage.save_snapshot(&snapshot).expect("save snapshot");
    let loaded = storage.load_snapshot().expect("load snapshot");

    assert_eq!(loaded.schema_version, STORAGE_SCHEMA_VERSION);
    assert_eq!(loaded.benchmark_history[0].id, "run-1");
    assert_eq!(loaded.profiles.len(), snapshot.profiles.len());
}

#[test]
fn sqlite_storage_preserves_infinite_latency_metrics() {
    let mut record = history_record("dns-only-run");
    record.scope = MeasurementScope::DnsOnly;
    record.metrics[0].median_connect_latency_ms = f64::INFINITY;
    let snapshot = StorageSnapshot {
        schema_version: STORAGE_SCHEMA_VERSION,
        profiles: built_in_profiles(),
        test_suites: built_in_test_suites(),
        benchmark_history: vec![record],
    };
    let storage = SqliteStorage::open_in_memory().expect("open sqlite");

    storage.save_snapshot(&snapshot).expect("save snapshot");
    let loaded = storage.load_snapshot().expect("load snapshot");

    assert!(loaded.benchmark_history[0].metrics[0]
        .median_connect_latency_ms
        .is_infinite());
}

fn history_record(id: &str) -> BenchmarkHistoryRecord {
    BenchmarkHistoryRecord {
        id: id.into(),
        started_at: "2026-06-09T00:00:00Z".into(),
        scope: MeasurementScope::DnsTcpTls,
        mode: RecommendationMode::BestOverall,
        domains: vec!["github.com".into()],
        resolver_profile_ids: vec!["cloudflare".into(), "google-public-dns".into()],
        metrics: vec![BenchmarkMetrics {
            profile_id: "cloudflare".into(),
            median_dns_latency_ms: 12.0,
            p95_dns_latency_ms: 25.0,
            failure_rate: 0.0,
            timeout_rate: 0.0,
            median_connect_latency_ms: 50.0,
            ipv4_health: 1.0,
            ipv6_health: 1.0,
            priority_fit: 1.0,
        }],
        gate: RecommendationGate {
            can_recommend: true,
            health: RecommendationHealth::Healthy,
            primary_issue: RecommendationIssue::None,
            notes: vec![],
        },
        recommendation_profile_id: Some("cloudflare".into()),
        notes: vec!["manual test record".into()],
    }
}
