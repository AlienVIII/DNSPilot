#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_APP="$ROOT_DIR/dist/DNSPilot.app"
APPLICATIONS_DIR="${HOME:?}/Applications"
APP_NAME="DNS Pilot.app"
BUNDLE_ID="com.dnspilot.mac"
PROCESS_NAME="DNSPilotMac"
STAGING_DIR=""

fail() {
  printf 'ERROR %s\n' "$1" >&2
  exit 1
}

usage() {
  cat >&2 <<USAGE
usage: $0 [--source-app ABSOLUTE_APP_BUNDLE]

Installs or updates DNS Pilot for the current user at:
  ~/Applications/DNS Pilot.app

The installer validates ownership and signing before replacing an existing app.
DNS Pilot profiles, suites, settings, and history are preserved.
USAGE
}

while (($#)); do
  case "$1" in
    --source-app)
      [[ $# -ge 2 ]] || fail "--source-app requires an absolute app bundle"
      SOURCE_APP="$2"
      shift
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

if [[ -n "${DNSPILOT_INSTALL_TEST_APPLICATIONS_DIR:-}" ]]; then
  [[ "${DNSPILOT_INSTALL_TEST_MODE:-}" == "1" ]] || fail "test applications override requires DNSPILOT_INSTALL_TEST_MODE=1"
  APPLICATIONS_DIR="$DNSPILOT_INSTALL_TEST_APPLICATIONS_DIR"
  [[ "$APPLICATIONS_DIR" == /tmp/dnspilot-install-test.* ]] || fail "test applications directory must use /tmp/dnspilot-install-test.*"
fi

if [[ -n "${DNSPILOT_INSTALL_TEST_FORCE_POST_INSTALL_VALIDATION_FAILURE:-}" ]]; then
  [[ "${DNSPILOT_INSTALL_TEST_MODE:-}" == "1" ]] || fail "post-install validation override requires DNSPILOT_INSTALL_TEST_MODE=1"
  [[ "${DNSPILOT_INSTALL_TEST_FORCE_POST_INSTALL_VALIDATION_FAILURE}" == "1" ]] || fail "invalid post-install validation override"
  [[ -n "${DNSPILOT_INSTALL_TEST_APPLICATIONS_DIR:-}" && "$APPLICATIONS_DIR" == /tmp/dnspilot-install-test.* ]] || fail "post-install validation override requires the isolated test applications directory"
fi

[[ "$(uname -s)" == "Darwin" ]] || fail "per-user installation requires macOS"
[[ "$SOURCE_APP" = /* ]] || fail "--source-app must be absolute"
[[ -d "$SOURCE_APP" && ! -L "$SOURCE_APP" ]] || fail "source app is missing or unsafe: $SOURCE_APP"
[[ "$APPLICATIONS_DIR" = /* ]] || fail "applications directory must be absolute"
[[ "$APPLICATIONS_DIR" != "/" && "$APPLICATIONS_DIR" != "${HOME:?}" ]] || fail "applications directory is unsafe"

bundle_identifier() {
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$1/Contents/Info.plist" 2>/dev/null || true
}

is_owned_app() {
  local app_bundle="$1"

  [[ -d "$app_bundle" && ! -L "$app_bundle" ]] || return 1
  [[ "$(bundle_identifier "$app_bundle")" == "$BUNDLE_ID" ]] || return 1
  [[ -x "$app_bundle/Contents/MacOS/$PROCESS_NAME" ]] || return 1
  [[ -x "$app_bundle/Contents/Library/Helpers/dnspilot-cli" ]] || return 1
  /usr/bin/codesign --verify --strict "$app_bundle" >/dev/null 2>&1
}

validate_owned_app() {
  local app_bundle="$1"
  local label="$2"

  is_owned_app "$app_bundle" || fail "$label is missing, unsafe, or does not belong to DNS Pilot: $app_bundle"
}

cleanup() {
  if [[ -n "$STAGING_DIR" && -d "$STAGING_DIR" ]]; then
    case "$STAGING_DIR" in
      "$APPLICATIONS_DIR"/.dnspilot-install.*)
        rm -rf -- "$STAGING_DIR"
        ;;
      *)
        printf 'WARN refusing unsafe staging cleanup: %s\n' "$STAGING_DIR" >&2
        ;;
    esac
  fi
}
trap cleanup EXIT

validate_owned_app "$SOURCE_APP" "source app"

if [[ -e "$APPLICATIONS_DIR" ]]; then
  [[ -d "$APPLICATIONS_DIR" && ! -L "$APPLICATIONS_DIR" ]] || fail "applications path is not a safe directory: $APPLICATIONS_DIR"
else
  /bin/mkdir -p "$APPLICATIONS_DIR"
fi

DESTINATION_APP="$APPLICATIONS_DIR/$APP_NAME"
if [[ -e "$DESTINATION_APP" || -L "$DESTINATION_APP" ]]; then
  validate_owned_app "$DESTINATION_APP" "existing destination"
fi

/usr/bin/pkill -x "$PROCESS_NAME" >/dev/null 2>&1 || true
for _ in {1..40}; do
  /usr/bin/pgrep -x "$PROCESS_NAME" >/dev/null || break
  sleep 0.25
done
/usr/bin/pgrep -x "$PROCESS_NAME" >/dev/null && fail "$PROCESS_NAME did not terminate before update"

STAGING_DIR="$(/usr/bin/mktemp -d "$APPLICATIONS_DIR/.dnspilot-install.XXXXXX")"
STAGED_APP="$STAGING_DIR/$APP_NAME"
PREVIOUS_APP="$STAGING_DIR/Previous DNS Pilot.app"

/usr/bin/ditto "$SOURCE_APP" "$STAGED_APP"
validate_owned_app "$STAGED_APP" "staged app"

if [[ -d "$DESTINATION_APP" ]]; then
  /bin/mv "$DESTINATION_APP" "$PREVIOUS_APP"
fi

if ! /bin/mv "$STAGED_APP" "$DESTINATION_APP"; then
  if [[ -d "$PREVIOUS_APP" && ! -e "$DESTINATION_APP" ]]; then
    /bin/mv "$PREVIOUS_APP" "$DESTINATION_APP"
  fi
  fail "could not install DNS Pilot"
fi

if [[ "${DNSPILOT_INSTALL_TEST_FORCE_POST_INSTALL_VALIDATION_FAILURE:-}" == "1" ]]; then
  printf '# forced post-install validation failure\n' >> "$DESTINATION_APP/Contents/MacOS/$PROCESS_NAME"
fi

if ! is_owned_app "$DESTINATION_APP"; then
  rm -rf -- "$DESTINATION_APP"
  if [[ -d "$PREVIOUS_APP" && ! -e "$DESTINATION_APP" ]]; then
    /bin/mv "$PREVIOUS_APP" "$DESTINATION_APP"
  fi
  fail "installed app validation failed; previous app restored when available"
fi
printf 'DNS Pilot installed: %s\n' "$DESTINATION_APP"
printf 'Existing profiles, suites, settings, and history were preserved.\n'
