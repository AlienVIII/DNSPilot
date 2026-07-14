use std::path::PathBuf;
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

fn binary() -> Command {
    Command::new(env!("CARGO_BIN_EXE_dnspilot-linux-shell"))
}

fn temp_path(name: &str) -> PathBuf {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    std::env::temp_dir().join(format!(
        "dnspilot-linux-cli-{name}-{}-{nanos}.json",
        std::process::id()
    ))
}

#[test]
fn cli_can_add_list_and_delete_custom_profiles_in_store() {
    let store = temp_path("profiles");

    let add = binary()
        .args([
            "profile-add",
            "--store",
            store.to_str().unwrap(),
            "--id",
            "local",
            "--name",
            "Local DNS",
            "--ipv4",
            "1.1.1.1",
            "--ipv6",
            "2606:4700:4700::1111",
        ])
        .output()
        .unwrap();
    assert!(add.status.success());
    assert!(String::from_utf8(add.stdout)
        .unwrap()
        .contains("Saved profile local"));

    let list = binary()
        .args(["profile-list", "--store", store.to_str().unwrap()])
        .output()
        .unwrap();
    assert!(list.status.success());
    let stdout = String::from_utf8(list.stdout).unwrap();
    assert!(stdout.contains("local\tLocal DNS\t1.1.1.1\t2606:4700:4700::1111"));

    let delete = binary()
        .args([
            "profile-delete",
            "--store",
            store.to_str().unwrap(),
            "--id",
            "local",
        ])
        .output()
        .unwrap();
    assert!(delete.status.success());
    assert!(String::from_utf8(delete.stdout)
        .unwrap()
        .contains("Deleted profile local"));

    let list = binary()
        .args(["profile-list", "--store", store.to_str().unwrap()])
        .output()
        .unwrap();
    assert!(list.status.success());
    assert!(String::from_utf8(list.stdout)
        .unwrap()
        .contains("No custom profiles"));
}

#[test]
fn cli_can_edit_custom_profiles_in_store() {
    let store = temp_path("edit-profile");

    let add = binary()
        .args([
            "profile-add",
            "--store",
            store.to_str().unwrap(),
            "--id",
            "local",
            "--name",
            "Local DNS",
            "--ipv4",
            "1.1.1.1",
        ])
        .output()
        .unwrap();
    assert!(add.status.success());

    let edit = binary()
        .args([
            "profile-edit",
            "--store",
            store.to_str().unwrap(),
            "--id",
            "local",
            "--name",
            "Edited DNS",
            "--ipv4",
            "9.9.9.9",
            "--ipv6",
            "2620:fe::fe",
        ])
        .output()
        .unwrap();
    assert!(edit.status.success());
    assert!(String::from_utf8(edit.stdout)
        .unwrap()
        .contains("Updated profile local"));

    let list = binary()
        .args(["profile-list", "--store", store.to_str().unwrap()])
        .output()
        .unwrap();
    assert!(list.status.success());
    let stdout = String::from_utf8(list.stdout).unwrap();
    assert!(stdout.contains("local\tEdited DNS\t9.9.9.9\t2620:fe::fe"));
    assert!(!stdout.contains("1.1.1.1"));
}

#[test]
fn cli_profile_edit_rejects_missing_profile_before_saving() {
    let store = temp_path("missing-edit-profile");

    let output = binary()
        .args([
            "profile-edit",
            "--store",
            store.to_str().unwrap(),
            "--id",
            "missing",
            "--name",
            "Missing DNS",
            "--ipv4",
            "1.1.1.1",
        ])
        .output()
        .unwrap();

    assert!(!output.status.success());
    assert!(String::from_utf8(output.stderr)
        .unwrap()
        .contains("MissingProfile"));
}

#[test]
fn cli_profile_add_rejects_invalid_family_before_saving() {
    let store = temp_path("invalid-profile");

    let output = binary()
        .args([
            "profile-add",
            "--store",
            store.to_str().unwrap(),
            "--id",
            "bad",
            "--name",
            "Bad",
            "--ipv4",
            "2606:4700:4700::1111",
        ])
        .output()
        .unwrap();

    assert!(!output.status.success());
    assert!(String::from_utf8(output.stderr)
        .unwrap()
        .contains("InvalidIpv4"));
}

#[test]
fn cli_plan_uses_stored_profiles_and_session_controls() {
    let store = temp_path("plan");
    let add = binary()
        .args([
            "profile-add",
            "--store",
            store.to_str().unwrap(),
            "--id",
            "local",
            "--name",
            "Local DNS",
            "--ipv4",
            "1.1.1.1",
            "--ipv6",
            "2606:4700:4700::1111",
        ])
        .output()
        .unwrap();
    assert!(add.status.success());

    let output = binary()
        .args([
            "plan",
            "--store",
            store.to_str().unwrap(),
            "--package",
            "snap",
            "--catalog-vietnam",
            "--profile-id",
            "local",
            "--resolver-family",
            "ipv4",
            "--record-family",
            "a",
            "--suite-id",
            "vietnam-daily",
            "--domain",
            "login.microsoftonline.com",
        ])
        .output()
        .unwrap();

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("path-compare"));
    assert!(stdout.contains("--resolver local=1.1.1.1"));
    assert!(stdout.contains("--suite-id vietnam-daily"));
    assert!(stdout.contains("--domain login.microsoftonline.com"));
    assert!(stdout.contains("--ip-family ipv4-only"));
    assert!(stdout.contains("--progress-jsonl"));
}

#[test]
fn cli_run_executes_supplied_core_cli_and_renders_debug_report() {
    let store = temp_path("run");
    let add = binary()
        .args([
            "profile-add",
            "--store",
            store.to_str().unwrap(),
            "--id",
            "local",
            "--name",
            "Local DNS",
            "--ipv4",
            "1.1.1.1",
        ])
        .output()
        .unwrap();
    assert!(add.status.success());

    let fake_core = temp_path("fake-core");
    std::fs::write(
        &fake_core,
        "#!/bin/sh\necho '{\"schema_version\":1,\"ok\":true}'\necho '{\"event\":\"resolver_finished\",\"resolver_id\":\"local\",\"elapsed_ms\":7}' >&2\n",
    )
    .unwrap();
    make_executable(&fake_core);

    let output = binary()
        .args([
            "run",
            "--core-cli",
            fake_core.to_str().unwrap(),
            "--store",
            store.to_str().unwrap(),
            "--package",
            "flatpak",
            "--profile-id",
            "local",
            "--domain",
            "github.com",
        ])
        .output()
        .unwrap();

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("DNS Pilot Linux Debug Report"));
    assert!(stdout.contains("Package: Flatpak"));
    assert!(stdout.contains("Local DNS: success - 7 ms"));
    assert!(stdout.contains("Final payload:"));
    assert!(stdout.contains("\"ok\":true"));
}

#[test]
fn cli_guide_for_store_build_outputs_copyable_manual_dns_steps() {
    let store = temp_path("guide-store");
    let add = binary()
        .args([
            "profile-add",
            "--store",
            store.to_str().unwrap(),
            "--id",
            "local",
            "--name",
            "Local DNS",
            "--ipv4",
            "1.1.1.1",
            "--ipv6",
            "2606:4700:4700::1111",
        ])
        .output()
        .unwrap();
    assert!(add.status.success());

    let output = binary()
        .args([
            "guide",
            "--store",
            store.to_str().unwrap(),
            "--package",
            "flatpak",
            "--profile-id",
            "local",
        ])
        .output()
        .unwrap();

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("Guided settings"));
    assert!(stdout.contains("does not change DNS"));
    assert!(stdout.contains("Copy DNS servers: 1.1.1.1, 2606:4700:4700::1111"));
    assert!(stdout.contains("Retest with current/system resolver validation when supported"));
}

#[test]
fn cli_guide_can_render_vietnamese_guided_settings() {
    let store = temp_path("guide-store-vi");
    let add = binary()
        .args([
            "profile-add",
            "--store",
            store.to_str().unwrap(),
            "--id",
            "local",
            "--name",
            "Local DNS",
            "--ipv4",
            "1.1.1.1",
        ])
        .output()
        .unwrap();
    assert!(add.status.success());

    let output = binary()
        .args([
            "guide",
            "--store",
            store.to_str().unwrap(),
            "--package",
            "flatpak",
            "--profile-id",
            "local",
            "--lang",
            "vi",
        ])
        .output()
        .unwrap();

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("Hướng dẫn cài đặt"));
    assert!(stdout.contains("Gói: Flatpak"));
    assert!(stdout.contains("Không tự động đổi DNS"));
    assert!(stdout.contains("Sao chép DNS server: 1.1.1.1"));
}

#[test]
fn cli_guide_for_native_power_reports_the_fail_closed_state() {
    let store = temp_path("guide-native");

    let output = binary()
        .args([
            "guide",
            "--store",
            store.to_str().unwrap(),
            "--package",
            "deb",
            "--network-manager",
            "--polkit",
        ])
        .output()
        .unwrap();

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("Native Power unavailable"));
    assert!(stdout.contains("unavailable in this build"));
    assert!(stdout.contains("NetworkManager"));
    assert!(stdout.contains("systemd-resolved"));
    assert!(stdout.contains("polkit D-Bus service"));
    assert!(!stdout.contains("Copy DNS servers:"));
}

#[test]
fn cli_detect_renders_capability_report_from_mocked_snapshot() {
    let output = binary()
        .args([
            "detect",
            "--mock-env",
            "FLATPAK_ID=com.example.DNSPilot",
            "--mock-command",
            "nmcli",
            "--mock-command",
            "pkcheck",
        ])
        .output()
        .unwrap();

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("DNS Pilot Linux Debug Report"));
    assert!(stdout.contains("Package: Flatpak"));
    assert!(stdout.contains("Apply path: Guided settings"));
    assert!(stdout.contains("Real DNS apply: not available"));
}

#[test]
fn cli_permissions_renders_localized_package_permission_plan() {
    let output = binary()
        .args(["permissions", "--package", "flatpak", "--lang", "vi"])
        .output()
        .unwrap();

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("Quyền"));
    assert!(stdout.contains("Package: Flatpak"));
    assert!(stdout.contains("network [required]"));
    assert!(stdout.contains("system DNS mutation [not requested]"));
    assert!(stdout.contains("does not change DNS automatically"));
}

#[test]
fn cli_app_model_renders_main_window_sections_without_tray_requirement() {
    let output = binary()
        .args([
            "app-model",
            "--package",
            "deb",
            "--network-manager",
            "--polkit",
            "--system-resolver-probe",
            "--lang",
            "en",
        ])
        .output()
        .unwrap();

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("DNS Pilot"));
    assert!(stdout.contains("Tray: optional"));
    assert!(stdout.contains("Benchmark"));
    assert!(stdout.contains("Profiles"));
    assert!(stdout.contains("Diagnostics"));
    assert!(!stdout.contains("Apply with native helper [enabled]"));
}

#[test]
fn cli_app_model_localizes_vietnamese_help_copy() {
    let output = binary()
        .args(["app-model", "--package", "flatpak", "--lang", "vi"])
        .output()
        .unwrap();

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("Tray: optional"));
    assert!(stdout.contains("Tray không bắt buộc"));
    assert!(stdout.contains("Chạy đo kiểm"));
    assert!(stdout.contains("Hồ sơ DNS"));
    assert!(stdout.contains("Thêm, sửa, xoá"));
    assert!(stdout.contains("Không tự động đổi DNS hệ thống"));
}

#[test]
fn cli_publish_check_localizes_vietnamese_release_steps() {
    let output = binary()
        .args(["publish-check", "--package", "snap", "--lang", "vi"])
        .output()
        .unwrap();

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("Gói: Snap"));
    assert!(stdout.contains("Cổng tự động:"));
    assert!(stdout.contains("Kiểm thử gói cục bộ:"));
    assert!(stdout.contains("Cổng thủ công:"));
    assert!(stdout.contains("Ghi chú an toàn:"));
    assert!(stdout.contains("không tự động đổi DNS hệ thống"));
}

#[test]
fn cli_apply_plan_rejects_native_power_until_the_service_is_verified() {
    let store = temp_path("apply-plan");
    let add = binary()
        .args([
            "profile-add",
            "--store",
            store.to_str().unwrap(),
            "--id",
            "local",
            "--name",
            "Local DNS",
            "--ipv4",
            "1.1.1.1",
            "--ipv6",
            "2606:4700:4700::1111",
        ])
        .output()
        .unwrap();
    assert!(add.status.success());

    let output = binary()
        .args([
            "apply-plan",
            "--store",
            store.to_str().unwrap(),
            "--package",
            "deb",
            "--network-manager",
            "--polkit",
            "--system-resolver-probe",
            "--profile-id",
            "local",
            "--resolver-family",
            "ipv4",
        ])
        .output()
        .unwrap();

    assert!(!output.status.success());
    let stderr = String::from_utf8(output.stderr).unwrap();
    assert!(stderr.contains("Native DNS apply is unavailable in this build"));
}

#[test]
fn cli_readiness_outputs_code_ready_and_manual_publish_requirements() {
    let output = binary().arg("readiness").output().unwrap();

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("DNS Pilot Linux Readiness"));
    assert!(stdout.contains("Code readiness: store-safe consumer work in progress"));
    assert!(stdout.contains("Packaging and publish checklist: ready"));
    assert!(stdout.contains("Manual/external requirements:"));
    assert!(stdout.contains("store credentials"));
}

#[test]
fn cli_publish_check_outputs_package_specific_manual_steps() {
    let flatpak = binary()
        .args(["publish-check", "--package", "flatpak", "--lang", "vi"])
        .output()
        .unwrap();

    assert!(flatpak.status.success());
    let stdout = String::from_utf8(flatpak.stdout).unwrap();
    assert!(stdout.contains("DNS Pilot Linux Publish Check"));
    assert!(stdout.contains("Gói: Flatpak"));
    assert!(stdout.contains("Cổng tự động"));
    assert!(stdout.contains("Flatpak Builder"));
    assert!(stdout.contains("Flathub credentials"));
    assert!(stdout.contains("không tự động đổi DNS hệ thống"));

    let deb = binary()
        .args([
            "publish-check",
            "--package",
            "deb",
            "--network-manager",
            "--polkit",
            "--system-resolver-probe",
        ])
        .output()
        .unwrap();

    assert!(deb.status.success());
    let stdout = String::from_utf8(deb.stdout).unwrap();
    assert!(stdout.contains("Package: deb"));
    assert!(stdout.contains("apps/linux/scripts/build-packages.sh deb"));
    assert!(stdout.contains("no native helper, polkit policy, or automatic DNS mutation"));
    assert!(stdout.contains("real Linux package QA"));
}

#[test]
fn cli_publish_check_all_outputs_every_package_lane() {
    let output = binary()
        .args(["publish-check", "--package", "all", "--lang", "en"])
        .output()
        .unwrap();

    assert!(output.status.success());
    let stdout = String::from_utf8(output.stdout).unwrap();
    assert!(stdout.contains("DNS Pilot Linux Publish Check"));
    assert!(stdout.contains("cargo build --release -p dnspilot-cli"));
    assert!(stdout.contains("Package: Flatpak"));
    assert!(stdout.contains("Package: Snap"));
    assert!(stdout.contains("Package: deb"));
    assert!(stdout.contains("Package: rpm"));
    assert!(stdout.contains("Flatpak is benchmark/guidance only"));
    assert!(stdout.contains("Snap is benchmark/guidance only"));
    assert!(stdout.contains("deb is benchmark/guidance first"));
    assert!(stdout.contains("rpm is benchmark/guidance first"));
}

#[cfg(unix)]
fn make_executable(path: &std::path::Path) {
    use std::os::unix::fs::PermissionsExt;

    let mut permissions = std::fs::metadata(path).unwrap().permissions();
    permissions.set_mode(0o755);
    std::fs::set_permissions(path, permissions).unwrap();
}

#[cfg(not(unix))]
fn make_executable(_path: &std::path::Path) {}
