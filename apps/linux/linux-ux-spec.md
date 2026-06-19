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
- Capability detection is mocked in the current Linux shell package so CI can
  validate behavior without distro mutation.

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

## Settings And Apply

Flatpak and Snap expose guided settings only. Guided actions copy values and
open OS guidance; they do not mutate DNS.

Native power package plan:

1. Detect active connection and DNS ownership through NetworkManager D-Bus.
2. Fall back to systemd-resolved for resolved-managed links and DNS state validation.
3. Require polkit authorization before writing resolver settings.
4. Flush/validate through the supported resolver stack, then rerun current/system resolver validation.

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
