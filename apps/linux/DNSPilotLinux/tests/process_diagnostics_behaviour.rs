use dnspilot_linux_shell::capabilities::{
    capability_view_model, BenchmarkMode, LinuxEnvironmentProbe, LinuxPackageKind,
};
use dnspilot_linux_shell::diagnostics::LinuxDiagnosticReport;
use dnspilot_linux_shell::process::{
    process_rows, LinuxBenchmarkProcessViewModel, ProcessRowKind, ProcessStatus, ProcessStepId,
};

fn probe(package_kind: LinuxPackageKind) -> LinuxEnvironmentProbe {
    LinuxEnvironmentProbe {
        package_kind,
        network_manager_available: false,
        systemd_resolved_available: false,
        polkit_available: false,
        system_resolver_probe_available: false,
    }
}

#[test]
fn dns_tcp_process_starts_idle_for_each_step_and_resolver() {
    let process = LinuxBenchmarkProcessViewModel::new(
        BenchmarkMode::DnsAndTcp,
        vec![("cloudflare", "Cloudflare"), ("google", "Google")],
    );

    let step_ids: Vec<ProcessStepId> = process.steps.iter().map(|step| step.id).collect();
    assert_eq!(
        step_ids,
        vec![
            ProcessStepId::DetectCapabilities,
            ProcessStepId::PrepareBenchmark,
            ProcessStepId::RunDnsBenchmark,
            ProcessStepId::RunTcpProbe,
            ProcessStepId::BuildDiagnostics
        ]
    );
    assert!(process
        .steps
        .iter()
        .all(|step| step.status == ProcessStatus::Idle));
    assert!(process
        .resolvers
        .iter()
        .all(|resolver| resolver.status == ProcessStatus::Idle));
    assert_eq!(process.overall_status(), ProcessStatus::Idle);
}

#[test]
fn current_resolver_mode_has_validation_step_without_tcp_probe() {
    let process = LinuxBenchmarkProcessViewModel::new(
        BenchmarkMode::CurrentSystemResolver,
        vec![("system", "Current system resolver")],
    );

    let step_ids: Vec<ProcessStepId> = process.steps.iter().map(|step| step.id).collect();
    assert!(step_ids.contains(&ProcessStepId::ValidateSystemResolver));
    assert!(!step_ids.contains(&ProcessStepId::RunTcpProbe));
}

#[test]
fn process_tracks_running_success_and_failed_states() {
    let mut process = LinuxBenchmarkProcessViewModel::new(
        BenchmarkMode::DnsOnly,
        vec![("cloudflare", "Cloudflare"), ("quad9", "Quad9")],
    );

    process.start_step(ProcessStepId::RunDnsBenchmark);
    process.complete_resolver("cloudflare", "median 12 ms");
    process.fail_resolver("quad9", "DNS timeout");
    process.fail_step(ProcessStepId::RunDnsBenchmark, "1 resolver failed");

    assert_eq!(
        process.step_status(ProcessStepId::RunDnsBenchmark),
        Some(ProcessStatus::Failed)
    );
    assert_eq!(process.resolvers[0].status, ProcessStatus::Success);
    assert_eq!(process.resolvers[0].detail.as_deref(), Some("median 12 ms"));
    assert_eq!(process.resolvers[1].status, ProcessStatus::Failed);
    assert_eq!(process.resolvers[1].detail.as_deref(), Some("DNS timeout"));
    assert_eq!(process.overall_status(), ProcessStatus::Failed);
}

#[test]
fn process_reports_success_after_all_steps_and_resolvers_succeed() {
    let mut process = LinuxBenchmarkProcessViewModel::new(
        BenchmarkMode::DnsOnly,
        vec![("cloudflare", "Cloudflare")],
    );

    for step_id in [
        ProcessStepId::DetectCapabilities,
        ProcessStepId::PrepareBenchmark,
        ProcessStepId::RunDnsBenchmark,
        ProcessStepId::BuildDiagnostics,
    ] {
        process.start_step(step_id);
        process.complete_step(step_id, "ok");
    }
    process.complete_resolver("cloudflare", "healthy");

    assert_eq!(process.overall_status(), ProcessStatus::Success);
}

#[test]
fn diagnostic_report_is_copyable_and_includes_capability_and_process_details() {
    let capability = capability_view_model(probe(LinuxPackageKind::Flatpak));
    let mut process = LinuxBenchmarkProcessViewModel::new(
        BenchmarkMode::DnsOnly,
        vec![("cloudflare", "Cloudflare")],
    );
    process.start_step(ProcessStepId::RunDnsBenchmark);
    process.fail_resolver("cloudflare", "DNS timeout");
    process.fail_step(ProcessStepId::RunDnsBenchmark, "DNS benchmark failed");

    let report = LinuxDiagnosticReport::new("Ubuntu 24.04", capability, process).to_copyable_text();

    assert!(report.contains("DNS Pilot Linux Debug Report"));
    assert!(report.contains("Distro: Ubuntu 24.04"));
    assert!(report.contains("Package: Flatpak"));
    assert!(report.contains("Apply path: Guided settings"));
    assert!(report.contains("Tray: optional"));
    assert!(report.contains("Run DNS benchmark: failed - DNS benchmark failed"));
    assert!(report.contains("Cloudflare: failed - DNS timeout"));
    assert!(report.contains("Flatpak build is store-safe"));
}

#[test]
fn process_rows_expose_steps_and_resolvers_for_gui_status_table() {
    let mut process = LinuxBenchmarkProcessViewModel::new(
        BenchmarkMode::DnsOnly,
        vec![("cloudflare", "Cloudflare")],
    );
    process.start_step(ProcessStepId::RunDnsBenchmark);
    process.complete_resolver("cloudflare", "12 ms");

    let rows = process_rows(&process);

    assert!(rows.iter().any(|row| {
        row.kind == ProcessRowKind::Step
            && row.label == "Run DNS benchmark"
            && row.status == "running"
            && row.detail.is_none()
    }));
    assert!(rows.iter().any(|row| {
        row.kind == ProcessRowKind::Resolver
            && row.label == "Cloudflare"
            && row.status == "success"
            && row.detail.as_deref() == Some("12 ms")
    }));
}
