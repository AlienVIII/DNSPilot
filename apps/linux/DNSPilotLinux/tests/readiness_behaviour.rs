use dnspilot_linux_shell::readiness::{
    linux_release_readiness, render_readiness_report, ReadinessStatus,
};

#[test]
fn release_readiness_keeps_unfinished_consumer_and_power_work_visible() {
    let readiness = linux_release_readiness();

    assert!(!readiness.code_ready);
    assert!(readiness
        .items
        .iter()
        .any(|item| item.name == "Capability matrix" && item.status == ReadinessStatus::Ready));
    assert!(readiness
        .items
        .iter()
        .any(|item| item.name == "Benchmark modes" && item.status == ReadinessStatus::Ready));
    assert!(readiness
        .items
        .iter()
        .any(|item| item.name == "Native app surface" && item.status == ReadinessStatus::Ready));
    assert!(readiness
        .items
        .iter()
        .any(|item| item.name == "Packaging and publish checklist"
            && item.status == ReadinessStatus::Ready
            && item.evidence.contains("publish-check")));
    assert!(readiness
        .external_requirements
        .iter()
        .any(|requirement| { requirement.contains("Flatpak/Snap/deb/rpm real package QA") }));
    assert!(readiness.items.iter().any(|item| {
        item.name == "Native power path"
            && item.status == ReadinessStatus::ExternalQaRequired
            && item.evidence.contains("unavailable")
    }));
    assert!(readiness.items.iter().any(|item| {
        item.name == "Native app surface" && item.evidence.contains("dnspilot-linux-gui")
    }));
    assert!(readiness
        .items
        .iter()
        .any(|item| { item.name == "Localization" && item.evidence.contains("publish") }));
    assert!(!readiness
        .external_requirements
        .iter()
        .any(|requirement| requirement.contains("GTK/libadwaita or Qt")));
    assert!(!readiness
        .external_requirements
        .iter()
        .any(|requirement| requirement.contains("write backend")));
}

#[test]
fn readiness_report_is_copyable_and_separates_manual_publish_work() {
    let report = render_readiness_report(&linux_release_readiness());

    assert!(report.contains("DNS Pilot Linux Readiness"));
    assert!(report.contains("Code readiness: store-safe consumer work in progress"));
    assert!(report.contains("Capability matrix: ready"));
    assert!(report.contains("Manual/external requirements:"));
    assert!(report.contains("store credentials"));
    assert!(report.contains("signing"));
    assert!(report.contains("Native power path: external QA required"));
    assert!(report.contains("unavailable"));
    assert!(report.contains("real package QA"));
    assert!(report.contains("publish-check"));
}
