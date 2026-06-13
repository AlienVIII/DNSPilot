#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="DNSPilotMac"
BUNDLE_ID="com.dnspilot.mac"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_PACKAGE_DIR="$ROOT_DIR/apps/macos/DNSPilotMac"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
CLI_NAME="dnspilot-cli"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

cargo build -p "$CLI_NAME" --manifest-path "$ROOT_DIR/Cargo.toml"
swift build --package-path "$SWIFT_PACKAGE_DIR"
BUILD_BINARY="$(swift build --package-path "$SWIFT_PACKAGE_DIR" --show-bin-path)/$APP_NAME"
CLI_BINARY="$ROOT_DIR/target/debug/$CLI_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$CLI_BINARY" "$APP_RESOURCES/$CLI_NAME"
chmod +x "$APP_BINARY" "$APP_RESOURCES/$CLI_NAME"

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
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

verify_app_window() {
  APP_NAME="$APP_NAME" /usr/bin/swift -e 'import CoreGraphics
import Darwin
import Foundation

let appName = ProcessInfo.processInfo.environment["APP_NAME"] ?? ""
let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly)
let windows = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[String: Any]] ?? []
let hasWindow = windows.contains { window in
    guard (window[kCGWindowOwnerName as String] as? String) == appName else {
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
exit(hasWindow ? 0 : 1)'
}

verify_launch() {
  for _ in {1..20}; do
    if pgrep -x "$APP_NAME" >/dev/null && verify_app_window; then
      return 0
    fi
    sleep 0.25
  done

  echo "$APP_NAME did not expose an on-screen app window." >&2
  return 1
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    verify_launch
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
