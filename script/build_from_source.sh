#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/DNSPilot.app"
INSTALLED_APP="${HOME:?}/Applications/DNS Pilot.app"
NO_OPEN=0
DRY_RUN=0
NO_INSTALL=0
POWER_EDITION=0

usage() {
  cat >&2 <<USAGE
usage: $0 [--power] [--no-open] [--no-install] [--dry-run]

Builds, locally signs, validates, and installs DNS Pilot for the current user.

Options:
  --power       Build the direct-install edition with confirmed admin DNS actions.
  --no-open     Build and install without opening the app.
  --no-install  Keep the app in dist for development instead of installing it.
  --dry-run     Check prerequisites and print the build command without building.

Output:
  ~/Applications/DNS Pilot.app
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
    --power)
      POWER_EDITION=1
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    --no-install)
      NO_INSTALL=1
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

build_args=(--verify --no-open)

if (( DRY_RUN )); then
  printf 'Prerequisites available: macOS %s, Swift %s, Cargo.\n' "$macos_version" "$swift_major"
  if (( POWER_EDITION )); then
    printf 'Edition: Power direct-install (outside App Sandbox).\n'
    printf 'Build environment: DNSPILOT_POWER_EDITION=1\n'
  else
    printf 'Edition: Store-safe.\n'
  fi
  printf 'Build command: %q' "$ROOT_DIR/script/build_and_run.sh"
  printf ' %q' "${build_args[@]}"
  if (( NO_INSTALL )); then
    printf '\nOutput: %s\n' "$APP_BUNDLE"
  else
    printf '\nInstall command: %q --source-app %q\n' "$ROOT_DIR/script/install_macos_user_app.sh" "$APP_BUNDLE"
    printf 'Output: %s\n' "$INSTALLED_APP"
  fi
  exit 0
fi

printf 'Building DNS Pilot from source.\n'
if (( POWER_EDITION )); then
  env DNSPILOT_POWER_EDITION=1 "$ROOT_DIR/script/build_and_run.sh" "${build_args[@]}"
else
  "$ROOT_DIR/script/build_and_run.sh" "${build_args[@]}"
fi

if (( NO_INSTALL )); then
  READY_APP="$APP_BUNDLE"
else
  "$ROOT_DIR/script/install_macos_user_app.sh" --source-app "$APP_BUNDLE"
  READY_APP="$INSTALLED_APP"
  if [[ "$APP_BUNDLE" != "$ROOT_DIR/dist/DNSPilot.app" || ! -d "$APP_BUNDLE" || -L "$APP_BUNDLE" ]]; then
    fail "refusing unsafe generated-bundle cleanup: $APP_BUNDLE"
  fi
  if [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true)" != "com.dnspilot.mac" ]]; then
    fail "refusing to remove a generated bundle with an unexpected identity"
  fi
  rm -rf -- "$APP_BUNDLE"
fi

if (( ! NO_OPEN )); then
  /usr/bin/open "$READY_APP"
  expected_executable="$READY_APP/Contents/MacOS/DNSPilotMac"
  launched=0
  for _ in {1..80}; do
    while IFS= read -r pid; do
      [[ -n "$pid" ]] || continue
      command_path="$(/bin/ps -p "$pid" -o command= 2>/dev/null || true)"
      if [[ "$command_path" == "$expected_executable" ]]; then
        launched=1
        break 2
      fi
    done < <(/usr/bin/pgrep -x DNSPilotMac 2>/dev/null || true)
    sleep 0.25
  done
  (( launched == 1 )) || fail "installed DNS Pilot did not launch from $READY_APP"
fi

printf '\nDNS Pilot is ready: %s\n' "$READY_APP"
if (( NO_OPEN )); then
  printf 'Open it with: open %q\n' "$READY_APP"
else
  printf 'The app has opened. Reopen it later with: open %q\n' "$READY_APP"
fi
if (( ! NO_INSTALL )); then
  if (( POWER_EDITION )); then
    printf 'To update later: git pull --ff-only && ./script/build_from_source.sh --power\n'
  else
    printf 'To update later: git pull --ff-only && ./script/build_from_source.sh\n'
  fi
fi
