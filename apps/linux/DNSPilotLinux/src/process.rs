use crate::capabilities::BenchmarkMode;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProcessStepId {
    DetectCapabilities,
    PrepareBenchmark,
    RunDnsBenchmark,
    RunTcpProbe,
    ValidateSystemResolver,
    BuildDiagnostics,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProcessStatus {
    Idle,
    Running,
    Success,
    Failed,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProcessStepViewModel {
    pub id: ProcessStepId,
    pub label: String,
    pub status: ProcessStatus,
    pub detail: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ResolverProgressViewModel {
    pub id: String,
    pub label: String,
    pub status: ProcessStatus,
    pub detail: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LinuxBenchmarkProcessViewModel {
    pub mode: BenchmarkMode,
    pub steps: Vec<ProcessStepViewModel>,
    pub resolvers: Vec<ResolverProgressViewModel>,
}

impl LinuxBenchmarkProcessViewModel {
    pub fn new(mode: BenchmarkMode, resolvers: Vec<(&str, &str)>) -> Self {
        let steps = steps_for_mode(mode)
            .into_iter()
            .map(|id| ProcessStepViewModel {
                id,
                label: step_label(id).to_string(),
                status: ProcessStatus::Idle,
                detail: None,
            })
            .collect();
        let resolvers = resolvers
            .into_iter()
            .map(|(id, label)| ResolverProgressViewModel {
                id: id.to_string(),
                label: label.to_string(),
                status: ProcessStatus::Idle,
                detail: None,
            })
            .collect();

        Self {
            mode,
            steps,
            resolvers,
        }
    }

    pub fn start_step(&mut self, step_id: ProcessStepId) {
        self.update_step(step_id, ProcessStatus::Running, None);
    }

    pub fn complete_step(&mut self, step_id: ProcessStepId, detail: impl Into<String>) {
        self.update_step(step_id, ProcessStatus::Success, Some(detail.into()));
    }

    pub fn fail_step(&mut self, step_id: ProcessStepId, detail: impl Into<String>) {
        self.update_step(step_id, ProcessStatus::Failed, Some(detail.into()));
    }

    pub fn complete_resolver(&mut self, resolver_id: &str, detail: impl Into<String>) {
        self.update_resolver(resolver_id, ProcessStatus::Success, Some(detail.into()));
    }

    pub fn fail_resolver(&mut self, resolver_id: &str, detail: impl Into<String>) {
        self.update_resolver(resolver_id, ProcessStatus::Failed, Some(detail.into()));
    }

    pub fn overall_status(&self) -> ProcessStatus {
        let statuses = self
            .steps
            .iter()
            .map(|step| step.status)
            .chain(self.resolvers.iter().map(|resolver| resolver.status));
        let statuses: Vec<ProcessStatus> = statuses.collect();
        if statuses.contains(&ProcessStatus::Failed) {
            ProcessStatus::Failed
        } else if statuses.contains(&ProcessStatus::Running) {
            ProcessStatus::Running
        } else if statuses
            .iter()
            .all(|status| *status == ProcessStatus::Success)
        {
            ProcessStatus::Success
        } else if statuses.iter().all(|status| *status == ProcessStatus::Idle) {
            ProcessStatus::Idle
        } else {
            ProcessStatus::Running
        }
    }

    pub fn step_status(&self, step_id: ProcessStepId) -> Option<ProcessStatus> {
        self.steps
            .iter()
            .find(|step| step.id == step_id)
            .map(|step| step.status)
    }

    fn update_step(
        &mut self,
        step_id: ProcessStepId,
        status: ProcessStatus,
        detail: Option<String>,
    ) {
        if let Some(step) = self.steps.iter_mut().find(|step| step.id == step_id) {
            step.status = status;
            step.detail = detail;
        }
    }

    fn update_resolver(
        &mut self,
        resolver_id: &str,
        status: ProcessStatus,
        detail: Option<String>,
    ) {
        if let Some(resolver) = self
            .resolvers
            .iter_mut()
            .find(|resolver| resolver.id == resolver_id)
        {
            resolver.status = status;
            resolver.detail = detail;
        }
    }
}

pub fn status_label(status: ProcessStatus) -> &'static str {
    match status {
        ProcessStatus::Idle => "idle",
        ProcessStatus::Running => "running",
        ProcessStatus::Success => "success",
        ProcessStatus::Failed => "failed",
    }
}

fn steps_for_mode(mode: BenchmarkMode) -> Vec<ProcessStepId> {
    match mode {
        BenchmarkMode::DnsOnly => vec![
            ProcessStepId::DetectCapabilities,
            ProcessStepId::PrepareBenchmark,
            ProcessStepId::RunDnsBenchmark,
            ProcessStepId::BuildDiagnostics,
        ],
        BenchmarkMode::DnsAndTcp => vec![
            ProcessStepId::DetectCapabilities,
            ProcessStepId::PrepareBenchmark,
            ProcessStepId::RunDnsBenchmark,
            ProcessStepId::RunTcpProbe,
            ProcessStepId::BuildDiagnostics,
        ],
        BenchmarkMode::CurrentSystemResolver => vec![
            ProcessStepId::DetectCapabilities,
            ProcessStepId::PrepareBenchmark,
            ProcessStepId::ValidateSystemResolver,
            ProcessStepId::BuildDiagnostics,
        ],
    }
}

fn step_label(step_id: ProcessStepId) -> &'static str {
    match step_id {
        ProcessStepId::DetectCapabilities => "Detect capabilities",
        ProcessStepId::PrepareBenchmark => "Prepare benchmark",
        ProcessStepId::RunDnsBenchmark => "Run DNS benchmark",
        ProcessStepId::RunTcpProbe => "Run TCP probe",
        ProcessStepId::ValidateSystemResolver => "Validate current resolver",
        ProcessStepId::BuildDiagnostics => "Build diagnostics",
    }
}
