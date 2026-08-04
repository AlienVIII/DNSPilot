#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/DNSPilot.app"
NO_OPEN=0
DRY_RUN=0

usage() {
  cat >&2 <<USAGE
usage: $0 [--no-open] [--dry-run]

Builds, locally signs, validates, and opens DNS Pilot from this source checkout.

Options:
  --no-open  Build and validate without opening the app.
  --dry-run  Check prerequisites and print the build command without building.

Output:
  dist/DNSPilot.app
USAGE
}

fail() {
  printf 'ERROR %s\n' "$1" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --no-open)
      NO_OPEN=1
      ;;
    --dry-run)
      DRY_RUN=1
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

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "DNS Pilot source builds are currently supported on macOS only."
fi

macos_version="$(sw_vers -productVersion 2>/dev/null || true)"
macos_major="${macos_version%%.*}"
if [[ ! "$macos_major" =~ ^[0-9]+$ ]] || (( macos_major < 14 )); then
  fail "macOS 14 or later is required; detected ${macos_version:-unknown}."
fi

if ! xcode-select -p >/dev/null 2>&1 || ! command -v swift >/dev/null 2>&1; then
  fail $'Xcode Command Line Tools are required. Run:\n  xcode-select --install\nThen reopen Terminal and run this command again.'
fi

swift_version_output="$(swift --version 2>&1)"
if [[ "$swift_version_output" =~ Swift[[:space:]]+version[[:space:]]+([0-9]+) ]]; then
  swift_major="${BASH_REMATCH[1]}"
else
  swift_major=""
fi
if [[ -z "$swift_major" || "$swift_major" -lt 6 ]]; then
  fail $'Swift 6 or later is required. Update Xcode or Xcode Command Line Tools, then run this command again.'
fi

if ! command -v cargo >/dev/null 2>&1; then
  fail $'Rust stable with Cargo is required. Install it from https://rustup.rs, reopen Terminal, then run this command again.'
fi

build_args=(--verify)
if (( NO_OPEN )); then
  build_args+=(--no-open)
fi

if (( DRY_RUN )); then
  printf 'Prerequisites available: macOS %s, Swift %s, Cargo.\n' "$macos_version" "$swift_major"
  printf 'Build command: %q' "$ROOT_DIR/script/build_and_run.sh"
  printf ' %q' "${build_args[@]}"
  printf '\nOutput: %s\n' "$APP_BUNDLE"
  exit 0
fi

printf 'Building DNS Pilot from source.\n'
"$ROOT_DIR/script/build_and_run.sh" "${build_args[@]}"

printf '\nDNS Pilot is ready: %s\n' "$APP_BUNDLE"
if (( NO_OPEN )); then
  printf 'Open it with: open %q\n' "$APP_BUNDLE"
else
  printf 'The app has opened. Reopen it later with: open %q\n' "$APP_BUNDLE"
fi
printf 'For personal use, drag DNSPilot.app to Applications or run it from dist.\n'
