use dnspilot_linux_shell::benchmark::{LinuxBenchmarkPlan, ResolverSelection};
use dnspilot_linux_shell::capabilities::{
    capability_view_model, BenchmarkMode, LinuxEnvironmentProbe, LinuxPackageKind,
};
use dnspilot_linux_shell::process::ProcessStatus;
use dnspilot_linux_shell::settings::DnsRecordFamily;
use dnspilot_linux_shell::worker::{spawn_benchmark_worker, BenchmarkWorkerPoll};
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::PathBuf;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

#[test]
fn benchmark_worker_emits_jsonl_progress_before_process_completion() {
    let core_cli = executable_script(
        "streaming-progress",
        "echo '{\"event\":\"resolver_started\",\"resolver_id\":\"cloudflare\"}' >&2\necho malformed-jsonl >&2\nsleep 0.2\necho '{\"event\":\"resolver_finished\",\"resolver_id\":\"cloudflare\",\"elapsed_ms\":7}' >&2\necho '{\"summary\":{\"can_recommend\":false,\"recommended_profile_id\":null},\"warning\":\"estimate\"}'",
    );
    let worker = spawn_benchmark_worker(
        core_cli.to_string_lossy().into_owned(),
        "linux-test".to_string(),
        flatpak_capability(),
        dns_only_plan(),
    )
    .expect("worker thread should start");

    let deadline = Instant::now() + Duration::from_secs(2);
    let mut saw_running = false;
    loop {
        match worker.poll() {
            BenchmarkWorkerPoll::Running if Instant::now() < deadline => {
                std::thread::sleep(Duration::from_millis(10));
            }
            BenchmarkWorkerPoll::Progress(process) => {
                saw_running |= process.resolvers[0].status == ProcessStatus::Running;
            }
            BenchmarkWorkerPoll::Finished(result) => {
                assert!(saw_running, "running event must arrive before completion");
                assert!(result.error.is_none());
                assert_eq!(result.process.resolvers[0].status, ProcessStatus::Success);
                assert!(result.debug_report.contains("malformed-jsonl"));
                break;
            }
            other => panic!("worker did not stream and finish: {other:?}"),
        }
    }
}

#[test]
fn benchmark_worker_cancels_reaps_and_marks_all_active_rows_terminal() {
    let core_cli = executable_script(
        "streaming-cancel",
        "echo '{\"event\":\"resolver_started\",\"resolver_id\":\"cloudflare\"}' >&2\nsleep 5 &\nwait\necho should-not-complete",
    );
    let worker = spawn_benchmark_worker(
        core_cli.to_string_lossy().into_owned(),
        "linux-test".to_string(),
        flatpak_capability(),
        dns_only_plan(),
    )
    .expect("worker thread should start");

    let deadline = Instant::now() + Duration::from_secs(2);
    loop {
        match worker.poll() {
            BenchmarkWorkerPoll::Progress(_) => {
                worker.cancel();
                break;
            }
            BenchmarkWorkerPoll::Running if Instant::now() < deadline => {
                std::thread::sleep(Duration::from_millis(10));
            }
            other => panic!("worker did not start before cancellation: {other:?}"),
        }
    }

    let deadline = Instant::now() + Duration::from_secs(2);
    loop {
        match worker.poll() {
            BenchmarkWorkerPoll::Running | BenchmarkWorkerPoll::Progress(_)
                if Instant::now() < deadline =>
            {
                std::thread::sleep(Duration::from_millis(10));
            }
            BenchmarkWorkerPoll::Finished(result) => {
                assert_eq!(result.error.as_deref(), Some("Benchmark cancelled"));
                assert!(result
                    .process
                    .steps
                    .iter()
                    .all(|step| step.status != ProcessStatus::Running));
                assert!(result
                    .process
                    .resolvers
                    .iter()
                    .all(|resolver| resolver.status == ProcessStatus::Failed));
                break;
            }
            other => panic!("worker did not finish after cancellation: {other:?}"),
        }
    }
}

fn flatpak_capability() -> dnspilot_linux_shell::capabilities::LinuxCapabilityViewModel {
    capability_view_model(LinuxEnvironmentProbe {
        package_kind: LinuxPackageKind::Flatpak,
        network_manager_available: false,
        systemd_resolved_available: false,
        polkit_available: false,
        system_resolver_probe_available: false,
    })
}

fn dns_only_plan() -> LinuxBenchmarkPlan {
    LinuxBenchmarkPlan {
        mode: BenchmarkMode::DnsOnly,
        package_platform: "linux-flatpak".to_string(),
        resolvers: vec![ResolverSelection {
            id: "cloudflare".to_string(),
            label: "Cloudflare".to_string(),
            resolver_spec: "cloudflare=1.1.1.1".to_string(),
        }],
        domains: vec!["example.com".to_string()],
        suite_id: None,
        suite_db: None,
        profile_db: None,
        history_db: None,
        attempts: 1,
        record_family: DnsRecordFamily::AAndAaaa,
    }
}

fn executable_script(name: &str, body: &str) -> PathBuf {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let path = std::env::temp_dir().join(format!("dnspilot-linux-{name}-{nanos}.sh"));
    fs::write(&path, format!("#!/bin/sh\n{body}\n")).unwrap();
    let mut permissions = fs::metadata(&path).unwrap().permissions();
    permissions.set_mode(0o755);
    fs::set_permissions(&path, permissions).unwrap();
    path
}
