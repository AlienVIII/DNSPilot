use dnspilot_linux_shell::benchmark::{
    CoreCliCommand, CoreCliRunOutput, CoreCliRunner, LinuxBenchmarkPlan, ResolverSelection,
};
use dnspilot_linux_shell::capabilities::{
    capability_view_model, BenchmarkMode, LinuxEnvironmentProbe, LinuxPackageKind,
};
use dnspilot_linux_shell::settings::DnsRecordFamily;
use dnspilot_linux_shell::worker::{spawn_benchmark_worker, BenchmarkWorkerPoll};
use std::sync::mpsc::{self, Receiver, SyncSender};
use std::time::{Duration, Instant};

struct GateRunner {
    started: SyncSender<()>,
    release: Receiver<()>,
}

impl CoreCliRunner for GateRunner {
    fn run(&self, _command: &CoreCliCommand) -> CoreCliRunOutput {
        self.started.send(()).expect("report worker start");
        self.release.recv().expect("wait for test release");
        CoreCliRunOutput {
            exit_code: 0,
            stdout: "{}".to_string(),
            stderr: String::new(),
        }
    }
}

#[test]
fn benchmark_worker_can_be_polled_without_blocking_the_ui_thread() {
    let (started_sender, started_receiver) = mpsc::sync_channel(1);
    let (release_sender, release_receiver) = mpsc::channel();
    let worker = spawn_benchmark_worker(
        "dnspilot-cli".to_string(),
        "linux-test".to_string(),
        capability_view_model(LinuxEnvironmentProbe {
            package_kind: LinuxPackageKind::Flatpak,
            network_manager_available: false,
            systemd_resolved_available: false,
            polkit_available: false,
            system_resolver_probe_available: false,
        }),
        dns_only_plan(),
        GateRunner {
            started: started_sender,
            release: release_receiver,
        },
    )
    .expect("worker thread should start");

    started_receiver
        .recv_timeout(Duration::from_secs(1))
        .expect("worker should reach runner");
    assert!(matches!(worker.poll(), BenchmarkWorkerPoll::Running));

    release_sender.send(()).expect("release worker");
    let deadline = Instant::now() + Duration::from_secs(1);
    loop {
        match worker.poll() {
            BenchmarkWorkerPoll::Running if Instant::now() < deadline => {
                std::thread::yield_now();
            }
            BenchmarkWorkerPoll::Finished(result) => {
                assert!(result.error.is_none());
                assert_eq!(result.final_payload.as_deref(), Some("{}"));
                break;
            }
            other => panic!("worker did not finish successfully: {other:?}"),
        }
    }
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
        attempts: 1,
        record_family: DnsRecordFamily::AAndAaaa,
    }
}
