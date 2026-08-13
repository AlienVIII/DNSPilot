#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_ROOT="$ROOT_DIR/apps/macos/DNSPilotMac"

usage() {
  cat >&2 <<USAGE
usage: $0 [--source-root ABSOLUTE_DIRECTORY]

Rejects D14 source changes that would require remote-push, scheduled/background,
login-item, or background DNS-mutation capabilities. The default scans the macOS
app source. --source-root exists only for shell regression fixtures.
USAGE
}

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --source-root)
      [[ $# -ge 2 ]] || fail "--source-root requires an absolute directory"
      SOURCE_ROOT="$2"
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

[[ "$SOURCE_ROOT" = /* ]] || fail "--source-root must be absolute"
[[ -d "$SOURCE_ROOT/Sources/DNSPilotMac" ]] || fail "source root is missing Sources/DNSPilotMac"
[[ -f "$SOURCE_ROOT/Packaging/DNSPilotMac.entitlements" ]] || fail "source root is missing Packaging/DNSPilotMac.entitlements"

reject_matches() {
  local description="$1"
  local pattern="$2"
  shift 2
  local matches
  if matches="$(rg -n -e "$pattern" "$@")"; then
    printf '%s\n' "$matches" >&2
    fail "$description"
  fi
}

SOURCE_DIR="$SOURCE_ROOT/Sources/DNSPilotMac"
ENTITLEMENTS="$SOURCE_ROOT/Packaging/DNSPilotMac.entitlements"

reject_matches \
  "D14 must not add remote-push APIs" \
  'PKPushRegistry|registerForRemoteNotifications|didRegisterForRemoteNotifications|didFailToRegisterForRemoteNotifications' \
  "$SOURCE_DIR"

reject_matches \
  "D14 must not add scheduled/background task APIs" \
  'BGTaskScheduler|BackgroundTasks|NSBackgroundActivityScheduler' \
  "$SOURCE_DIR"

reject_matches \
  "D14 must not add login-item or service-management APIs" \
  'SMAppService|ServiceManagement' \
  "$SOURCE_DIR"

reject_matches \
  "Store-safe D14 must not add an APNs entitlement" \
  'aps-environment' \
  "$ENTITLEMENTS"

for lifecycle_source in \
  "$SOURCE_DIR/DNSPilotLocalNotifications.swift" \
  "$SOURCE_DIR/BackgroundMeasurementReceipt.swift"; do
  [[ ! -e "$lifecycle_source" ]] && continue
  reject_matches \
    "D14 lifecycle code must remain read-only" \
    'MacOSPowerDNSAction|networksetup|dscacheutil|scutil|authorizationdb' \
    "$lifecycle_source"
done

printf 'D14 macOS Store-safety guard passed.\n'
