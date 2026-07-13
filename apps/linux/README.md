# DNS Pilot Linux

Linux is capability-based in DNS Pilot. Flatpak and Snap are store-safe
benchmark/guidance builds. deb/rpm are native packages with a future, separately
gated Power capability for NetworkManager/systemd-resolved plus polkit.

Current completion design and task order:

- `apps/linux/linux-completion-plan.md`
- `apps/linux/linux-implementation-plan.md`

The current command-backed native execute prototype is not release-safe. Default
package guidance must remain benchmark/preview only until the planned system D-Bus,
caller-bound polkit, and exact rollback mechanism is implemented and proved on Linux.

## Binaries

- `dnspilot-linux-gui`: desktop launcher and primary UX.
- `dnspilot-linux-shell`: CLI inspection, QA, profile, readiness, and publish
  helper.
- `dnspilot-cli`: packaged core benchmark engine used by the GUI.
- `dnspilot-native-helper`: experimental native deb/rpm contract/dry-run helper; do
  not use execute mode.

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

Flatpak uses `org.freedesktop.Platform`/`Sdk` 25.08. Install that runtime from
Flathub on the Flatpak build host. Snap remains on the supported `core24` base.

## Build And Run

From repo root:

```sh
cargo build -p dnspilot-cli
cargo build --manifest-path apps/linux/DNSPilotLinux/Cargo.toml
DNSPILOT_CLI_PATH="$PWD/target/debug/dnspilot-cli" \
  cargo run --manifest-path apps/linux/DNSPilotLinux/Cargo.toml --bin dnspilot-linux-gui
```

In the GUI, the Benchmark tab is the primary no-tray workflow. It shows
capability-gated benchmark modes, selected DNS profiles, suite/domain controls,
IPv4/IPv6 and A/AAAA controls, a process status table, and copyable diagnostics.
Benchmark commands run on a background worker, so the main window stays
responsive and prevents duplicate runs until the active job reaches a terminal
state.
The Settings tab selects one profile and address family. Flatpak/Snap copy the
filtered DNS values and render an in-app manual guide without mutation;
capable deb/rpm builds render the exact native apply plan for review.
Installed packages place `dnspilot-cli` beside the GUI, so normal users do not
configure an engine path. `DNSPILOT_CLI_PATH` is only a development/QA override.

Release binaries:

```sh
cargo build --release -p dnspilot-cli
cargo build --manifest-path apps/linux/DNSPilotLinux/Cargo.toml --release
ls apps/linux/DNSPilotLinux/target/release/dnspilot-linux-gui \
   apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell \
   apps/linux/DNSPilotLinux/target/release/dnspilot-native-helper \
   target/release/dnspilot-cli
```

## Automated Gate

```sh
cargo fmt --manifest-path apps/linux/DNSPilotLinux/Cargo.toml --check
cargo test --manifest-path apps/linux/DNSPilotLinux/Cargo.toml
cargo clippy --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- -D warnings
cargo test -p dnspilot-cli
cargo build --manifest-path apps/linux/DNSPilotLinux/Cargo.toml
cargo build --manifest-path apps/linux/DNSPilotLinux/Cargo.toml --release
cargo build --release -p dnspilot-cli
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

Do not run execute mode. The current prototype checks authorization but does not provide
a complete privileged mechanism or exact DNS rollback snapshot. Milestone 0 disables
it by default; Milestone 7 replaces it before native Power release QA.

## Package QA

The package pipeline builds locked release binaries, rejects non-Linux payloads,
validates AppStream/desktop metadata, and stages the same payload for every
format:

```sh
apps/linux/scripts/build-packages.sh stage
apps/linux/scripts/build-packages.sh flatpak
apps/linux/scripts/build-packages.sh snap
apps/linux/scripts/build-packages.sh deb
apps/linux/scripts/build-packages.sh rpm
# Or all formats when every package tool is installed:
apps/linux/scripts/build-packages.sh all
```

Artifacts and temporary roots are written under `apps/linux/dist/`. Detailed
install, smoke, store, and rollback steps live in
`apps/linux/linux-publish-checklist.md`.

Manual gates remain:

- real Flatpak/Snap/deb/rpm package builds and QA on Linux,
- live HTTPS homepage/support/privacy URLs and a public immutable source tag,
- store credentials/signing/screenshots/release notes,
- real-device validation before publishing native DNS mutation.
