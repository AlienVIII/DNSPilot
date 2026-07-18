use dnspilot_linux_shell::i18n::Language;
use dnspilot_linux_shell::preferences::{
    load_language_preference, save_language_preference, LanguagePreference,
};
use std::path::PathBuf;

#[test]
fn system_english_and_vietnamese_preferences_resolve_and_persist() {
    let path = temp_path("language-preference");

    assert_eq!(
        LanguagePreference::System.resolve(Some("vi_VN.UTF-8")),
        Language::Vietnamese
    );
    assert_eq!(
        LanguagePreference::System.resolve(Some("fr_FR.UTF-8")),
        Language::English
    );
    assert_eq!(
        LanguagePreference::English.resolve(Some("vi")),
        Language::English
    );

    save_language_preference(&path, LanguagePreference::Vietnamese).unwrap();
    assert_eq!(
        load_language_preference(&path),
        LanguagePreference::Vietnamese
    );
}

fn temp_path(name: &str) -> PathBuf {
    std::env::temp_dir().join(format!("dnspilot-linux-{name}-{}", std::process::id()))
}
