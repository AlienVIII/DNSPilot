use crate::i18n::Language;
use std::fs;
use std::path::Path;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LanguagePreference {
    System,
    English,
    Vietnamese,
}

impl LanguagePreference {
    pub fn resolve(self, system_locale: Option<&str>) -> Language {
        match self {
            Self::System => system_locale
                .and_then(Language::parse_system_locale)
                .unwrap_or(Language::English),
            Self::English => Language::English,
            Self::Vietnamese => Language::Vietnamese,
        }
    }

    fn value(self) -> &'static str {
        match self {
            Self::System => "system",
            Self::English => "en",
            Self::Vietnamese => "vi",
        }
    }

    fn parse(value: &str) -> Option<Self> {
        match value.trim() {
            "system" => Some(Self::System),
            "en" => Some(Self::English),
            "vi" => Some(Self::Vietnamese),
            _ => None,
        }
    }
}

pub fn load_language_preference(path: &Path) -> LanguagePreference {
    fs::read_to_string(path)
        .ok()
        .as_deref()
        .and_then(LanguagePreference::parse)
        .unwrap_or(LanguagePreference::System)
}

pub fn save_language_preference(
    path: &Path,
    preference: LanguagePreference,
) -> std::io::Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, format!("{}\n", preference.value()))
}
