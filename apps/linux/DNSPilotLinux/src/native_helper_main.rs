use dnspilot_linux_shell::native_power::{
    parse_native_apply_request_json, NativeHelperApplyRequest, NativeMutationMode,
    NativeResolverStack, DNS_APPLY_POLKIT_ACTION_ID,
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
            if request.mutation_mode == NativeMutationMode::Execute {
                return Err(
                    "execution backend is not enabled in this helper build; run Linux package QA before enabling real DNS mutation"
                        .to_string(),
                );
            }
            Ok(render_mock_execution(&request))
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

fn render_mock_execution(request: &NativeHelperApplyRequest) -> String {
    let mut lines = vec![
        "Native helper mock execution".to_string(),
        "Dry run: yes".to_string(),
        "Events:".to_string(),
    ];
    lines.push(format!("- snapshot:{:?}", request.resolver_stack));
    lines.push(format!("- authorize:{}", request.polkit_action_id));
    lines.push(format!(
        "- would-write:{:?}:{}",
        request.resolver_stack,
        request.servers.join(",")
    ));
    lines.push(format!("- flush:{:?}", request.resolver_stack));
    if request.validate_after_apply {
        lines.push(format!("- validate:{:?}", request.resolver_stack));
    }
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
