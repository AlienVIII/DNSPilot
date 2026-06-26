use std::collections::HashSet;
use std::net::IpAddr;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlainDnsProfileDraft {
    pub id: String,
    pub name: String,
    pub ipv4_servers: Vec<String>,
    pub ipv6_servers: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlainDnsProfile {
    pub id: String,
    pub name: String,
    pub ipv4_servers: Vec<String>,
    pub ipv6_servers: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ProfileValidationIssue {
    EmptyId,
    EmptyName,
    NoServers,
    InvalidIpv4(String),
    InvalidIpv6(String),
    DuplicateServer(String),
    DuplicateProfileId(String),
    MissingProfile(String),
}

#[derive(Debug, Default, Clone, PartialEq, Eq)]
pub struct CustomProfileStore {
    profiles: Vec<PlainDnsProfile>,
}

impl CustomProfileStore {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn add(&mut self, draft: PlainDnsProfileDraft) -> Result<(), ProfileValidationIssue> {
        if self.profiles.iter().any(|profile| profile.id == draft.id) {
            return Err(ProfileValidationIssue::DuplicateProfileId(draft.id));
        }
        let profile = validate_draft(draft)?;
        self.profiles.push(profile);
        Ok(())
    }

    pub fn edit(&mut self, draft: PlainDnsProfileDraft) -> Result<(), ProfileValidationIssue> {
        let index = self
            .profiles
            .iter()
            .position(|profile| profile.id == draft.id)
            .ok_or_else(|| ProfileValidationIssue::MissingProfile(draft.id.clone()))?;
        let profile = validate_draft(draft)?;
        self.profiles[index] = profile;
        Ok(())
    }

    pub fn delete(&mut self, id: &str) -> bool {
        let before = self.profiles.len();
        self.profiles.retain(|profile| profile.id != id);
        before != self.profiles.len()
    }

    pub fn list(&self) -> &[PlainDnsProfile] {
        &self.profiles
    }
}

fn validate_draft(draft: PlainDnsProfileDraft) -> Result<PlainDnsProfile, ProfileValidationIssue> {
    if draft.id.trim().is_empty() {
        return Err(ProfileValidationIssue::EmptyId);
    }
    if draft.name.trim().is_empty() {
        return Err(ProfileValidationIssue::EmptyName);
    }
    if draft.ipv4_servers.is_empty() && draft.ipv6_servers.is_empty() {
        return Err(ProfileValidationIssue::NoServers);
    }

    let mut seen = HashSet::new();
    for server in draft.ipv4_servers.iter().chain(draft.ipv6_servers.iter()) {
        if !seen.insert(server.clone()) {
            return Err(ProfileValidationIssue::DuplicateServer(server.clone()));
        }
    }

    for server in &draft.ipv4_servers {
        match server.parse::<IpAddr>() {
            Ok(IpAddr::V4(_)) => {}
            _ => return Err(ProfileValidationIssue::InvalidIpv4(server.clone())),
        }
    }

    for server in &draft.ipv6_servers {
        match server.parse::<IpAddr>() {
            Ok(IpAddr::V6(_)) => {}
            _ => return Err(ProfileValidationIssue::InvalidIpv6(server.clone())),
        }
    }

    Ok(PlainDnsProfile {
        id: draft.id,
        name: draft.name,
        ipv4_servers: draft.ipv4_servers,
        ipv6_servers: draft.ipv6_servers,
    })
}
