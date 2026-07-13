use std::env;
use std::fmt;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};

pub const CORE_CLI_ENVIRONMENT_VARIABLE: &str = "DNSPILOT_CLI_PATH";
const CORE_CLI_BINARY_NAME: &str = "dnspilot-cli";

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CoreCliSource {
    EnvironmentOverride,
    PackagedSibling,
    Path,
}

impl CoreCliSource {
    pub fn label(self) -> &'static str {
        match self {
            Self::EnvironmentOverride => "environment override",
            Self::PackagedSibling => "packaged engine",
            Self::Path => "PATH",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CoreCliResolution {
    pub path: PathBuf,
    pub source: CoreCliSource,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CoreCliResolutionError {
    InvalidOverride(PathBuf),
    NotFound,
}

impl fmt::Display for CoreCliResolutionError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidOverride(path) => write!(
                formatter,
                "DNS Pilot core engine override is not executable: {}. Fix or unset {}.",
                path.display(),
                CORE_CLI_ENVIRONMENT_VARIABLE
            ),
            Self::NotFound => write!(
                formatter,
                "DNS Pilot core engine was not found. Reinstall the package or set {} for development.",
                CORE_CLI_ENVIRONMENT_VARIABLE
            ),
        }
    }
}

pub fn resolve_core_cli() -> Result<CoreCliResolution, CoreCliResolutionError> {
    let environment_override = env::var_os(CORE_CLI_ENVIRONMENT_VARIABLE)
        .map(|value| value.to_string_lossy().into_owned());
    let current_executable = env::current_exe().ok();
    let path_value = env::var_os("PATH").map(|value| value.to_string_lossy().into_owned());

    resolve_core_cli_with(
        environment_override.as_deref(),
        current_executable.as_deref(),
        path_value.as_deref(),
        is_executable_file,
    )
}

pub fn resolve_core_cli_with(
    environment_override: Option<&str>,
    current_executable: Option<&Path>,
    path_value: Option<&str>,
    is_executable: impl Fn(&Path) -> bool,
) -> Result<CoreCliResolution, CoreCliResolutionError> {
    if let Some(value) = environment_override.filter(|value| !value.trim().is_empty()) {
        let path = PathBuf::from(value);
        return if is_executable(&path) {
            Ok(CoreCliResolution {
                path,
                source: CoreCliSource::EnvironmentOverride,
            })
        } else {
            Err(CoreCliResolutionError::InvalidOverride(path))
        };
    }

    if let Some(path) = current_executable
        .and_then(Path::parent)
        .map(|directory| directory.join(CORE_CLI_BINARY_NAME))
    {
        if is_executable(&path) {
            return Ok(CoreCliResolution {
                path,
                source: CoreCliSource::PackagedSibling,
            });
        }
    }

    if let Some(path_value) = path_value {
        for directory in env::split_paths(path_value).filter(|path| !path.as_os_str().is_empty()) {
            let path = directory.join(CORE_CLI_BINARY_NAME);
            if is_executable(&path) {
                return Ok(CoreCliResolution {
                    path,
                    source: CoreCliSource::Path,
                });
            }
        }
    }

    Err(CoreCliResolutionError::NotFound)
}

fn is_executable_file(path: &Path) -> bool {
    fs::metadata(path)
        .map(|metadata| metadata.is_file() && metadata.permissions().mode() & 0o111 != 0)
        .unwrap_or(false)
}
