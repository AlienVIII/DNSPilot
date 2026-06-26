use crate::capabilities::{LinuxEnvironmentProbe, LinuxPackageKind};
use std::env;
use std::path::Path;
use std::process::Command;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LinuxDetectionSnapshot {
    pub env: Vec<(String, String)>,
    pub existing_paths: Vec<String>,
    pub available_commands: Vec<String>,
}

impl LinuxDetectionSnapshot {
    pub fn empty() -> Self {
        Self {
            env: Vec::new(),
            existing_paths: Vec::new(),
            available_commands: Vec::new(),
        }
    }

    pub fn with_env(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.env.push((key.into(), value.into()));
        self
    }

    pub fn with_path(mut self, path: impl Into<String>) -> Self {
        self.existing_paths.push(path.into());
        self
    }

    pub fn with_command(mut self, command: impl Into<String>) -> Self {
        self.available_commands.push(command.into());
        self
    }
}

pub fn detect_linux_environment_from_snapshot(
    snapshot: &LinuxDetectionSnapshot,
) -> LinuxEnvironmentProbe {
    let package_kind = detect_package_kind(snapshot);
    let network_manager_available = snapshot.has_command("nmcli")
        || snapshot.has_path("/usr/bin/nmcli")
        || snapshot.has_path("/run/NetworkManager");
    let systemd_resolved_available = snapshot.has_command("resolvectl")
        || snapshot.has_path("/run/systemd/resolve/stub-resolv.conf")
        || snapshot.has_path("/run/systemd/resolve/resolv.conf");
    let polkit_available = snapshot.has_command("pkcheck") || snapshot.has_path("/usr/bin/pkcheck");
    let system_resolver_probe_available = snapshot.has_path("/etc/resolv.conf")
        || snapshot.has_command("getent")
        || systemd_resolved_available;

    LinuxEnvironmentProbe {
        package_kind,
        network_manager_available,
        systemd_resolved_available,
        polkit_available,
        system_resolver_probe_available,
    }
}

pub fn detect_linux_environment() -> LinuxEnvironmentProbe {
    detect_linux_environment_from_snapshot(&runtime_snapshot())
}

impl LinuxDetectionSnapshot {
    fn env_value(&self, key: &str) -> Option<&str> {
        self.env
            .iter()
            .find(|(candidate, _)| candidate == key)
            .map(|(_, value)| value.as_str())
    }

    fn has_env(&self, key: &str) -> bool {
        self.env_value(key).is_some()
    }

    fn has_path(&self, path: &str) -> bool {
        self.existing_paths
            .iter()
            .any(|candidate| candidate == path)
    }

    fn has_command(&self, command: &str) -> bool {
        self.available_commands
            .iter()
            .any(|candidate| candidate == command)
    }
}

fn detect_package_kind(snapshot: &LinuxDetectionSnapshot) -> LinuxPackageKind {
    if let Some(value) = snapshot.env_value("DNSPILOT_LINUX_PACKAGE") {
        if let Some(kind) = parse_package_kind(value) {
            return kind;
        }
    }

    if snapshot.has_env("FLATPAK_ID") || snapshot.has_path("/.flatpak-info") {
        LinuxPackageKind::Flatpak
    } else if snapshot.has_env("SNAP") || snapshot.has_env("SNAP_NAME") {
        LinuxPackageKind::Snap
    } else if snapshot.has_path("/etc/fedora-release")
        || snapshot.has_path("/etc/redhat-release")
        || snapshot.has_path("/etc/centos-release")
        || snapshot.has_command("rpm")
    {
        LinuxPackageKind::Rpm
    } else {
        LinuxPackageKind::Deb
    }
}

fn parse_package_kind(value: &str) -> Option<LinuxPackageKind> {
    match value {
        "flatpak" => Some(LinuxPackageKind::Flatpak),
        "snap" => Some(LinuxPackageKind::Snap),
        "deb" => Some(LinuxPackageKind::Deb),
        "rpm" => Some(LinuxPackageKind::Rpm),
        _ => None,
    }
}

fn runtime_snapshot() -> LinuxDetectionSnapshot {
    let mut snapshot = LinuxDetectionSnapshot::empty();
    for key in ["DNSPILOT_LINUX_PACKAGE", "FLATPAK_ID", "SNAP", "SNAP_NAME"] {
        if let Ok(value) = env::var(key) {
            snapshot = snapshot.with_env(key, value);
        }
    }
    for path in [
        "/.flatpak-info",
        "/etc/fedora-release",
        "/etc/redhat-release",
        "/etc/centos-release",
        "/etc/resolv.conf",
        "/run/NetworkManager",
        "/run/systemd/resolve/stub-resolv.conf",
        "/run/systemd/resolve/resolv.conf",
        "/usr/bin/nmcli",
        "/usr/bin/pkcheck",
    ] {
        if Path::new(path).exists() {
            snapshot = snapshot.with_path(path);
        }
    }
    for command in ["nmcli", "resolvectl", "pkcheck", "getent", "rpm"] {
        if command_exists(command) {
            snapshot = snapshot.with_command(command);
        }
    }
    snapshot
}

fn command_exists(command: &str) -> bool {
    Command::new("sh")
        .arg("-c")
        .arg(format!("command -v {command} >/dev/null 2>&1"))
        .status()
        .map(|status| status.success())
        .unwrap_or(false)
}
