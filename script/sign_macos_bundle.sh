#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="${1:-"$ROOT_DIR/dist/DNSPilot.app"}"
APP_NAME="DNSPilotMac"
CLI_NAME="dnspilot-cli"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
CODESIGN_OPTIONS="${DNSPILOT_CODESIGN_OPTIONS:-}"

STORE_APP_ENTITLEMENTS="$ROOT_DIR/apps/macos/DNSPilotMac/Packaging/DNSPilotMac.entitlements"
STORE_HELPER_ENTITLEMENTS="$ROOT_DIR/apps/macos/DNSPilotMac/Packaging/DNSPilotHelper.entitlements"
POWER_APP_ENTITLEMENTS="$ROOT_DIR/apps/macos/DNSPilotMac/Packaging/DNSPilotPower.entitlements"
POWER_HELPER_ENTITLEMENTS="$ROOT_DIR/apps/macos/DNSPilotMac/Packaging/DNSPilotPowerHelper.entitlements"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
HELPER_BINARY="$APP_BUNDLE/Contents/Library/Helpers/$CLI_NAME"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"

if [[ -z "$CODESIGN_OPTIONS" && "$CODESIGN_IDENTITY" != "-" ]]; then
  CODESIGN_OPTIONS="runtime"
fi

uses_codesign_options=0
if [[ -n "$CODESIGN_OPTIONS" && "$CODESIGN_OPTIONS" != "-" && "$CODESIGN_OPTIONS" != "none" ]]; then
  uses_codesign_options=1
fi

sign_with_entitlements() {
  local entitlements="$1"
  local target="$2"

  if (( uses_codesign_options )); then
    codesign --force --sign "$CODESIGN_IDENTITY" --options "$CODESIGN_OPTIONS" --entitlements "$entitlements" "$target"
  else
    codesign --force --sign "$CODESIGN_IDENTITY" --entitlements "$entitlements" "$target"
  fi
}

if [[ ! -x "$APP_BINARY" ]]; then
  echo "main executable missing or not executable: $APP_BINARY" >&2
  exit 1
fi

if [[ ! -x "$HELPER_BINARY" ]]; then
  echo "helper executable missing or not executable: $HELPER_BINARY" >&2
  exit 1
fi

if [[ ! -f "$INFO_PLIST" ]] || ! plutil -lint "$INFO_PLIST" >/dev/null; then
  echo "Info.plist missing or invalid: $INFO_PLIST" >&2
  exit 1
fi

power_actions_enabled="$(/usr/libexec/PlistBuddy -c 'Print :DNSPilotPowerActionsEnabled' "$INFO_PLIST" 2>/dev/null || true)"
if [[ "$power_actions_enabled" == "true" ]]; then
  APP_ENTITLEMENTS="$POWER_APP_ENTITLEMENTS"
  HELPER_ENTITLEMENTS="$POWER_HELPER_ENTITLEMENTS"
  EDITION_NAME="Power direct-install"
else
  APP_ENTITLEMENTS="$STORE_APP_ENTITLEMENTS"
  HELPER_ENTITLEMENTS="$STORE_HELPER_ENTITLEMENTS"
  EDITION_NAME="Store-safe"
fi

plutil -lint "$APP_ENTITLEMENTS" "$HELPER_ENTITLEMENTS" >/dev/null

sign_with_entitlements "$HELPER_ENTITLEMENTS" "$HELPER_BINARY"
sign_with_entitlements "$APP_ENTITLEMENTS" "$APP_BUNDLE"
codesign --verify --strict "$HELPER_BINARY"
codesign --verify --strict "$APP_BUNDLE"

if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
  echo "Signed $EDITION_NAME bundle with ad-hoc identity for local verification only." >&2
else
  echo "Signed $EDITION_NAME bundle with identity: $CODESIGN_IDENTITY"
  if (( uses_codesign_options )); then
    echo "Code signing options: $CODESIGN_OPTIONS"
  fi
fi
