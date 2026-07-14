use dnspilot_linux_shell::app::LinuxAppSession;
use dnspilot_linux_shell::benchmark::{
    benchmark_process_for_plan, benchmark_running_process_for_plan, build_core_cli_command,
    LinuxBenchmarkPlan, LinuxBenchmarkRunResult,
};
use dnspilot_linux_shell::capabilities::{
    available_benchmark_modes, capability_view_model, BenchmarkMode, LinuxCapabilityViewModel,
};
use dnspilot_linux_shell::core_adapter::{
    CoreCliAdapter, LinuxDataPaths, ProcessCoreCliCommandRunner,
};
use dnspilot_linux_shell::detect::detect_linux_environment;
use dnspilot_linux_shell::executable::{
    resolve_core_cli, CoreCliResolution, CoreCliResolutionError,
};
use dnspilot_linux_shell::i18n::{localized_text, Language, TextKey};
use dnspilot_linux_shell::native_app::{build_native_app_model, NativeAppSectionKind};
use dnspilot_linux_shell::native_power::{build_native_apply_plan, render_native_apply_plan};
use dnspilot_linux_shell::permissions::{permission_plan, render_permission_plan};
use dnspilot_linux_shell::preferences::{
    load_language_preference, save_language_preference, LanguagePreference,
};
use dnspilot_linux_shell::process::{
    process_rows, status_label, LinuxBenchmarkProcessViewModel, ProcessRowKind, ProcessStatus,
};
use dnspilot_linux_shell::profiles::PlainDnsProfile;
use dnspilot_linux_shell::result::{
    decode_benchmark_decision, BenchmarkDecision, PrimaryResultAction,
};
use dnspilot_linux_shell::settings::{
    build_guided_settings_plan, dns_record_family_controls, render_guided_settings_plan,
    resolver_address_family_controls, settings_actions, DnsRecordFamily, ResolverAddressFamily,
    SettingsActionKind,
};
use dnspilot_linux_shell::suites::{suite_catalog_from_core, SuiteViewModel};
use dnspilot_linux_shell::worker::{spawn_benchmark_worker, BenchmarkWorker, BenchmarkWorkerPoll};
use eframe::egui;
use std::env;
use std::fs;
use std::path::PathBuf;
use std::time::Duration;

fn main() -> eframe::Result<()> {
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([1040.0, 720.0])
            .with_min_inner_size([760.0, 560.0]),
        ..Default::default()
    };

    eframe::run_native(
        "DNS Pilot",
        options,
        Box::new(|_creation_context| Ok(Box::new(DnsPilotGui::new()))),
    )
}

struct DnsPilotGui {
    language: Language,
    language_preference: LanguagePreference,
    capability: LinuxCapabilityViewModel,
    active_section: NativeAppSectionKind,
    profiles: Vec<PlainDnsProfile>,
    suites: Vec<SuiteViewModel>,
    selected_profile_ids: Vec<String>,
    selected_mode: BenchmarkMode,
    selected_suite_id: Option<String>,
    resolver_family: ResolverAddressFamily,
    record_family: DnsRecordFamily,
    custom_domains: String,
    core_cli: Result<CoreCliResolution, CoreCliResolutionError>,
    status: String,
    diagnostics: String,
    result: Option<BenchmarkDecision>,
    process: Option<LinuxBenchmarkProcessViewModel>,
    benchmark_worker: Option<BenchmarkWorker>,
    show_tutorial: bool,
    show_settings: bool,
    profile_id: String,
    profile_name: String,
    profile_ipv4: String,
    profile_ipv6: String,
    database_path: PathBuf,
    language_preference_path: PathBuf,
    settings_profile_id: String,
    settings_output: String,
}

impl DnsPilotGui {
    fn new() -> Self {
        let capability = capability_view_model(detect_linux_environment());
        let data_paths = LinuxDataPaths::from_environment();
        let database_path = data_paths.core_database_path();
        let language_preference_path = data_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("language-preference");
        let language_preference = load_language_preference(&language_preference_path);
        let language = language_preference.resolve(env::var("LANG").ok().as_deref());
        let setup_seen_path = setup_tutorial_seen_path();
        let show_tutorial = !has_seen_setup_tutorial(&setup_seen_path);
        let core_cli = resolve_core_cli();
        let (profiles, suites, status) =
            load_core_state(&core_cli, &database_path, &data_paths.legacy_profile_path());
        let settings_profile_id = profiles
            .first()
            .map(|profile| profile.id.clone())
            .unwrap_or_default();
        let selected_profile_ids = profiles.iter().map(|profile| profile.id.clone()).collect();
        let selected_suite_id = suites.first().map(|suite| suite.id.clone());

        Self {
            language,
            language_preference,
            capability,
            active_section: NativeAppSectionKind::CheckDns,
            profiles,
            suites,
            selected_profile_ids,
            selected_mode: BenchmarkMode::DnsOnly,
            selected_suite_id,
            resolver_family: ResolverAddressFamily::Auto,
            record_family: DnsRecordFamily::AAndAaaa,
            custom_domains: String::new(),
            core_cli,
            status,
            diagnostics: String::new(),
            result: None,
            process: None,
            benchmark_worker: None,
            show_tutorial,
            show_settings: false,
            profile_id: String::new(),
            profile_name: String::new(),
            profile_ipv4: String::new(),
            profile_ipv6: String::new(),
            database_path,
            language_preference_path,
            settings_profile_id,
            settings_output: String::new(),
        }
    }

    fn build_session(&self) -> LinuxAppSession {
        let mut session = LinuxAppSession::new(
            self.capability.clone(),
            self.suites.clone(),
            self.profiles.clone(),
        );
        let _ = session.select_mode(self.selected_mode);
        session.set_selected_profiles(self.selected_profile_ids.clone());
        session.selected_suite_id = self.selected_suite_id.clone();
        session.resolver_address_family = self.resolver_family;
        session.record_family = self.record_family;
        session.set_custom_domains(split_words(&self.custom_domains));
        session
    }

    fn set_language_preference(&mut self, preference: LanguagePreference) {
        self.language_preference = preference;
        self.language = preference.resolve(env::var("LANG").ok().as_deref());
        if let Err(error) = save_language_preference(&self.language_preference_path, preference) {
            self.status = format!("Could not save language preference: {error}");
        }
    }

    fn build_plan(&self) -> Result<LinuxBenchmarkPlan, Vec<String>> {
        let mut plan = self.build_session().build_plan()?;
        let database_path = self.database_path.to_string_lossy().into_owned();
        plan.profile_db = Some(database_path.clone());
        plan.suite_db = Some(database_path.clone());
        plan.history_db = Some(database_path);
        Ok(plan)
    }

    fn save_profile_from_form(&mut self) {
        let profile = PlainDnsProfile {
            id: self.profile_id.trim().to_string(),
            name: self.profile_name.trim().to_string(),
            ipv4_servers: split_words(&self.profile_ipv4),
            ipv6_servers: split_words(&self.profile_ipv6),
        };
        let update = self.profiles.iter().any(|item| item.id == profile.id);
        match self.core_adapter().and_then(|mut adapter| {
            adapter
                .save_plain_profile(&profile, update)
                .map_err(|error| format!("{error:?}"))?;
            adapter
                .load_profiles()
                .map(|profiles| profiles.into_iter().map(Into::into).collect())
                .map_err(|error| format!("{error:?}"))
        }) {
            Ok(profiles) => {
                self.profiles = profiles;
                if self.settings_profile_id.is_empty() {
                    self.settings_profile_id = self
                        .profiles
                        .first()
                        .map(|profile| profile.id.clone())
                        .unwrap_or_default();
                }
                self.status = "Profile saved by core storage".to_string();
            }
            Err(error) => {
                self.status = format!("Profile save failed: {error:?}");
            }
        }
    }

    fn delete_profile(&mut self, profile_id: &str) {
        match self.core_adapter().and_then(|mut adapter| {
            adapter
                .delete_profile(profile_id)
                .map_err(|error| format!("{error:?}"))?;
            adapter
                .load_profiles()
                .map(|profiles| profiles.into_iter().map(Into::into).collect())
                .map_err(|error| format!("{error:?}"))
        }) {
            Ok(profiles) => {
                self.profiles = profiles;
                self.selected_profile_ids.retain(|id| id != profile_id);
                if self.settings_profile_id == profile_id {
                    self.settings_profile_id = self
                        .profiles
                        .first()
                        .map(|profile| profile.id.clone())
                        .unwrap_or_default();
                }
                self.status = "Profile deleted by core storage".to_string();
            }
            Err(error) => self.status = format!("Profile delete failed: {error:?}"),
        }
    }

    fn core_adapter(&self) -> Result<CoreCliAdapter<ProcessCoreCliCommandRunner>, String> {
        let resolution = self.core_cli.as_ref().map_err(ToString::to_string)?;
        Ok(CoreCliAdapter::new(
            resolution.path.to_string_lossy(),
            self.database_path.clone(),
            ProcessCoreCliCommandRunner,
        ))
    }

    fn fill_profile_form(&mut self, profile: &PlainDnsProfile) {
        self.profile_id = profile.id.clone();
        self.profile_name = profile.name.clone();
        self.profile_ipv4 = profile.ipv4_servers.join(", ");
        self.profile_ipv6 = profile.ipv6_servers.join(", ");
    }

    fn plan_benchmark(&mut self) {
        if self.benchmark_worker.is_some() {
            self.status = "Benchmark is already running".to_string();
            return;
        }
        let Some(core_cli_path) = self.resolved_core_cli_path() else {
            return;
        };
        match self.build_plan() {
            Ok(plan) => {
                let command = build_core_cli_command(core_cli_path, &plan);
                self.process = Some(benchmark_process_for_plan(&plan));
                self.diagnostics = format!(
                    "Core command:\n{} {}",
                    command.program,
                    command.args.join(" ")
                );
                self.status = "Benchmark plan ready".to_string();
            }
            Err(issues) => {
                self.process = None;
                self.status = issues.join("; ");
            }
        }
    }

    fn run_benchmark(&mut self) {
        if self.benchmark_worker.is_some() {
            self.status = "Benchmark is already running".to_string();
            return;
        }
        let Some(core_cli_path) = self.resolved_core_cli_path() else {
            return;
        };
        match self.build_plan() {
            Ok(plan) => {
                let running_process = benchmark_running_process_for_plan(&plan);
                match spawn_benchmark_worker(
                    core_cli_path,
                    "linux-gui".to_string(),
                    self.capability.clone(),
                    plan,
                ) {
                    Ok(worker) => {
                        self.process = Some(running_process);
                        self.benchmark_worker = Some(worker);
                        self.diagnostics =
                            "Benchmark running. Final diagnostics will appear here.".to_string();
                        self.status = "Benchmark running".to_string();
                    }
                    Err(error) => {
                        let detail = error.to_string();
                        let mut process = running_process;
                        process.fail_unfinished(&detail);
                        self.process = Some(process);
                        self.status = detail;
                    }
                }
            }
            Err(issues) => {
                self.process = None;
                self.status = issues.join("; ");
            }
        }
    }

    fn poll_benchmark_worker(&mut self) -> bool {
        let Some(worker) = &self.benchmark_worker else {
            return false;
        };

        match worker.poll() {
            BenchmarkWorkerPoll::Running => true,
            BenchmarkWorkerPoll::Progress(process) => {
                self.process = Some(process);
                true
            }
            BenchmarkWorkerPoll::Finished(result) => {
                self.benchmark_worker = None;
                self.finish_benchmark(result);
                false
            }
            BenchmarkWorkerPoll::Disconnected => {
                self.benchmark_worker = None;
                let detail = "Benchmark worker stopped before returning a result";
                if let Some(process) = &mut self.process {
                    process.fail_unfinished(detail);
                }
                self.status = detail.to_string();
                false
            }
        }
    }

    fn finish_benchmark(&mut self, result: LinuxBenchmarkRunResult) {
        let overall_status = result.process.overall_status();
        self.process = Some(result.process);
        self.diagnostics = result.debug_report;
        if let Some(payload) = result.final_payload {
            self.result = decode_benchmark_decision(&payload, &self.capability).ok();
            self.diagnostics.push_str("\n\nFinal payload:\n");
            self.diagnostics.push_str(&payload);
        } else {
            self.result = None;
        }
        self.status = match result.error {
            Some(error) => format!("Benchmark failed: {error}"),
            None if overall_status == ProcessStatus::Failed => {
                "Benchmark finished with resolver failures".to_string()
            }
            None => "Benchmark finished".to_string(),
        };
    }

    fn resolved_core_cli_path(&mut self) -> Option<String> {
        match &self.core_cli {
            Ok(resolution) => Some(resolution.path.to_string_lossy().into_owned()),
            Err(error) => {
                self.status = error.to_string();
                None
            }
        }
    }
}

impl eframe::App for DnsPilotGui {
    fn ui(&mut self, ui: &mut egui::Ui, _frame: &mut eframe::Frame) {
        if self.poll_benchmark_worker() {
            ui.ctx().request_repaint_after(Duration::from_millis(50));
        }
        let ctx = ui.ctx().clone();
        ui.add_space(8.0);
        ui.horizontal(|ui| {
            ui.heading(localized_text(TextKey::AppTitle, self.language));
            ui.separator();
            ui.label(format!("Package: {}", self.capability.package_kind.label()));
            ui.separator();
            let mut language_preference = self.language_preference;
            ui.selectable_value(
                &mut language_preference,
                LanguagePreference::System,
                "System",
            );
            ui.selectable_value(&mut language_preference, LanguagePreference::English, "EN");
            ui.selectable_value(
                &mut language_preference,
                LanguagePreference::Vietnamese,
                "VI",
            );
            if language_preference != self.language_preference {
                self.set_language_preference(language_preference);
            }
            ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                if ui.button("Settings").clicked() {
                    self.show_settings = true;
                }
                if ui
                    .button("?")
                    .on_hover_text("Show setup tutorial")
                    .clicked()
                {
                    self.show_tutorial = true;
                }
            });
        });
        ui.separator();

        if self.show_tutorial {
            let mut tutorial_completed = false;
            egui::Window::new("DNSPilot Setup")
                .collapsible(false)
                .resizable(false)
                .open(&mut self.show_tutorial)
                .show(&ctx, |ui| {
                    ui.heading("Test, copy, retest");
                    ui.label("1. Run a benchmark.");
                    ui.label("2. Copy/open OS DNS settings.");
                    ui.label("3. Retest System DNS.");
                    ui.separator();
                    ui.label("Sandbox packages are guidance-first.");
                    ui.label("Power DNS apply stays explicit and package-gated.");
                    ui.horizontal(|ui| {
                        if ui.button("Skip").clicked() {
                            tutorial_completed = true;
                        }
                        if ui.button("Done").clicked() {
                            tutorial_completed = true;
                        }
                    });
                });
            if tutorial_completed {
                mark_setup_tutorial_seen(&setup_tutorial_seen_path());
                self.show_tutorial = false;
            }
        }

        if self.show_settings {
            let mut show_settings = self.show_settings;
            egui::Window::new(localized_text(TextKey::Settings, self.language))
                .open(&mut show_settings)
                .show(&ctx, |ui| {
                    self.settings_ui(ui);
                    ui.separator();
                    self.diagnostics_ui(ui);
                    ui.separator();
                    self.permissions_ui(ui);
                });
            self.show_settings = show_settings;
        }

        ui.horizontal(|ui| {
            ui.vertical(|ui| {
                ui.set_width(210.0);
                let model = build_native_app_model(&self.capability, self.language);
                ui.label(model.tray_note);
                ui.separator();
                for section in model.sections {
                    ui.selectable_value(&mut self.active_section, section.kind, section.title)
                        .on_hover_text(section.help_text);
                }
                ui.separator();
                ui.label(format!("Status: {}", self.status));
            });

            ui.separator();
            ui.vertical(|ui| match self.active_section {
                NativeAppSectionKind::CheckDns => self.benchmark_ui(ui),
                NativeAppSectionKind::Profiles => self.profiles_ui(ui),
                NativeAppSectionKind::History => self.history_ui(ui),
            });
        });
    }
}

impl DnsPilotGui {
    fn benchmark_ui(&mut self, ui: &mut egui::Ui) {
        ui.heading(localized_text(TextKey::Benchmark, self.language));
        ui.horizontal_wrapped(|ui| {
            for mode in available_benchmark_modes(&self.capability) {
                ui.radio_value(&mut self.selected_mode, mode, mode.label());
            }
        });

        ui.separator();
        ui.label(localized_text(TextKey::Profiles, self.language));
        for profile in &self.profiles {
            let mut selected = self.selected_profile_ids.contains(&profile.id);
            if ui.checkbox(&mut selected, &profile.name).changed() {
                if selected {
                    self.selected_profile_ids.push(profile.id.clone());
                } else {
                    self.selected_profile_ids.retain(|id| id != &profile.id);
                }
            }
        }

        ui.separator();
        egui::ComboBox::from_label("Suite")
            .selected_text(
                self.selected_suite_id
                    .clone()
                    .unwrap_or_else(|| "custom domains".to_string()),
            )
            .show_ui(ui, |ui| {
                ui.selectable_value(&mut self.selected_suite_id, None, "Custom domains only");
                for suite in &self.suites {
                    ui.selectable_value(
                        &mut self.selected_suite_id,
                        Some(suite.id.clone()),
                        &suite.name,
                    )
                    .on_hover_text(suite.domains.join(", "));
                }
            });
        ui.text_edit_singleline(&mut self.custom_domains)
            .on_hover_text("Optional extra domains separated by comma or whitespace.");

        ui.separator();
        ui.horizontal_wrapped(|ui| {
            for control in resolver_address_family_controls() {
                ui.radio_value(&mut self.resolver_family, control.value, control.label)
                    .on_hover_text(control.help_text);
            }
        });
        ui.horizontal_wrapped(|ui| {
            for control in dns_record_family_controls() {
                ui.radio_value(&mut self.record_family, control.value, control.label)
                    .on_hover_text(control.help_text);
            }
        });

        ui.separator();
        ui.horizontal(|ui| {
            ui.label("Engine");
            let engine_ready = self.core_cli.is_ok();
            let benchmark_idle = self.benchmark_worker.is_none();
            match &self.core_cli {
                Ok(resolution) => {
                    ui.colored_label(egui::Color32::from_rgb(40, 140, 80), "Ready")
                        .on_hover_text(format!(
                            "{} ({})",
                            resolution.path.display(),
                            resolution.source.label()
                        ));
                }
                Err(error) => {
                    ui.colored_label(egui::Color32::from_rgb(190, 60, 60), "Unavailable")
                        .on_hover_text(error.to_string());
                }
            }
            if ui
                .add_enabled(engine_ready && benchmark_idle, egui::Button::new("Plan"))
                .clicked()
            {
                self.plan_benchmark();
            }
            if ui
                .add_enabled(
                    engine_ready && benchmark_idle,
                    egui::Button::new(localized_text(TextKey::RunBenchmark, self.language)),
                )
                .clicked()
            {
                self.run_benchmark();
            }
            if ui
                .add_enabled(!benchmark_idle, egui::Button::new("Cancel"))
                .clicked()
            {
                if let Some(worker) = &self.benchmark_worker {
                    worker.cancel();
                    self.status = "Cancelling benchmark".to_string();
                }
            }
        });

        ui.separator();
        if let Some(result) = self.result.clone() {
            self.result_ui(ui, &result);
            ui.separator();
        }
        if let Some(process) = self
            .process
            .clone()
            .or_else(|| self.current_process_preview())
        {
            self.process_ui(ui, &process);
        }
    }

    fn profiles_ui(&mut self, ui: &mut egui::Ui) {
        ui.heading(localized_text(TextKey::ManageProfiles, self.language));
        let profiles = self.profiles.clone();
        egui::Grid::new("profiles_grid")
            .striped(true)
            .show(ui, |ui| {
                ui.strong("ID");
                ui.strong("Name");
                ui.strong("IPv4");
                ui.strong("IPv6");
                ui.end_row();

                for profile in &profiles {
                    ui.label(&profile.id);
                    ui.label(&profile.name);
                    ui.label(profile.ipv4_servers.join(", "));
                    ui.label(profile.ipv6_servers.join(", "));
                    if ui.button("Edit").clicked() {
                        self.fill_profile_form(profile);
                    }
                    if ui.button("Delete").clicked() {
                        self.delete_profile(&profile.id);
                    }
                    ui.end_row();
                }
            });

        ui.separator();
        ui.label("Add or edit profile");
        ui.horizontal(|ui| {
            ui.label("ID");
            ui.text_edit_singleline(&mut self.profile_id);
            ui.label("Name");
            ui.text_edit_singleline(&mut self.profile_name);
        });
        ui.horizontal(|ui| {
            ui.label("IPv4");
            ui.text_edit_singleline(&mut self.profile_ipv4);
            ui.label("IPv6");
            ui.text_edit_singleline(&mut self.profile_ipv6);
        });
        if ui.button("Save profile").clicked() {
            self.save_profile_from_form();
        }
    }

    fn settings_ui(&mut self, ui: &mut egui::Ui) {
        ui.heading(localized_text(TextKey::Settings, self.language));

        let profiles = self.profiles.clone();
        egui::ComboBox::from_label(localized_text(TextKey::Profiles, self.language))
            .selected_text(
                profiles
                    .iter()
                    .find(|profile| profile.id == self.settings_profile_id)
                    .map(|profile| profile.name.as_str())
                    .unwrap_or("No profile"),
            )
            .show_ui(ui, |ui| {
                for profile in &profiles {
                    ui.selectable_value(
                        &mut self.settings_profile_id,
                        profile.id.clone(),
                        &profile.name,
                    );
                }
            });

        ui.horizontal_wrapped(|ui| {
            for control in resolver_address_family_controls() {
                ui.radio_value(&mut self.resolver_family, control.value, control.label)
                    .on_hover_text(control.help_text);
            }
        });
        ui.separator();

        for action in settings_actions(&self.capability) {
            match action.kind {
                SettingsActionKind::GuidedSettings => {
                    if ui.button(action.label).clicked() {
                        if let Some(profile) = self.selected_settings_profile() {
                            match build_guided_settings_plan(
                                &self.capability,
                                &profile,
                                self.resolver_family,
                                self.language,
                            ) {
                                Ok(plan) => {
                                    ui.ctx().copy_text(plan.servers.join(", "));
                                    self.settings_output = render_guided_settings_plan(&plan);
                                    self.status = "DNS servers copied".to_string();
                                }
                                Err(error) => {
                                    self.status = format!("Guided settings unavailable: {error:?}");
                                }
                            }
                        } else {
                            self.status = "Select a DNS profile first".to_string();
                        }
                    }
                }
                SettingsActionKind::NativePowerApply => {
                    if ui.button(action.label).clicked() {
                        if let Some(profile) = self.selected_settings_profile() {
                            match build_native_apply_plan(
                                &self.capability,
                                &profile,
                                self.resolver_family,
                            ) {
                                Ok(plan) => {
                                    self.settings_output = render_native_apply_plan(&plan);
                                    self.status = "Native apply plan ready for review".to_string();
                                }
                                Err(error) => {
                                    self.status = format!("Native apply unavailable: {error:?}");
                                }
                            }
                        } else {
                            self.status = "Select a DNS profile first".to_string();
                        }
                    }
                }
                SettingsActionKind::DiagnosticsOnly => {
                    if ui.button(action.label).clicked() {
                        self.settings_output = self.diagnostics.clone();
                        self.status = "Diagnostics copied into Settings".to_string();
                    }
                }
            }
            ui.label(action.help_text);
        }

        if !self.settings_output.is_empty() {
            ui.separator();
            ui.add(
                egui::TextEdit::multiline(&mut self.settings_output)
                    .desired_rows(18)
                    .desired_width(f32::INFINITY),
            );
        }
    }

    fn selected_settings_profile(&self) -> Option<PlainDnsProfile> {
        self.profiles
            .iter()
            .find(|profile| profile.id == self.settings_profile_id)
            .cloned()
    }

    fn history_ui(&mut self, ui: &mut egui::Ui) {
        ui.heading(localized_text(TextKey::History, self.language));
        match self
            .core_adapter()
            .and_then(|mut adapter| adapter.load_history().map_err(|error| format!("{error:?}")))
        {
            Ok(history) if history.is_empty() => {
                ui.label("No saved benchmark history yet.");
            }
            Ok(history) => {
                egui::Grid::new("history_grid")
                    .striped(true)
                    .show(ui, |ui| {
                        ui.strong("Started");
                        ui.strong("Resolvers");
                        ui.strong("Recommendation");
                        ui.end_row();
                        for record in history.into_iter().rev() {
                            ui.label(record.started_at);
                            ui.label(record.resolver_profile_ids.join(", "));
                            ui.label(
                                record
                                    .recommendation_profile_id
                                    .unwrap_or_else(|| "Keep current".to_string()),
                            );
                            ui.end_row();
                        }
                    });
            }
            Err(error) => {
                ui.label(format!("Could not load history: {error}"));
            }
        }
    }

    fn result_ui(&mut self, ui: &mut egui::Ui, result: &BenchmarkDecision) {
        ui.heading("Result");
        ui.label(format!("Health: {}", result.health));
        ui.label(format!(
            "Recommended: {}",
            result
                .recommended_profile_id
                .as_deref()
                .unwrap_or("Keep current")
        ));
        ui.label(format!(
            "Fastest observed: {}",
            result
                .fastest_observed_profile_id
                .as_deref()
                .unwrap_or("No completed resolver")
        ));
        for reason in &result.gate_reasons {
            ui.label(reason);
        }
        if !result.warning.is_empty() {
            ui.label(&result.warning);
        }
        match result.primary_action {
            PrimaryResultAction::ApplyGuidance => {
                if ui.button("Apply guidance").clicked() {
                    if let Some(profile_id) = &result.recommended_profile_id {
                        self.settings_profile_id = profile_id.clone();
                    }
                    self.show_settings = true;
                }
            }
            PrimaryResultAction::RetestSystemDns => {
                if ui.button("Retest system DNS").clicked() {
                    self.selected_mode = BenchmarkMode::CurrentSystemResolver;
                    self.status = "System DNS retest ready".to_string();
                }
            }
            PrimaryResultAction::None => {}
        }
    }

    fn diagnostics_ui(&mut self, ui: &mut egui::Ui) {
        ui.heading(localized_text(TextKey::Diagnostics, self.language));
        if ui
            .button(localized_text(TextKey::CopyDebugReport, self.language))
            .clicked()
        {
            ui.ctx().copy_text(self.diagnostics.clone());
        }
        ui.add(
            egui::TextEdit::multiline(&mut self.diagnostics)
                .desired_rows(26)
                .desired_width(f32::INFINITY),
        );
    }

    fn permissions_ui(&mut self, ui: &mut egui::Ui) {
        ui.heading(localized_text(TextKey::Permissions, self.language));
        let plan = permission_plan(&self.capability, self.language);
        let mut rendered = render_permission_plan(&plan);
        ui.add(
            egui::TextEdit::multiline(&mut rendered)
                .desired_rows(24)
                .desired_width(f32::INFINITY),
        );
    }

    fn current_process_preview(&self) -> Option<LinuxBenchmarkProcessViewModel> {
        self.build_plan()
            .ok()
            .map(|plan| benchmark_process_for_plan(&plan))
    }

    fn process_ui(&self, ui: &mut egui::Ui, process: &LinuxBenchmarkProcessViewModel) {
        ui.heading(localized_text(TextKey::Process, self.language));
        ui.label(format!(
            "{}: {}",
            localized_text(TextKey::Overall, self.language),
            status_label(process.overall_status())
        ));

        egui::Grid::new("process_status_grid")
            .striped(true)
            .show(ui, |ui| {
                ui.strong(localized_text(TextKey::Step, self.language));
                ui.strong(localized_text(TextKey::Status, self.language));
                ui.strong(localized_text(TextKey::Detail, self.language));
                ui.end_row();

                for row in process_rows(process) {
                    let label = match row.kind {
                        ProcessRowKind::Step => row.label,
                        ProcessRowKind::Resolver => format!(
                            "{}: {}",
                            localized_text(TextKey::Resolver, self.language),
                            row.label
                        ),
                    };
                    ui.label(label);
                    ui.label(row.status);
                    ui.label(row.detail.unwrap_or_else(|| "-".to_string()));
                    ui.end_row();
                }
            });
    }
}

fn setup_tutorial_seen_path() -> PathBuf {
    if let Some(data_dir) = data_dir() {
        return data_dir.join("setup-tutorial-seen");
    }
    PathBuf::from("dnspilot-setup-tutorial-seen")
}

fn data_dir() -> Option<PathBuf> {
    if let Ok(data_home) = env::var("XDG_DATA_HOME") {
        return Some(PathBuf::from(data_home).join("dnspilot"));
    }
    if let Ok(home) = env::var("HOME") {
        return Some(PathBuf::from(home).join(".local/share/dnspilot"));
    }
    None
}

fn has_seen_setup_tutorial(path: &PathBuf) -> bool {
    fs::read_to_string(path)
        .map(|value| value.trim() == "true")
        .unwrap_or(false)
}

fn mark_setup_tutorial_seen(path: &PathBuf) {
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let _ = fs::write(path, "true\n");
}

fn load_core_state(
    core_cli: &Result<CoreCliResolution, CoreCliResolutionError>,
    database_path: &std::path::Path,
    legacy_profile_path: &std::path::Path,
) -> (Vec<PlainDnsProfile>, Vec<SuiteViewModel>, String) {
    let resolution = match core_cli {
        Ok(resolution) => resolution,
        Err(error) => return (Vec::new(), Vec::new(), error.to_string()),
    };
    let mut adapter = CoreCliAdapter::new(
        resolution.path.to_string_lossy(),
        database_path,
        ProcessCoreCliCommandRunner,
    );
    let migration_status = match adapter.migrate_legacy_profiles_once(legacy_profile_path) {
        Ok(outcome) if outcome.migrated_profile_count > 0 => {
            format!(
                "Migrated {} legacy profiles. ",
                outcome.migrated_profile_count
            )
        }
        Ok(_) => String::new(),
        Err(error) => {
            return (
                Vec::new(),
                Vec::new(),
                format!("Profile migration failed: {error:?}"),
            )
        }
    };
    let profiles = match adapter.load_profiles() {
        Ok(profiles) => profiles.into_iter().map(Into::into).collect(),
        Err(error) => {
            return (
                Vec::new(),
                Vec::new(),
                format!("Core profile load failed: {error:?}"),
            )
        }
    };
    let suites = match adapter.load_suites() {
        Ok(suites) => suite_catalog_from_core(suites),
        Err(error) => {
            return (
                profiles,
                Vec::new(),
                format!("Core suite load failed: {error:?}"),
            )
        }
    };
    (profiles, suites, format!("{migration_status}Ready"))
}

fn split_words(value: &str) -> Vec<String> {
    value
        .split(|ch: char| ch == ',' || ch.is_ascii_whitespace())
        .map(str::trim)
        .filter(|part| !part.is_empty())
        .map(ToString::to_string)
        .collect()
}
