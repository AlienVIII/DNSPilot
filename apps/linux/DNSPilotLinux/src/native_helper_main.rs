use dnspilot_linux_shell::native_power::{
    execute_native_apply_request, parse_native_apply_request_json, NativeHelperExecutor,
    NativeHelperRunError, NativeResolverStack, DNS_APPLY_POLKIT_ACTION_ID,
};
use std::env;
use std::process;

fn main() {
    match run(env::args().skip(1)) {
        Ok(output) => println!("{output}"),
        Err(error) => {
            eprintln!("{error}");
            process::exit(2);
        }
    }
}

fn run(args: impl IntoIterator<Item = String>) -> Result<String, String> {
    let mut mode = HelperMode::Contract;
    let mut stack = None;
    let mut servers = Vec::new();
    let mut request_json = None;
    let mut args = args.into_iter();

    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--contract" => mode = HelperMode::Contract,
            "--dry-run" => mode = HelperMode::DryRun,
            "--request-json" => {
                mode = HelperMode::RequestJson;
                request_json = Some(next_arg(&mut args, "--request-json")?);
            }
            "--stack" => stack = Some(parse_stack(&next_arg(&mut args, "--stack")?)?),
            "--server" => servers.push(next_arg(&mut args, "--server")?),
            _ => return Err(format!("unknown argument: {arg}")),
        }
    }

    match mode {
        HelperMode::Contract => Ok(render_contract()),
        HelperMode::DryRun => {
            let stack = stack.ok_or_else(|| "--stack is required".to_string())?;
            if servers.is_empty() {
                return Err("--server is required".to_string());
            }
            Ok(render_dry_run(stack, &servers))
        }
        HelperMode::RequestJson => {
            let json = request_json.ok_or_else(|| "--request-json is required".to_string())?;
            let request = parse_native_apply_request_json(&json)
                .map_err(|error| format!("invalid request: {error:?}"))?;
            let mut executor = DryRunExecutor::default();
            execute_native_apply_request(&request, &mut executor)
                .map_err(|error| format!("mock execution failed: {error:?}"))?;
            Ok(render_mock_execution(&executor.events))
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum HelperMode {
    Contract,
    DryRun,
    RequestJson,
}

fn render_contract() -> String {
    [
        "DNS Pilot Native Helper Contract".to_string(),
        format!("Polkit action: {DNS_APPLY_POLKIT_ACTION_ID}"),
        "Supported stacks:".to_string(),
        format!("- {}", NativeResolverStack::NetworkManager.label()),
        format!("- {}", NativeResolverStack::SystemdResolved.label()),
        "Safety:".to_string(),
        "- runs only for native deb/rpm power packages".to_string(),
        "- does not mutate DNS without an explicit apply request".to_string(),
        "- requires rollback snapshot before writes".to_string(),
        "- validates current/system resolver after apply when supported".to_string(),
    ]
    .join("\n")
}

fn render_dry_run(stack: NativeResolverStack, servers: &[String]) -> String {
    [
        "DNS Pilot Native Helper Dry Run".to_string(),
        "Dry run: yes".to_string(),
        format!("Resolver stack: {}", stack.label()),
        format!("Servers: {}", servers.join(", ")),
        format!("Polkit action: {DNS_APPLY_POLKIT_ACTION_ID}"),
        "DNS writes executed: no".to_string(),
    ]
    .join("\n")
}

fn render_mock_execution(events: &[String]) -> String {
    let mut lines = vec![
        "Native helper mock execution".to_string(),
        "Dry run: yes".to_string(),
        "Events:".to_string(),
    ];
    lines.extend(events.iter().map(|event| format!("- {event}")));
    lines.push("DNS writes executed: no".to_string());
    lines.join("\n")
}

fn parse_stack(value: &str) -> Result<NativeResolverStack, String> {
    match value {
        "networkmanager" | "network-manager" | "nm" => Ok(NativeResolverStack::NetworkManager),
        "systemd-resolved" | "resolved" => Ok(NativeResolverStack::SystemdResolved),
        _ => Err(format!("unknown stack: {value}")),
    }
}

fn next_arg(args: &mut impl Iterator<Item = String>, flag: &str) -> Result<String, String> {
    args.next()
        .ok_or_else(|| format!("{flag} requires a value"))
}

#[derive(Default)]
struct DryRunExecutor {
    events: Vec<String>,
}

impl NativeHelperExecutor for DryRunExecutor {
    fn snapshot_existing_dns(
        &mut self,
        stack: NativeResolverStack,
    ) -> Result<(), NativeHelperRunError> {
        self.events.push(format!("snapshot:{stack:?}"));
        Ok(())
    }

    fn authorize(&mut self, action_id: &str) -> Result<(), NativeHelperRunError> {
        self.events.push(format!("authorize:{action_id}"));
        Ok(())
    }

    fn write_dns(
        &mut self,
        stack: NativeResolverStack,
        servers: &[String],
    ) -> Result<(), NativeHelperRunError> {
        self.events
            .push(format!("write:{stack:?}:{}", servers.join(",")));
        Ok(())
    }

    fn flush_resolver_cache(
        &mut self,
        stack: NativeResolverStack,
    ) -> Result<(), NativeHelperRunError> {
        self.events.push(format!("flush:{stack:?}"));
        Ok(())
    }

    fn validate_current_resolver(
        &mut self,
        stack: NativeResolverStack,
    ) -> Result<(), NativeHelperRunError> {
        self.events.push(format!("validate:{stack:?}"));
        Ok(())
    }

    fn rollback_dns(&mut self, stack: NativeResolverStack) -> Result<(), NativeHelperRunError> {
        self.events.push(format!("rollback:{stack:?}"));
        Ok(())
    }
}
