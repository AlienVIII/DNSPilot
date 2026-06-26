# Linux UX Spec

## Scope

- Linux is capability-based, not one platform.
- Main app must work without tray support. Tray is optional because GNOME and
  Wayland environments can suppress or omit tray behavior.
- Store/sandbox packages are benchmark and guidance first.
- Real DNS mutation is only for native power packages with explicit
  NetworkManager/systemd-resolved and polkit support.
- Flatpak, Snap, deb, and rpm must not be described as feature-parity targets.

## Capability Matrix

| Package | Benchmark DNS | Benchmark DNS + TCP | Current resolver validation | Guided settings | Real DNS apply |
| --- | --- | --- | --- | --- | --- |
| Flatpak | Yes | Yes | Only if explicitly supported by probe | Yes | No |
| Snap | Yes | Yes | Only if explicitly supported by probe | Yes | No |
| deb | Yes | Yes | Only if explicitly supported by probe | No | Yes with resolver stack + polkit |
| rpm | Yes | Yes | Only if explicitly supported by probe | No | Yes with resolver stack + polkit |

Notes:
- Snap `network-manager` is privileged and not auto-connected, so the store-safe
  Snap lane must not promise DNS apply.
- deb/rpm without NetworkManager or systemd-resolved plus polkit is
  diagnostics-only for apply.
- Capability detection has a non-mutating runtime path plus mocked snapshot
  inputs for deterministic CI and later QA.

CLI detection example:

```sh
cargo run --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- detect

cargo run --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- detect \
  --mock-env FLATPAK_ID=com.example.DNSPilot \
  --mock-command nmcli \
  --mock-command pkcheck
```

Readiness checkpoint:

```sh
cargo run --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- readiness
```

The readiness report marks scoped Linux code goals as ready and separates
manual package QA, store credentials, signing, screenshots, release notes, GUI
adapter choice, and real resolver-write QA as external release work.

## Native App Surface

The Linux shell exposes a native app view-model for the eventual GTK/libadwaita
or Qt adapter. The main app surface is the primary UX; tray integration is
optional and never required for GNOME/Wayland.

CLI app-model example:

```sh
cargo run --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- app-model \
  --package deb \
  --network-manager \
  --polkit \
  --system-resolver-probe \
  --lang vi
```

The view-model includes:

- benchmark,
- profile management,
- settings/apply path,
- diagnostics/debug report,
- permissions.

English and Vietnamese are supported for the Linux shell's primary app and
permission surfaces. Guided settings also supports `--lang en|vi`.

## Permissions

Permission UX is package-specific:

- Flatpak requests outbound network and desktop-window permissions for
  benchmark/guidance. It does not request system DNS mutation.
- Snap requests strict outbound network and desktop-window permissions. It does
  not include the privileged `network-manager` plug in the store-safe build.
- deb/rpm native power packages require polkit plus NetworkManager D-Bus or
  systemd-resolved before real DNS apply is offered.

CLI permission example:

```sh
cargo run --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- permissions \
  --package snap \
  --lang en

cargo run --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- permissions \
  --package deb \
  --network-manager \
  --polkit \
  --system-resolver-probe \
  --lang vi
```

## Benchmark Modes

- `DNS only`: direct DNS lookup benchmark.
- `DNS + TCP`: direct DNS lookup plus connection-path TCP probe.
- `Current/system resolver`: validates the active resolver path after a manual
  or native apply only when the capability probe says it is supported.

Unsupported modes are rejected before any run starts.

## Process UI

Each run has per-step status and per-resolver status:

- `idle`
- `running`
- `success`
- `failed`

Step sets are mode-specific:

- DNS only: detect capabilities, prepare benchmark, run DNS benchmark, build diagnostics.
- DNS + TCP: detect capabilities, prepare benchmark, run DNS benchmark, run TCP probe, build diagnostics.
- Current/system resolver: detect capabilities, prepare benchmark, validate current resolver, build diagnostics.

## Result Diagnostics

Every run can produce a copyable debug report with:

- distro/package context,
- benchmark mode,
- apply path,
- system resolver validation support,
- tray expectation,
- step statuses,
- resolver statuses,
- capability notes.

The Linux CLI harness renders this report from mocked inputs:

```sh
cargo run --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- \
  --package flatpak --mode dns-tcp
```

Native deb/rpm mock:

```sh
cargo run --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- \
  --package deb --network-manager --polkit --system-resolver-probe --mode system-resolver
```

## Core CLI Runner Boundary

Linux shell planning now builds core CLI commands without duplicating benchmark
logic:

- DNS only uses `compare`.
- DNS + TCP uses `path-compare`.
- Current/system resolver uses `system-benchmark`.
- Direct benchmark modes request `--progress-jsonl` and parse resolver progress
  from stderr.
- Unsupported modes are rejected before the runner is invoked.
- The concrete process runner captures stdout, stderr, and exit code from a
  caller-supplied core CLI path.

CLI plan example:

```sh
cargo run --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- plan \
  --store /tmp/dnspilot-linux-profiles.json \
  --package snap \
  --profile-id local \
  --resolver-family ipv4 \
  --record-family a \
  --suite-id vietnam-daily \
  --domain login.microsoftonline.com
```

CLI run example:

```sh
cargo run --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- run \
  --core-cli /path/to/dnspilot-cli \
  --store /tmp/dnspilot-linux-profiles.json \
  --package flatpak \
  --profile-id local \
  --domain github.com
```

## Settings And Apply

Flatpak and Snap expose guided settings only. Guided actions copy values and
open OS guidance; they do not mutate DNS.

CLI guide example:

```sh
cargo run --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- guide \
  --store /tmp/dnspilot-linux-profiles.json \
  --package flatpak \
  --profile-id local \
  --lang vi
```

Native power package plan:

1. Detect active connection and DNS ownership through NetworkManager D-Bus.
2. Fall back to systemd-resolved for resolved-managed links and DNS state validation.
3. Require polkit authorization before writing resolver settings.
4. Flush/validate through the supported resolver stack, then rerun current/system resolver validation.

Native apply contract CLI example:

```sh
cargo run --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- apply-plan \
  --store /tmp/dnspilot-linux-profiles.json \
  --package deb \
  --network-manager \
  --polkit \
  --system-resolver-probe \
  --profile-id local \
  --resolver-family ipv4
```

The apply plan rejects Flatpak/Snap, requires a supported resolver stack plus
polkit, selects NetworkManager before systemd-resolved when both are available,
filters DNS servers by IPv4/IPv6 selection, requires rollback snapshot, and
includes post-apply current/system resolver validation when supported.

## Custom Profiles

The Linux shell package includes view-model support for custom plain DNS
profiles:

- add,
- edit,
- delete,
- list,
- IPv4 server validation,
- IPv6 server validation,
- duplicate server rejection,
- duplicate profile ID rejection.

Profiles can be persisted in a Linux shell JSON store with schema version 1:

```sh
cargo run --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- profile-add \
  --store /tmp/dnspilot-linux-profiles.json \
  --id local \
  --name "Local DNS" \
  --ipv4 1.1.1.1 \
  --ipv6 2606:4700:4700::1111

cargo run --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- profile-list \
  --store /tmp/dnspilot-linux-profiles.json

cargo run --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- profile-edit \
  --store /tmp/dnspilot-linux-profiles.json \
  --id local \
  --name "Edited DNS" \
  --ipv4 9.9.9.9 \
  --ipv6 2620:fe::fe

cargo run --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- profile-delete \
  --store /tmp/dnspilot-linux-profiles.json \
  --id local
```

Encrypted DNS profile apply is out of scope for this lane until the core
contract exposes a Linux-safe apply strategy.

## Family Controls

Resolver address family:

- `Auto`: use all DNS server addresses in the profile.
- `IPv4`: use only IPv4 DNS servers.
- `IPv6`: use only IPv6 DNS servers.

DNS record family:

- `A + AAAA`: balanced IPv4/IPv6 answer measurement.
- `A only`: IPv4 answers only; useful when IPv6 is broken.
- `AAAA only`: IPv6 answers only for IPv6-specific troubleshooting.

All controls carry hover/help text in the view model.

## Suites

Default suites:

- General.
- Developer.
- Microsoft login.

Vietnam suite is included only when the catalog capability supports it:

- Vietnam daily: `zing.vn`, `vnexpress.net`, `momo.vn`.

## Later QA

Do not block Linux lane completion on manual distro/package testing. Later QA
should verify real Flatpak/Snap/deb/rpm packaging behavior, portal/settings
handoff, NetworkManager D-Bus writes, systemd-resolved writes, polkit prompts,
and distro resolver-stack differences.

Publish and manual real-device steps live in `linux-publish-checklist.md`.
