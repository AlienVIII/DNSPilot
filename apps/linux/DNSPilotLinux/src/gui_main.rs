use dnspilot_linux_shell::app::LinuxAppSession;
use dnspilot_linux_shell::benchmark::{
    benchmark_process_for_plan, build_core_cli_command, run_benchmark_with_runner,
    ProcessCoreCliRunner,
};
use dnspilot_linux_shell::capabilities::{
    available_benchmark_modes, capability_view_model, BenchmarkMode, LinuxCapabilityViewModel,
};
use dnspilot_linux_shell::detect::detect_linux_environment;
use dnspilot_linux_shell::i18n::{localized_text, Language, TextKey};
use dnspilot_linux_shell::native_app::{build_native_app_model, NativeAppSectionKind};
use dnspilot_linux_shell::permissions::{permission_plan, render_permission_plan};
use dnspilot_linux_shell::process::{
    process_rows, status_label, LinuxBenchmarkProcessViewModel, ProcessRowKind,
};
use dnspilot_linux_shell::profiles::{CustomProfileStore, PlainDnsProfile, PlainDnsProfileDraft};
use dnspilot_linux_shell::settings::{
    dns_record_family_controls, resolver_address_family_controls, settings_actions,
    DnsRecordFamily, ResolverAddressFamily,
};
use dnspilot_linux_shell::storage::FileProfileRepository;
use dnspilot_linux_shell::suites::default_suite_catalog;
use eframe::egui;
use std::env;
use std::fs;
use std::path::PathBuf;

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
    capability: LinuxCapabilityViewModel,
    active_section: NativeAppSectionKind,
    profiles: Vec<PlainDnsProfile>,
    selected_profile_ids: Vec<String>,
    selected_mode: BenchmarkMode,
    selected_suite_id: Option<String>,
    resolver_family: ResolverAddressFamily,
    record_family: DnsRecordFamily,
    custom_domains: String,
    core_cli_path: String,
    status: String,
    diagnostics: String,
    process: Option<LinuxBenchmarkProcessViewModel>,
    show_tutorial: bool,
    profile_id: String,
    profile_name: String,
    profile_ipv4: String,
    profile_ipv6: String,
    store_path: String,
}

impl DnsPilotGui {
    fn new() -> Self {
        let capability = capability_view_model(detect_linux_environment());
        let store_path = profile_store_path().to_string_lossy().to_string();
        let setup_seen_path = setup_tutorial_seen_path();
        let show_tutorial = !has_seen_setup_tutorial(&setup_seen_path);
        if show_tutorial {
            mark_setup_tutorial_seen(&setup_seen_path);
        }
        let profiles = load_or_seed_profiles(&store_path);
        let selected_profile_ids = profiles.iter().map(|profile| profile.id.clone()).collect();
        let selected_suite_id = default_suite_catalog(true)
            .first()
            .map(|suite| suite.id.to_string());

        Self {
            language: Language::English,
            capability,
            active_section: NativeAppSectionKind::Benchmark,
            profiles,
            selected_profile_ids,
            selected_mode: BenchmarkMode::DnsAndTcp,
            selected_suite_id,
            resolver_family: ResolverAddressFamily::Auto,
            record_family: DnsRecordFamily::AAndAaaa,
            custom_domains: String::new(),
            core_cli_path: "dnspilot-cli".to_string(),
            status: "Ready".to_string(),
            diagnostics: String::new(),
            process: None,
            show_tutorial,
            profile_id: String::new(),
            profile_name: String::new(),
            profile_ipv4: String::new(),
            profile_ipv6: String::new(),
            store_path,
        }
    }

    fn build_session(&self) -> LinuxAppSession {
        let mut session = LinuxAppSession::new(
            self.capability.clone(),
            default_suite_catalog(true),
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

    fn save_profile_from_form(&mut self) {
        let draft = PlainDnsProfileDraft {
            id: self.profile_id.trim().to_string(),
            name: self.profile_name.trim().to_string(),
            ipv4_servers: split_words(&self.profile_ipv4),
            ipv6_servers: split_words(&self.profile_ipv6),
        };
        let mut store = store_from_profiles(&self.profiles);
        let result = if self.profiles.iter().any(|profile| profile.id == draft.id) {
            store.edit(draft)
        } else {
            store.add(draft)
        };

        match result {
            Ok(()) => {
                self.profiles = store.list().to_vec();
                if let Err(error) = FileProfileRepository::new(self.store_path.clone())
                    .save_profiles(&self.profiles)
                {
                    self.status = format!("Profile save failed: {error:?}");
                } else {
                    self.status = "Profile saved".to_string();
                }
            }
            Err(error) => {
                self.status = format!("Profile validation failed: {error:?}");
            }
        }
    }

    fn delete_profile(&mut self, profile_id: &str) {
        let mut store = store_from_profiles(&self.profiles);
        if store.delete(profile_id) {
            self.profiles = store.list().to_vec();
            self.selected_profile_ids.retain(|id| id != profile_id);
            if let Err(error) =
                FileProfileRepository::new(self.store_path.clone()).save_profiles(&self.profiles)
            {
                self.status = format!("Profile delete failed: {error:?}");
            } else {
                self.status = "Profile deleted".to_string();
            }
        }
    }

    fn fill_profile_form(&mut self, profile: &PlainDnsProfile) {
        self.profile_id = profile.id.clone();
        self.profile_name = profile.name.clone();
        self.profile_ipv4 = profile.ipv4_servers.join(", ");
        self.profile_ipv6 = profile.ipv6_servers.join(", ");
    }

    fn plan_benchmark(&mut self) {
        let session = self.build_session();
        match session.build_plan() {
            Ok(plan) => {
                let command = build_core_cli_command(&self.core_cli_path, &plan);
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
        let session = self.build_session();
        match session.build_plan() {
            Ok(plan) => {
                let runner = ProcessCoreCliRunner;
                let result = run_benchmark_with_runner(
                    self.core_cli_path.clone(),
                    "linux-gui",
                    self.capability.clone(),
                    plan,
                    &runner,
                );
                self.process = Some(result.process.clone());
                self.diagnostics = result.debug_report;
                if let Some(payload) = result.final_payload {
                    self.diagnostics.push_str("\n\nFinal payload:\n");
                    self.diagnostics.push_str(&payload);
                }
                self.status = result
                    .error
                    .map(|error| format!("Benchmark failed: {error}"))
                    .unwrap_or_else(|| "Benchmark finished".to_string());
            }
            Err(issues) => {
                self.process = None;
                self.status = issues.join("; ");
            }
        }
    }
}

impl eframe::App for DnsPilotGui {
    fn ui(&mut self, ui: &mut egui::Ui, _frame: &mut eframe::Frame) {
        let ctx = ui.ctx().clone();
        ui.add_space(8.0);
        ui.horizontal(|ui| {
            ui.heading(localized_text(TextKey::AppTitle, self.language));
            ui.separator();
            ui.label(format!("Package: {}", self.capability.package_kind.label()));
            ui.separator();
            ui.selectable_value(&mut self.language, Language::English, "EN");
            ui.selectable_value(&mut self.language, Language::Vietnamese, "VI");
            ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                if ui.button("?").on_hover_text("Show setup tutorial").clicked() {
                    self.show_tutorial = true;
                }
            });
        });
        ui.separator();

        if self.show_tutorial {
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
                });
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
                NativeAppSectionKind::Benchmark => self.benchmark_ui(ui),
                NativeAppSectionKind::Profiles => self.profiles_ui(ui),
                NativeAppSectionKind::Settings => self.settings_ui(ui),
                NativeAppSectionKind::Diagnostics => self.diagnostics_ui(ui),
                NativeAppSectionKind::Permissions => self.permissions_ui(ui),
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
                for suite in default_suite_catalog(true) {
                    ui.selectable_value(
                        &mut self.selected_suite_id,
                        Some(suite.id.to_string()),
                        suite.name,
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
            ui.label("Core CLI");
            ui.text_edit_singleline(&mut self.core_cli_path);
            if ui.button("Plan").clicked() {
                self.plan_benchmark();
            }
            if ui
                .button(localized_text(TextKey::RunBenchmark, self.language))
                .clicked()
            {
                self.run_benchmark();
            }
        });

        ui.separator();
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
        for action in settings_actions(&self.capability) {
            ui.label(format!("{}: {}", action.label, action.help_text));
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
        self.build_session()
            .build_plan()
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

fn profile_store_path() -> PathBuf {
    if let Some(data_dir) = data_dir() {
        return data_dir.join("profiles.json");
    }
    PathBuf::from("dnspilot-profiles.json")
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

fn load_or_seed_profiles(path: &str) -> Vec<PlainDnsProfile> {
    let loaded = FileProfileRepository::new(path.to_string())
        .load_profiles()
        .unwrap_or_default();
    if loaded.is_empty() {
        seeded_profiles()
    } else {
        loaded
    }
}

fn seeded_profiles() -> Vec<PlainDnsProfile> {
    vec![
        PlainDnsProfile {
            id: "cloudflare".to_string(),
            name: "Cloudflare".to_string(),
            ipv4_servers: vec!["1.1.1.1".to_string(), "1.0.0.1".to_string()],
            ipv6_servers: vec![
                "2606:4700:4700::1111".to_string(),
                "2606:4700:4700::1001".to_string(),
            ],
        },
        PlainDnsProfile {
            id: "quad9".to_string(),
            name: "Quad9".to_string(),
            ipv4_servers: vec!["9.9.9.9".to_string(), "149.112.112.112".to_string()],
            ipv6_servers: vec!["2620:fe::fe".to_string(), "2620:fe::9".to_string()],
        },
    ]
}

fn store_from_profiles(profiles: &[PlainDnsProfile]) -> CustomProfileStore {
    let mut store = CustomProfileStore::new();
    for profile in profiles {
        let _ = store.add(PlainDnsProfileDraft {
            id: profile.id.clone(),
            name: profile.name.clone(),
            ipv4_servers: profile.ipv4_servers.clone(),
            ipv6_servers: profile.ipv6_servers.clone(),
        });
    }
    store
}

fn split_words(value: &str) -> Vec<String> {
    value
        .split(|ch: char| ch == ',' || ch.is_ascii_whitespace())
        .map(str::trim)
        .filter(|part| !part.is_empty())
        .map(ToString::to_string)
        .collect()
}
