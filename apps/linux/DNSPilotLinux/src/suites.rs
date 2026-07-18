use crate::core_adapter::CoreSuite;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SuiteViewModel {
    pub id: String,
    pub name: String,
    pub description: String,
    pub domains: Vec<String>,
    pub tags: Vec<String>,
}

pub fn suite_catalog_from_core(suites: Vec<CoreSuite>) -> Vec<SuiteViewModel> {
    suites
        .into_iter()
        .map(|suite| SuiteViewModel {
            id: suite.id,
            name: suite.name,
            description: suite.description,
            domains: suite.domains,
            tags: suite.tags,
        })
        .collect()
}
