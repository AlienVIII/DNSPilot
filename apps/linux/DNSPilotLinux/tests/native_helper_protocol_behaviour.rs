use dnspilot_linux_shell::native_power::{
    execute_native_apply_request, parse_native_apply_request_json, CommandNativeHelperExecutor,
    NativeCommandOutput, NativeCommandRunner, NativeHelperExecutor, NativeHelperRunError,
    NativeMutationMode, NativeResolverStack, DNS_APPLY_POLKIT_ACTION_ID,
};

#[test]
fn native_helper_request_json_parses_stack_servers_and_safety_flags() {
    let request = parse_native_apply_request_json(&format!(
        r#"{{
            "schema_version": 1,
            "polkit_action_id": "{DNS_APPLY_POLKIT_ACTION_ID}",
            "resolver_stack": "networkmanager",
            "servers": ["1.1.1.1", "9.9.9.9"],
            "rollback_snapshot": true,
            "validate_after_apply": true
        }}"#
    ))
    .unwrap();

    assert_eq!(request.resolver_stack, NativeResolverStack::NetworkManager);
    assert_eq!(request.servers, vec!["1.1.1.1", "9.9.9.9"]);
    assert_eq!(request.mutation_mode, NativeMutationMode::DryRun);
    assert!(!request.confirm_system_dns_mutation);
    assert!(request.rollback_snapshot);
    assert!(request.validate_after_apply);
}

#[test]
fn native_helper_request_json_requires_confirmation_for_execute_mode() {
    let error = parse_native_apply_request_json(&format!(
        r#"{{
            "schema_version": 1,
            "polkit_action_id": "{DNS_APPLY_POLKIT_ACTION_ID}",
            "resolver_stack": "networkmanager",
            "servers": ["1.1.1.1"],
            "rollback_snapshot": true,
            "validate_after_apply": true,
            "mutation_mode": "execute"
        }}"#
    ))
    .unwrap_err();

    assert_eq!(error, NativeHelperRunError::MutationNotConfirmed);
}

#[test]
fn native_helper_request_json_accepts_confirmed_execute_mode() {
    let request = parse_native_apply_request_json(&format!(
        r#"{{
            "schema_version": 1,
            "polkit_action_id": "{DNS_APPLY_POLKIT_ACTION_ID}",
            "resolver_stack": "systemd-resolved",
            "servers": ["2606:4700:4700::1111"],
            "rollback_snapshot": true,
            "validate_after_apply": true,
            "mutation_mode": "execute",
            "confirm_system_dns_mutation": true
        }}"#
    ))
    .unwrap();

    assert_eq!(request.mutation_mode, NativeMutationMode::Execute);
    assert!(request.confirm_system_dns_mutation);
}

#[test]
fn native_helper_executor_refuses_dry_run_requests() {
    let request = parse_native_apply_request_json(&format!(
        r#"{{
            "schema_version": 1,
            "polkit_action_id": "{DNS_APPLY_POLKIT_ACTION_ID}",
            "resolver_stack": "networkmanager",
            "servers": ["1.1.1.1"],
            "rollback_snapshot": true,
            "validate_after_apply": false
        }}"#
    ))
    .unwrap();
    let mut executor = RecordingExecutor::default();

    let error = execute_native_apply_request(&request, &mut executor).unwrap_err();

    assert_eq!(error, NativeHelperRunError::MutationNotConfirmed);
    assert!(executor.events.is_empty());
}

#[test]
fn native_helper_request_json_rejects_wrong_polkit_action_or_empty_servers() {
    let wrong_action = parse_native_apply_request_json(
        r#"{
            "schema_version": 1,
            "polkit_action_id": "io.example.bad",
            "resolver_stack": "systemd-resolved",
            "servers": ["2606:4700:4700::1111"],
            "rollback_snapshot": true,
            "validate_after_apply": false
        }"#,
    )
    .unwrap_err();
    assert_eq!(wrong_action, NativeHelperRunError::InvalidPolkitAction);

    let empty_servers = parse_native_apply_request_json(&format!(
        r#"{{
            "schema_version": 1,
            "polkit_action_id": "{DNS_APPLY_POLKIT_ACTION_ID}",
            "resolver_stack": "systemd-resolved",
            "servers": [],
            "rollback_snapshot": true,
            "validate_after_apply": false
        }}"#
    ))
    .unwrap_err();
    assert_eq!(empty_servers, NativeHelperRunError::NoServers);
}

#[test]
fn native_helper_executor_runs_authorized_write_sequence() {
    let request = parse_native_apply_request_json(&format!(
        r#"{{
            "schema_version": 1,
            "polkit_action_id": "{DNS_APPLY_POLKIT_ACTION_ID}",
            "resolver_stack": "networkmanager",
            "servers": ["1.1.1.1"],
            "rollback_snapshot": true,
            "validate_after_apply": true,
            "mutation_mode": "execute",
            "confirm_system_dns_mutation": true
        }}"#
    ))
    .unwrap();
    let mut executor = RecordingExecutor::default();

    let result = execute_native_apply_request(&request, &mut executor).unwrap();

    assert_eq!(
        executor.events,
        vec![
            "snapshot:NetworkManager",
            "authorize:io.dnspilot.DNSPilot.apply-dns",
            "write:NetworkManager:1.1.1.1",
            "flush:NetworkManager",
            "validate:NetworkManager"
        ]
    );
    assert!(result.applied);
    assert!(!result.rolled_back);
}

#[test]
fn native_helper_executor_rolls_back_after_write_failure() {
    let request = parse_native_apply_request_json(&format!(
        r#"{{
            "schema_version": 1,
            "polkit_action_id": "{DNS_APPLY_POLKIT_ACTION_ID}",
            "resolver_stack": "systemd-resolved",
            "servers": ["2606:4700:4700::1111"],
            "rollback_snapshot": true,
            "validate_after_apply": true,
            "mutation_mode": "execute",
            "confirm_system_dns_mutation": true
        }}"#
    ))
    .unwrap();
    let mut executor = RecordingExecutor {
        fail_write: true,
        ..RecordingExecutor::default()
    };

    let error = execute_native_apply_request(&request, &mut executor).unwrap_err();

    assert_eq!(
        error,
        NativeHelperRunError::WriteFailed("forced".to_string())
    );
    assert_eq!(
        executor.events,
        vec![
            "snapshot:SystemdResolved",
            "authorize:io.dnspilot.DNSPilot.apply-dns",
            "write:SystemdResolved:2606:4700:4700::1111",
            "rollback:SystemdResolved"
        ]
    );
}

#[test]
fn native_command_executor_runs_networkmanager_apply_commands_in_order() {
    let request = parse_native_apply_request_json(&format!(
        r#"{{
            "schema_version": 1,
            "polkit_action_id": "{DNS_APPLY_POLKIT_ACTION_ID}",
            "resolver_stack": "networkmanager",
            "servers": ["1.1.1.1", "9.9.9.9"],
            "rollback_snapshot": true,
            "validate_after_apply": true,
            "mutation_mode": "execute",
            "confirm_system_dns_mutation": true
        }}"#
    ))
    .unwrap();
    let mut runner = RecordingCommandRunner::default().with_stdout(
        "nmcli --terse --fields DEVICE connection show --active",
        "wlan0\n",
    );
    let mut executor = CommandNativeHelperExecutor::new(&mut runner);

    let result = execute_native_apply_request(&request, &mut executor).unwrap();

    assert!(result.applied);
    let polkit_command = format!(
        "pkcheck --action-id io.dnspilot.DNSPilot.apply-dns --process {} --allow-user-interaction",
        std::process::id()
    );
    assert_eq!(
        runner.commands,
        vec![
            "nmcli --terse --fields DEVICE connection show --active".to_string(),
            polkit_command,
            "nmcli device modify wlan0 ipv4.dns 1.1.1.1 9.9.9.9 ipv4.ignore-auto-dns yes"
                .to_string(),
            "nmcli general reload dns-full".to_string(),
            "resolvectl status".to_string()
        ]
    );
}

#[test]
fn native_command_executor_rolls_back_with_snapshot_after_flush_failure() {
    let request = parse_native_apply_request_json(&format!(
        r#"{{
            "schema_version": 1,
            "polkit_action_id": "{DNS_APPLY_POLKIT_ACTION_ID}",
            "resolver_stack": "systemd-resolved",
            "servers": ["2606:4700:4700::1111"],
            "rollback_snapshot": true,
            "validate_after_apply": true,
            "mutation_mode": "execute",
            "confirm_system_dns_mutation": true
        }}"#
    ))
    .unwrap();
    let mut runner = RecordingCommandRunner {
        fail_on: Some("resolvectl flush-caches".to_string()),
        ..RecordingCommandRunner::default()
    }
    .with_stdout(
        "ip route show default",
        "default via 192.0.2.1 dev eth0 proto dhcp\n",
    );
    let mut executor = CommandNativeHelperExecutor::new(&mut runner);

    let error = execute_native_apply_request(&request, &mut executor).unwrap_err();

    assert_eq!(
        error,
        NativeHelperRunError::FlushFailed("forced".to_string())
    );
    let polkit_command = format!(
        "pkcheck --action-id io.dnspilot.DNSPilot.apply-dns --process {} --allow-user-interaction",
        std::process::id()
    );
    assert_eq!(
        runner.commands,
        vec![
            "ip route show default".to_string(),
            polkit_command,
            "resolvectl dns eth0 2606:4700:4700::1111".to_string(),
            "resolvectl flush-caches".to_string(),
            "resolvectl revert eth0".to_string()
        ]
    );
}

#[derive(Default)]
struct RecordingExecutor {
    events: Vec<String>,
    fail_write: bool,
}

impl NativeHelperExecutor for RecordingExecutor {
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
        if self.fail_write {
            Err(NativeHelperRunError::WriteFailed("forced".to_string()))
        } else {
            Ok(())
        }
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

#[derive(Default)]
struct RecordingCommandRunner {
    commands: Vec<String>,
    fail_on: Option<String>,
    stdout_by_command: Vec<(String, String)>,
}

impl RecordingCommandRunner {
    fn with_stdout(mut self, command: &str, stdout: &str) -> Self {
        self.stdout_by_command
            .push((command.to_string(), stdout.to_string()));
        self
    }
}

impl NativeCommandRunner for RecordingCommandRunner {
    fn run_command(
        &mut self,
        program: &str,
        args: &[String],
    ) -> Result<NativeCommandOutput, String> {
        let rendered = if args.is_empty() {
            program.to_string()
        } else {
            format!("{program} {}", args.join(" "))
        };
        self.commands.push(rendered.clone());
        if self.fail_on.as_ref() == Some(&rendered) {
            Err("forced".to_string())
        } else {
            let stdout = self
                .stdout_by_command
                .iter()
                .find(|(command, _)| command == &rendered)
                .map(|(_, stdout)| stdout.clone())
                .unwrap_or_else(|| "ok".to_string());
            Ok(NativeCommandOutput {
                stdout,
                stderr: String::new(),
            })
        }
    }
}
