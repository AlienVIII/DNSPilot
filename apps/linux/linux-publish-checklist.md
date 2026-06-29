# Linux Publish Checklist

## Status

This lane is ready for automated Rust validation and later real-device package
QA. It does not require manual distro/package testing before handoff.

Current package split:

- Flatpak: store-safe benchmark and guided settings only.
- Snap: strict store-safe benchmark and guided settings only.
- deb/rpm: native power package path for future DNS apply through
  NetworkManager/systemd-resolved plus polkit.

## Official References

- Flatpak sandbox permissions: https://docs.flatpak.org/en/latest/sandbox-permissions.html
- Flathub metainfo guidelines: https://docs.flathub.org/docs/for-app-authors/metainfo-guidelines/
- Snap network interface: https://snapcraft.io/docs/reference/interfaces/network-interface/
- Snap network-manager interface: https://snapcraft.io/docs/reference/interfaces/network-manager-interface/
- NetworkManager D-Bus API: https://networkmanager.dev/docs/api/latest/spec.html
- polkit actions: https://polkit.pages.freedesktop.org/polkit/polkit.8.html

## Automated Gate

Run from repo root:

```sh
cargo fmt --manifest-path apps/linux/DNSPilotLinux/Cargo.toml --check
cargo test --manifest-path apps/linux/DNSPilotLinux/Cargo.toml
cargo clippy --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- -D warnings
cargo build --manifest-path apps/linux/DNSPilotLinux/Cargo.toml
```

Release binary:

```sh
cargo build --manifest-path apps/linux/DNSPilotLinux/Cargo.toml --release
```

Smoke the native-facing surfaces:

```sh
apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell detect
apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell readiness
apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell app-model --package flatpak --lang vi
apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell permissions --package snap
apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell permissions --package deb --network-manager --polkit --system-resolver-probe
```

## Flatpak Local QA

1. Build release binary.
2. Confirm manifest stays store-safe:

```sh
rg -- '--share=network|--socket=system-bus|org.freedesktop.NetworkManager|org.freedesktop.resolve1' apps/linux/packaging/flatpak
```

Expected:

- `--share=network` exists.
- `--socket=system-bus` does not exist.
- NetworkManager/systemd-resolved bus access does not exist.

3. Build/install locally with Flatpak Builder from the repo root or adjust the
   manifest source paths for the builder working directory:

```sh
flatpak-builder --force-clean --user --install build-flatpak apps/linux/packaging/flatpak/io.dnspilot.DNSPilot.yml
flatpak run io.dnspilot.DNSPilot
```

4. Validate metadata:

```sh
appstreamcli validate apps/linux/packaging/shared/io.dnspilot.DNSPilot.metainfo.xml
desktop-file-validate apps/linux/packaging/shared/io.dnspilot.DNSPilot.desktop
```

5. Manual flow:

- app starts without tray,
- Vietnamese strings render when language is `vi`,
- DNS only and DNS + TCP benchmarks run,
- guided settings copies DNS values and does not mutate system DNS,
- copyable debug report includes package, mode, process status, resolver status,
  and capability notes.

## Flathub Submission

1. Make sure Flatpak local QA passes.
2. Add screenshots, release notes, and final AppStream metadata required by
   Flathub.
3. Open the app submission PR using app id `io.dnspilot.DNSPilot`.
4. In the PR description, state explicitly:

- Flatpak build is benchmark/guidance only.
- It does not request system bus access.
- It does not mutate system DNS.

## Snap Local QA

1. Build release binary.
2. Build a `snap-payload` directory matching `snapcraft.yaml`:

```sh
mkdir -p apps/linux/packaging/snap-payload
cp apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell apps/linux/packaging/snap-payload/
cp apps/linux/packaging/shared/io.dnspilot.DNSPilot.desktop apps/linux/packaging/snap-payload/
cp apps/linux/packaging/shared/io.dnspilot.DNSPilot.metainfo.xml apps/linux/packaging/snap-payload/
cp apps/linux/packaging/shared/io.dnspilot.DNSPilot.svg apps/linux/packaging/snap-payload/
```

3. Pack and install:

```sh
cd apps/linux/packaging/snap
snapcraft pack
sudo snap install --dangerous dnspilot_0.1.0_*.snap
snap connections dnspilot
dnspilot
```

Expected:

- `network` is connected.
- no privileged network-manager/network-control plug is requested.
- DNS apply is not shown as available in the Snap build.

## Snap Store Submission

1. Make sure strict local QA passes.
2. Register/upload/release with Snapcraft credentials:

```sh
snapcraft login
snapcraft register dnspilot
snapcraft upload --release=edge dnspilot_0.1.0_*.snap
```

3. In store notes, state that native DNS apply is not part of the strict Snap.

## deb Native Power QA

1. Build release binary.
2. Wire `apps/linux/packaging/deb/control`, shared metadata, binary install,
   and polkit policy into the final Debian packaging tree.
3. Build and install locally:

```sh
debuild -us -uc
sudo apt install ./dnspilot_0.1.0_*.deb
```

4. Verify host capabilities:

```sh
nmcli --version || true
resolvectl --version || true
pkcheck --version
dnspilot-linux-shell detect
dnspilot-linux-shell permissions --package deb --network-manager --polkit --system-resolver-probe
dnspilot-linux-shell apply-plan --store /tmp/dnspilot-linux-profiles.json --package deb --network-manager --polkit --system-resolver-probe --profile-id local --resolver-family auto
dnspilot-native-helper --contract
dnspilot-native-helper --dry-run --stack networkmanager --server 1.1.1.1
dnspilot-native-helper --request-json '{"schema_version":1,"polkit_action_id":"io.dnspilot.DNSPilot.apply-dns","resolver_stack":"networkmanager","servers":["1.1.1.1"],"rollback_snapshot":true,"validate_after_apply":true,"mutation_mode":"dry-run"}'
```

Expected:

- native apply plan is offered only when NetworkManager or systemd-resolved plus
  polkit are detected,
- native helper contract/dry-run/request protocol works without writing DNS,
- execute-mode requests require `confirm_system_dns_mutation: true` and stay
  disabled until the native write backend passes package QA,
- polkit prompt appears before any DNS write after the backend is enabled,
- current/system resolver validation can run after apply if supported.

## rpm Native Power QA

1. Build release binary.
2. Wire `apps/linux/packaging/rpm/dnspilot-linux.spec`, shared metadata, binary
   install, and polkit policy into the final RPM build tree.
3. Build and install locally:

```sh
rpmbuild -ba dnspilot-linux.spec
sudo dnf install ./dnspilot-0.1.0-*.rpm
```

4. Repeat the deb native power QA capability and polkit checks.

## Manual Real-Device Acceptance

- Main window works without tray on GNOME Wayland.
- Tray presence/absence does not block benchmark/profile/diagnostics flows.
- Add/edit/delete custom DNS profiles.
- IPv4/IPv6 resolver-family controls have help text and affect benchmark plans.
- A/AAAA record-family controls have help text and affect benchmark plans.
- Default suites and Vietnam suite appear where catalog support is enabled.
- DNS only benchmark produces per-step and per-resolver success/failure states.
- DNS + TCP benchmark includes TCP probe status.
- Current/system resolver validation appears only when supported.
- Debug report copies complete capability, process, resolver, and result context.
- Flatpak/Snap never mutate system DNS.
- deb/rpm native apply requires polkit and supported resolver stack.

## Known Release Risks

- The checked-in packaging files are policy templates; real Flatpak/Snap/deb/rpm
  builds still need package-tool validation on Linux.
- The native UI adapter is represented by app view-model and desktop metadata;
  GTK/libadwaita or Qt binding remains a separate implementation step.
- The native power helper contract is implemented with a non-mutating dry-run
  lifecycle and an execute mutation gate; resolver write backend/package QA is
  still required before real DNS mutation is enabled.
