use crate::capabilities::LinuxCapabilityViewModel;
use crate::process::{status_label, LinuxBenchmarkProcessViewModel};

pub fn redact_debug_report(report: &str, private_domains: &[String]) -> String {
    let mut redacted = report.to_string();
    for domain in private_domains {
        if !domain.trim().is_empty() {
            redacted = redacted.replace(domain, "[redacted-domain]");
        }
    }
    redact_home_path(&redact_home_path(&redacted, "/home/"), "/Users/")
}

fn redact_home_path(value: &str, root: &str) -> String {
    let mut result = String::with_capacity(value.len());
    let mut remainder = value;
    while let Some(index) = remainder.find(root) {
        result.push_str(&remainder[..index]);
        result.push_str(root);
        remainder = &remainder[index + root.len()..];
        let user_end = remainder
            .find(|character: char| character == '/' || character.is_ascii_whitespace())
            .unwrap_or(remainder.len());
        if user_end == 0 {
            continue;
        }
        result.push_str("[redacted]");
        remainder = &remainder[user_end..];
    }
    result.push_str(remainder);
    result
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LinuxDiagnosticReport {
    pub distro: String,
    pub capability: LinuxCapabilityViewModel,
    pub process: LinuxBenchmarkProcessViewModel,
}

impl LinuxDiagnosticReport {
    pub fn new(
        distro: impl Into<String>,
        capability: LinuxCapabilityViewModel,
        process: LinuxBenchmarkProcessViewModel,
    ) -> Self {
        Self {
            distro: distro.into(),
            capability,
            process,
        }
    }

    pub fn to_copyable_text(&self) -> String {
        let mut lines = vec![
            "DNS Pilot Linux Debug Report".to_string(),
            format!("Distro: {}", self.distro),
            format!("Package: {}", self.capability.package_kind.label()),
            format!("Benchmark mode: {}", self.process.mode.label()),
            format!("Apply path: {}", self.capability.apply_path.label()),
            format!(
                "Real DNS apply: {}",
                if self.capability.can_apply_real_dns {
                    "available"
                } else {
                    "not available"
                }
            ),
            format!(
                "System resolver validation: {}",
                if self.capability.can_validate_current_system_resolver {
                    "available"
                } else {
                    "not available"
                }
            ),
            format!(
                "Tray: {}",
                if self.capability.tray_required {
                    "required"
                } else {
                    "optional"
                }
            ),
            format!("Overall: {}", status_label(self.process.overall_status())),
            String::new(),
            "Steps:".to_string(),
        ];

        for step in &self.process.steps {
            lines.push(format!(
                "- {}: {}{}",
                step.label,
                status_label(step.status),
                detail_suffix(step.detail.as_deref())
            ));
        }

        lines.push(String::new());
        lines.push("Resolvers:".to_string());
        for resolver in &self.process.resolvers {
            lines.push(format!(
                "- {}: {}{}",
                resolver.label,
                status_label(resolver.status),
                detail_suffix(resolver.detail.as_deref())
            ));
        }

        if !self.capability.notes.is_empty() {
            lines.push(String::new());
            lines.push("Capability notes:".to_string());
            for note in &self.capability.notes {
                lines.push(format!("- {note}"));
            }
        }

        lines.join("\n")
    }
}

fn detail_suffix(detail: Option<&str>) -> String {
    match detail {
        Some(detail) if !detail.is_empty() => format!(" - {detail}"),
        _ => String::new(),
    }
}
