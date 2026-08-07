#!/usr/bin/env bash
set -euo pipefail

MODE="run"
MODE_SET=0
SHOULD_OPEN=1
APP_NAME="DNSPilotMac"
PRODUCT_NAME="DNS Pilot"
APP_CATEGORY="public.app-category.utilities"
BUNDLE_ID="com.dnspilot.mac"
MIN_SYSTEM_VERSION="14.0"
APP_VERSION="${DNSPILOT_APP_VERSION:-0.1.0}"
APP_BUILD="${DNSPILOT_APP_BUILD:-1}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_PACKAGE_DIR="$ROOT_DIR/apps/macos/DNSPilotMac"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/DNSPilot.app"
LEGACY_APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_HELPERS="$APP_CONTENTS/Library/Helpers"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
CLI_NAME="dnspilot-cli"
POWER_EDITION="${DNSPILOT_POWER_EDITION:-0}"
PRIVACY_MANIFEST="$ROOT_DIR/apps/macos/DNSPilotMac/Packaging/PrivacyInfo.xcprivacy"
APP_ICON="$ROOT_DIR/apps/macos/DNSPilotMac/Assets/AppIcon.icns"

truthy() {
  case "$(printf "%s" "$1" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

usage() {
  cat >&2 <<USAGE
usage: $0 [run|--debug|--logs|--telemetry|--verify|--sandbox-verify|--validate] [--no-open]

Builds DNS Pilot into dist/DNSPilot.app.

  --no-open  Build without opening the app window; verify modes still validate.
USAGE
}

while (($#)); do
  case "$1" in
    run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify|--sandbox-verify|sandbox-verify|--validate|validate)
      if (( MODE_SET )); then
        usage
        exit 2
      fi
      MODE="$1"
      MODE_SET=1
      ;;
    --no-open)
      SHOULD_OPEN=0
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

terminate_existing_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true

  for _ in {1..40}; do
    if ! pgrep -x "$APP_NAME" >/dev/null; then
      return 0
    fi
    sleep 0.25
  done

  echo "$APP_NAME did not terminate before rebuilding." >&2
  return 1
}

terminate_existing_app

cargo build -p "$CLI_NAME" --manifest-path "$ROOT_DIR/Cargo.toml"
swift build --package-path "$SWIFT_PACKAGE_DIR"
BUILD_BINARY="$(swift build --package-path "$SWIFT_PACKAGE_DIR" --show-bin-path)/$APP_NAME"
RESOURCE_BUNDLE="$(swift build --package-path "$SWIFT_PACKAGE_DIR" --show-bin-path)/DNSPilotMac_DNSPilotMacCore.bundle"
CLI_BINARY="$ROOT_DIR/target/debug/$CLI_NAME"

rm -rf "$APP_BUNDLE" "$LEGACY_APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$APP_HELPERS"
cp "$BUILD_BINARY" "$APP_BINARY"
cp -R "$RESOURCE_BUNDLE" "$APP_RESOURCES/DNSPilotMac_DNSPilotMacCore.bundle"
cp "$CLI_BINARY" "$APP_HELPERS/$CLI_NAME"
cp "$PRIVACY_MANIFEST" "$APP_RESOURCES/PrivacyInfo.xcprivacy"
cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"
chmod +x "$APP_BINARY" "$APP_HELPERS/$CLI_NAME"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$PRODUCT_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$PRODUCT_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon.icns</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSApplicationCategoryType</key>
  <string>$APP_CATEGORY</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

if truthy "$POWER_EDITION"; then
  /usr/libexec/PlistBuddy -c "Add :DNSPilotPowerActionsEnabled bool true" "$INFO_PLIST"
fi

printf "Built app: %s\n" "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

verify_app_window() {
  WINDOW_OWNER_NAME="$PRODUCT_NAME" /usr/bin/swift -e 'import CoreGraphics
import Darwin
import Foundation

let windowOwnerName = ProcessInfo.processInfo.environment["WINDOW_OWNER_NAME"] ?? ""
let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly)
let windows = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[String: Any]] ?? []
let appWindows = windows.filter { window in
    guard (window[kCGWindowOwnerName as String] as? String) == windowOwnerName else {
        return false
    }
    guard (window[kCGWindowLayer as String] as? Int) == 0 else {
        return false
    }
    guard (window[kCGWindowIsOnscreen as String] as? Int) == 1 else {
        return false
    }
    guard let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let width = bounds["Width"] as? Double,
          let height = bounds["Height"] as? Double else {
        return false
    }
    return width >= 600 && height >= 400
}
exit(appWindows.count == 1 ? 0 : 1)'
}

verify_launch() {
  for _ in {1..80}; do
    if pgrep -x "$APP_NAME" >/dev/null && verify_app_window; then
      return 0
    fi
    sleep 0.25
  done

  echo "$APP_NAME did not expose exactly one on-screen app window." >&2
  return 1
}

validate_bundle() {
  local validation_args=("$APP_BUNDLE")
  if truthy "$POWER_EDITION"; then
    validation_args+=("--power-edition")
  fi
  "$ROOT_DIR/script/validate_macos_bundle.sh" "${validation_args[@]}"
}

case "$MODE" in
  run)
    if (( SHOULD_OPEN )); then
      open_app
    fi
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    if (( ! SHOULD_OPEN )); then
      echo "--no-open cannot be used with --logs" >&2
      exit 2
    fi
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    if (( ! SHOULD_OPEN )); then
      echo "--no-open cannot be used with --telemetry" >&2
      exit 2
    fi
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify|--sandbox-verify|sandbox-verify)
    "$ROOT_DIR/script/sign_macos_bundle.sh" "$APP_BUNDLE"
    if (( SHOULD_OPEN )); then
      open_app
      verify_launch
    fi
    validate_bundle
    ;;
  --validate|validate)
    validate_bundle
    ;;
  *)
    usage
    exit 2
    ;;
esac
