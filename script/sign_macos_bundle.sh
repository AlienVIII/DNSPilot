#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="${1:-"$ROOT_DIR/dist/DNSPilotMac.app"}"
APP_NAME="DNSPilotMac"
CLI_NAME="dnspilot-cli"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"

APP_ENTITLEMENTS="$ROOT_DIR/apps/macos/DNSPilotMac/Packaging/DNSPilotMac.entitlements"
HELPER_ENTITLEMENTS="$ROOT_DIR/apps/macos/DNSPilotMac/Packaging/DNSPilotHelper.entitlements"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
HELPER_BINARY="$APP_BUNDLE/Contents/Library/Helpers/$CLI_NAME"

if [[ ! -x "$APP_BINARY" ]]; then
  echo "main executable missing or not executable: $APP_BINARY" >&2
  exit 1
fi

if [[ ! -x "$HELPER_BINARY" ]]; then
  echo "helper executable missing or not executable: $HELPER_BINARY" >&2
  exit 1
fi

plutil -lint "$APP_ENTITLEMENTS" "$HELPER_ENTITLEMENTS" >/dev/null

codesign --force --sign "$CODESIGN_IDENTITY" --entitlements "$HELPER_ENTITLEMENTS" "$HELPER_BINARY"
codesign --force --sign "$CODESIGN_IDENTITY" --entitlements "$APP_ENTITLEMENTS" "$APP_BUNDLE"
codesign --verify --strict "$HELPER_BINARY"
codesign --verify --strict "$APP_BUNDLE"

if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
  echo "Signed with ad-hoc identity for local sandbox verification only." >&2
else
  echo "Signed with identity: $CODESIGN_IDENTITY"
fi
