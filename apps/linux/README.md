# DNS Pilot Linux

Linux is capability-based in DNS Pilot. Flatpak and Snap are store-safe
benchmark/guidance builds. deb/rpm are native power builds that can use
NetworkManager or systemd-resolved with polkit.

## Binaries

- `dnspilot-linux-gui`: desktop launcher and primary UX.
- `dnspilot-linux-shell`: CLI inspection, QA, profile, readiness, and publish
  helper.
- `dnspilot-native-helper`: native deb/rpm helper for DNS apply contracts and
  explicit native power execution.

## Install Dependencies

Rust toolchain:

```sh
rustc --version
cargo --version
```

Linux package tools for later QA, installed on the target Linux VM/device:

```sh
# Debian/Ubuntu
sudo apt install build-essential pkg-config libgtk-3-dev libxkbcommon-dev \
  libwayland-dev libx11-dev libxcursor-dev libxi-dev libxrandr-dev \
  flatpak-builder appstream desktop-file-utils snapcraft devscripts rpm \
  network-manager systemd-resolved polkitd

# Fedora/RHEL family
sudo dnf install gcc pkg-config gtk3-devel libxkbcommon-devel \
  wayland-devel libX11-devel libXcursor-devel libXi-devel libXrandr-devel \
  flatpak-builder appstream desktop-file-utils snapcraft rpm-build \
  NetworkManager systemd-resolved polkit
```

## Build And Run

From repo root:

```sh
cargo build --manifest-path apps/linux/DNSPilotLinux/Cargo.toml
cargo run --manifest-path apps/linux/DNSPilotLinux/Cargo.toml --bin dnspilot-linux-gui
```

In the GUI, the Benchmark tab is the primary no-tray workflow. It shows
capability-gated benchmark modes, selected DNS profiles, suite/domain controls,
IPv4/IPv6 and A/AAAA controls, a process status table, and copyable diagnostics.

Release binaries:

```sh
cargo build --manifest-path apps/linux/DNSPilotLinux/Cargo.toml --release
ls apps/linux/DNSPilotLinux/target/release/dnspilot-linux-gui \
   apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell \
   apps/linux/DNSPilotLinux/target/release/dnspilot-native-helper
```

## Automated Gate

```sh
cargo fmt --manifest-path apps/linux/DNSPilotLinux/Cargo.toml --check
cargo test --manifest-path apps/linux/DNSPilotLinux/Cargo.toml
cargo clippy --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- -D warnings
cargo build --manifest-path apps/linux/DNSPilotLinux/Cargo.toml
cargo build --manifest-path apps/linux/DNSPilotLinux/Cargo.toml --release
```

## CLI Smoke

```sh
apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell readiness
apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell detect
apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell app-model --package flatpak --lang vi
apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell permissions --package deb --network-manager --polkit --system-resolver-probe
apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell publish-check --package all
apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell publish-check --package deb --network-manager --polkit --system-resolver-probe
```

## Profiles

```sh
STORE=/tmp/dnspilot-linux-profiles.json

apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell profile-add \
  --store "$STORE" \
  --id local \
  --name "Local DNS" \
  --ipv4 1.1.1.1 \
  --ipv6 2606:4700:4700::1111

apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell profile-list --store "$STORE"
```

## Native Power Helper

Dry-run and contract commands never mutate DNS:

```sh
apps/linux/DNSPilotLinux/target/release/dnspilot-native-helper --contract
apps/linux/DNSPilotLinux/target/release/dnspilot-native-helper \
  --dry-run --stack networkmanager --server 1.1.1.1
```

Execute mode is for deb/rpm native package QA only. It requires both
`confirm_system_dns_mutation: true` in the request and
`--allow-system-dns-mutation` on the helper command:

```sh
apps/linux/DNSPilotLinux/target/release/dnspilot-native-helper \
  --allow-system-dns-mutation \
  --request-json '{"schema_version":1,"polkit_action_id":"io.dnspilot.DNSPilot.apply-dns","resolver_stack":"networkmanager","servers":["1.1.1.1"],"rollback_snapshot":true,"validate_after_apply":true,"mutation_mode":"execute","confirm_system_dns_mutation":true}'
```

Do not run execute mode in Flatpak/Snap. Do not enable it by default before real
Linux package QA validates polkit prompts, rollback, and resolver behavior.

## Package QA

Detailed steps live in `apps/linux/linux-publish-checklist.md`.

Manual gates remain:

- real Flatpak/Snap/deb/rpm package builds and QA on Linux,
- store credentials/signing/screenshots/release notes,
- real-device validation before publishing native DNS mutation.
