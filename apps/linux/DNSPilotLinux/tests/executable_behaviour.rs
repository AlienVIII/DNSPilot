use dnspilot_linux_shell::executable::{
    resolve_core_cli_with, CoreCliResolutionError, CoreCliSource,
};
use std::path::{Path, PathBuf};

fn executable_probe(paths: &[&str]) -> impl Fn(&Path) -> bool {
    let paths = paths.iter().map(PathBuf::from).collect::<Vec<_>>();
    move |candidate| paths.iter().any(|path| path == candidate)
}

#[test]
fn environment_override_wins_over_packaged_and_path_candidates() {
    let resolution = resolve_core_cli_with(
        Some("/opt/dnspilot/custom-cli"),
        Some(Path::new("/app/bin/dnspilot-linux-gui")),
        Some("/usr/local/bin:/usr/bin"),
        executable_probe(&[
            "/opt/dnspilot/custom-cli",
            "/app/bin/dnspilot-cli",
            "/usr/bin/dnspilot-cli",
        ]),
    )
    .expect("environment override should resolve");

    assert_eq!(resolution.path, PathBuf::from("/opt/dnspilot/custom-cli"));
    assert_eq!(resolution.source, CoreCliSource::EnvironmentOverride);
}

#[test]
fn packaged_sibling_is_used_for_store_and_native_install_layouts() {
    let resolution = resolve_core_cli_with(
        None,
        Some(Path::new("/app/bin/dnspilot-linux-gui")),
        Some("/usr/local/bin:/usr/bin"),
        executable_probe(&["/app/bin/dnspilot-cli"]),
    )
    .expect("packaged sibling should resolve");

    assert_eq!(resolution.path, PathBuf::from("/app/bin/dnspilot-cli"));
    assert_eq!(resolution.source, CoreCliSource::PackagedSibling);
}

#[test]
fn path_lookup_is_the_last_supported_fallback() {
    let resolution = resolve_core_cli_with(
        None,
        Some(Path::new("/tmp/dnspilot-linux-gui")),
        Some("/usr/local/bin:/usr/bin"),
        executable_probe(&["/usr/bin/dnspilot-cli"]),
    )
    .expect("PATH candidate should resolve");

    assert_eq!(resolution.path, PathBuf::from("/usr/bin/dnspilot-cli"));
    assert_eq!(resolution.source, CoreCliSource::Path);
}

#[test]
fn missing_engine_returns_actionable_error() {
    let error = resolve_core_cli_with(
        None,
        Some(Path::new("/app/bin/dnspilot-linux-gui")),
        Some("/usr/bin"),
        |_| false,
    )
    .expect_err("missing engine must be reported");

    assert_eq!(error, CoreCliResolutionError::NotFound);
    assert!(error.to_string().contains("DNSPILOT_CLI_PATH"));
}

#[test]
fn invalid_environment_override_does_not_silently_use_another_engine() {
    let error = resolve_core_cli_with(
        Some("/opt/dnspilot/missing-cli"),
        Some(Path::new("/app/bin/dnspilot-linux-gui")),
        Some("/usr/bin"),
        executable_probe(&["/app/bin/dnspilot-cli", "/usr/bin/dnspilot-cli"]),
    )
    .expect_err("an explicit invalid override must fail closed");

    assert_eq!(
        error,
        CoreCliResolutionError::InvalidOverride(PathBuf::from("/opt/dnspilot/missing-cli"))
    );
}
