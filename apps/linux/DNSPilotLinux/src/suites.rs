#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SuiteViewModel {
    pub id: &'static str,
    pub name: &'static str,
    pub domains: Vec<&'static str>,
}

pub fn default_suite_catalog(catalog_supports_vietnam: bool) -> Vec<SuiteViewModel> {
    let mut suites = vec![
        SuiteViewModel {
            id: "general",
            name: "General",
            domains: vec!["example.com", "cloudflare.com", "wikipedia.org"],
        },
        SuiteViewModel {
            id: "developer",
            name: "Developer",
            domains: vec!["github.com", "npmjs.com", "crates.io"],
        },
        SuiteViewModel {
            id: "microsoft-login",
            name: "Microsoft login",
            domains: vec!["login.microsoftonline.com", "graph.microsoft.com"],
        },
    ];

    if catalog_supports_vietnam {
        suites.push(SuiteViewModel {
            id: "vietnam-daily",
            name: "Vietnam daily",
            domains: vec!["zing.vn", "vnexpress.net", "momo.vn"],
        });
    }

    suites
}
