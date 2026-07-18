use std::process::Command;

fn binary() -> Command {
    Command::new(env!("CARGO_BIN_EXE_dnspilot-linux-shell"))
}

#[test]
fn cli_renders_copyable_debug_report_for_flatpak_without_dns_mutation() {
    let output = binary()
        .args(["--package", "flatpak", "--mode", "dns-tcp"])
        .output()
        .unwrap();

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("DNS Pilot Linux Debug Report"));
    assert!(stdout.contains("Package: Flatpak"));
    assert!(stdout.contains("Benchmark mode: DNS + TCP"));
    assert!(stdout.contains("Apply path: Guided settings"));
    assert!(stdout.contains("Real DNS apply: not available"));
    assert!(stdout.contains("mocked validation; no DNS mutation"));
}

#[test]
fn cli_reports_native_power_as_unavailable_for_deb_with_networkmanager_and_polkit() {
    let output = binary()
        .args([
            "--package",
            "deb",
            "--network-manager",
            "--polkit",
            "--system-resolver-probe",
            "--mode",
            "system-resolver",
        ])
        .output()
        .unwrap();

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("Package: deb"));
    assert!(stdout.contains("Benchmark mode: Current/system resolver validation"));
    assert!(stdout.contains("Apply path: Unsupported"));
    assert!(stdout.contains("Real DNS apply: not available"));
    assert!(stdout.contains("Native Power is unavailable in this build"));
    assert!(stdout.contains("Validate current resolver: success"));
}

#[test]
fn cli_rejects_unsupported_system_resolver_validation_for_flatpak() {
    let output = binary()
        .args(["--package", "flatpak", "--mode", "system-resolver"])
        .output()
        .unwrap();

    assert!(!output.status.success());
    let stderr = String::from_utf8(output.stderr).unwrap();
    assert!(stderr.contains("system-resolver is not supported by current capabilities"));
}
