use crate::capabilities::LinuxCapabilityViewModel;
use crate::process::{status_label, LinuxBenchmarkProcessViewModel};

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
