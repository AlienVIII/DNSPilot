# Linux Publish Checklist

## Status

This lane is ready for automated Rust validation and later real-device package
QA. It is not yet a production consumer or publisher-ready build. Follow
`linux-completion-plan.md` and `linux-implementation-plan.md` before submission.
Start with `apps/linux/README.md` for install, build, run, smoke, and native
helper commands.

Shared gate references:

- UX copy/onboarding contract: `docs/ux-copy-onboarding.md`.
- OS provider trust/manual store steps: `docs/os-provider-trust.md`.

Current package split:

- Flatpak: store-safe benchmark and guided settings only.
- Snap: strict store-safe benchmark and guided settings only.
- deb/rpm: native package path; Power remains disabled/experimental until the real
  system D-Bus, caller-bound polkit, exact rollback, and Linux-host gates pass.

## Required Publisher And Site Setup

As of 2026-07-11, `dnspilot.io` does not resolve. Before any store/repository
submission:

1. Configure the chosen product domain in the DNS provider and enable HTTPS.
2. Host public homepage, support, and privacy pages. If the domain differs from
   `dnspilot.io`, update the AppStream URLs and maintainer addresses first.
3. Publish the source repository and create an immutable `v0.1.0` tag/archive
   for Flathub source review.
4. Verify the public surfaces:

```sh
curl -fsS https://dnspilot.io/ >/dev/null
curl -fsS https://dnspilot.io/support >/dev/null
curl -fsS https://dnspilot.io/privacy >/dev/null
git ls-remote --tags <public-source-url> refs/tags/v0.1.0
```

5. Create/sign in to the Flathub submission account and Snapcraft publisher
   account. Keep credentials outside the repository.

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
cargo test -p dnspilot-cli
cargo build --manifest-path apps/linux/DNSPilotLinux/Cargo.toml
cargo build -p dnspilot-cli
```

Release payload and package commands:

```sh
cargo build --manifest-path apps/linux/DNSPilotLinux/Cargo.toml --release
cargo build --release -p dnspilot-cli
apps/linux/scripts/build-packages.sh stage
# Use flatpak, snap, deb, rpm, or all after the stage gate passes.
```

Expected release binaries:

- `apps/linux/DNSPilotLinux/target/release/dnspilot-linux-gui` for the desktop launcher,
- `apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell` for CLI inspection/QA,
- repo-root `target/release/dnspilot-cli` for the benchmark engine,

Smoke the native-facing surfaces:

```sh
apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell detect
apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell readiness
apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell publish-check --package all
apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell publish-check --package flatpak
apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell publish-check --package deb --network-manager --polkit --system-resolver-probe
apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell app-model --package flatpak --lang vi
apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell permissions --package snap
apps/linux/DNSPilotLinux/target/release/dnspilot-linux-shell permissions --package deb --network-manager --polkit --system-resolver-probe
```

## Flatpak Local QA

1. Install `org.freedesktop.Platform` and `org.freedesktop.Sdk` 25.08 from
   Flathub on the Linux build host.
2. Confirm manifest stays store-safe:

```sh
rg -- '--share=network|--socket=system-bus|org.freedesktop.NetworkManager|org.freedesktop.resolve1' apps/linux/packaging/flatpak
```

Expected:

- `--share=network` exists.
- `--socket=system-bus` does not exist.
- NetworkManager/systemd-resolved bus access does not exist.

3. Build, then install locally with Flatpak Builder:

```sh
apps/linux/scripts/build-packages.sh flatpak
flatpak-builder --force-clean --user --install apps/linux/dist/flatpak-build apps/linux/packaging/flatpak/io.dnspilot.DNSPilot.yml
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

Review `docs/os-provider-trust.md` before starting so Flathub verification,
publisher proof, support/privacy URLs, screenshots, and package QA evidence can
be batched once.

1. Make sure Flatpak local QA passes.
2. Add screenshots, release notes, and final AppStream metadata required by
   Flathub.
3. Open the app submission PR using app id `io.dnspilot.DNSPilot`.
4. In the PR description, state explicitly:

- Flatpak build is benchmark/guidance only.
- It does not request system bus access.
- It does not mutate system DNS.

## Snap Local QA

1. Build the strict Snap; the script stages the shared payload automatically:

```sh
apps/linux/scripts/build-packages.sh snap
```

2. Install and inspect connections:

```sh
sudo snap install --dangerous apps/linux/dist/dnspilot_0.1.0.snap
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
snapcraft upload --release=edge apps/linux/dist/dnspilot_0.1.0.snap
```

3. In store notes, state that native DNS apply is not part of the strict Snap.

## deb/rpm Benchmark-First QA

1. Build and install locally on a Debian-family Linux host:

```sh
apps/linux/scripts/build-packages.sh deb
sudo apt install ./apps/linux/dist/deb/dnspilot_0.1.0_*.deb
```

2. Verify the installed package is non-privileged:

```sh
dnspilot-linux-shell detect
dnspilot-linux-shell permissions --package deb --network-manager --polkit --system-resolver-probe
test ! -e /usr/libexec/dnspilot/dnspilot-native-helper
test ! -e /usr/share/polkit-1/actions/io.dnspilot.DNSPilot.apply.policy
```

Expected:

- no native helper or polkit action is installed,
- automatic DNS mutation is unavailable even when resolver-stack tools are detected,
- current/system resolver validation can run after apply if supported.

## rpm Benchmark-First QA

1. Build and install locally on an RPM-family Linux host:

```sh
apps/linux/scripts/build-packages.sh rpm
sudo dnf install ./apps/linux/dist/rpmbuild/RPMS/*/dnspilot-0.1.0-1*.rpm
```

2. Repeat the deb/rpm non-privileged package checks.

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
- deb/rpm native apply is unavailable until the completed Power mechanism requires
  polkit, a supported resolver stack, exact rollback, and configuration identity checks.

## Known Release Risks

- The checked-in build script and recipes are structurally tested; real
  Flatpak/Snap/deb/rpm artifacts still need package-tool validation on Linux.
- Flathub submission needs a public immutable source tag/archive and generated
  Cargo source manifest; the local manifest intentionally consumes verified
  Linux ELF payloads for pre-submission QA.
- `dnspilot.io` homepage/support/privacy URLs must resolve over HTTPS before
  metadata submission.
- The native GUI launcher compiles in this lane; real GNOME/Wayland rendering
  still needs package-tool validation on Linux.
- The development-only helper rejects execute requests and is excluded from every
  release payload. A Power service must be separately designed and verified.
