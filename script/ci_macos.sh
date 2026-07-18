#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_step() {
  printf "\n==> %s\n" "$1"
}

run_step "Rust formatting"
cargo fmt --all -- --check

run_step "Rust workspace tests"
cargo test --workspace --tests

run_step "macOS Swift tests"
swift test --package-path "$ROOT_DIR/apps/macos/DNSPilotMac"

run_step "macOS UI localization guard"
if rg -n 'EN:|VI:' "$ROOT_DIR/apps/macos/DNSPilotMac/Sources" --glob '*.swift'; then
  printf "UI copy must use one active locale; move bilingual tooltip text into Localizable.strings.\n" >&2
  exit 1
fi
if rg -n '(Text|Label|Button|DisclosureGroup)\("[A-Za-z]|\.help\("[A-Za-z]|confirmationDialog\("[A-Za-z]' \
  "$ROOT_DIR/apps/macos/DNSPilotMac/Sources" --glob '*.swift'; then
  printf "User-facing macOS copy must use DNSPilotLocalizer keys.\n" >&2
  exit 1
fi

run_step "macOS sandbox bundle verification"
"$ROOT_DIR/script/build_and_run.sh" --sandbox-verify

run_step "DNS-only live smoke"
"$ROOT_DIR/script/smoke_quick_benchmark.sh" dns-only

run_step "DNS + TCP live smoke"
"$ROOT_DIR/script/smoke_quick_benchmark.sh"

if [[ -n "${DNSPILOT_DISTRIBUTION_BUNDLE:-}" ]]; then
  run_step "Distribution bundle verification"
  "$ROOT_DIR/script/validate_macos_bundle.sh" "$DNSPILOT_DISTRIBUTION_BUNDLE" --distribution
else
  printf "\nSKIP distribution bundle verification; set DNSPILOT_DISTRIBUTION_BUNDLE to a signed .app bundle.\n"
fi
