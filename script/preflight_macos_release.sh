#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DNSPilotMac"
INCLUDE_POWER=0
SKIP_CARGO=0
SKIP_SWIFT=0
SKIP_LAUNCH=0

usage() {
  cat >&2 <<USAGE
usage: $0 [--include-power] [--skip-cargo] [--skip-swift] [--skip-launch]

Runs the local macOS release gate before signing or upload.

Default:
  - shell syntax check for release scripts
  - Rust workspace tests
  - macOS Swift package tests
  - Store-safe sandbox bundle validation

Options:
  --include-power  Also validate a Power edition sandbox bundle.
  --skip-cargo     Skip Rust tests.
  --skip-swift     Skip Swift tests.
  --skip-launch    Skip bundle launch/structural validation.
USAGE
}

while (($#)); do
  case "$1" in
    --include-power)
      INCLUDE_POWER=1
      ;;
    --skip-cargo)
      SKIP_CARGO=1
      ;;
    --skip-swift)
      SKIP_SWIFT=1
      ;;
    --skip-launch)
      SKIP_LAUNCH=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
  shift
done

cleanup() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

run_step() {
  local label="$1"
  shift
  printf "\n==> %s\n" "$label"
  "$@"
}

trap cleanup EXIT

cd "$ROOT_DIR"

run_step "Shell syntax" \
  bash -n \
    script/build_and_run.sh \
    script/validate_macos_bundle.sh \
    script/package_macos_distribution.sh \
    script/preflight_macos_release.sh

if (( ! SKIP_CARGO )); then
  run_step "Rust workspace tests" cargo test --workspace --tests
fi

if (( ! SKIP_SWIFT )); then
  run_step "macOS Swift tests" swift test --package-path apps/macos/DNSPilotMac
fi

if (( ! SKIP_LAUNCH )); then
  run_step "Store-safe sandbox bundle validation" ./script/build_and_run.sh --sandbox-verify

  if (( INCLUDE_POWER )); then
    run_step "Power sandbox bundle validation" \
      env DNSPILOT_POWER_EDITION=1 ./script/build_and_run.sh --sandbox-verify

    run_step "Restore Store-safe sandbox bundle" ./script/build_and_run.sh --sandbox-verify
  fi
fi

printf "\nmacOS release preflight passed.\n"
