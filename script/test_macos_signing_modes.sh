#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d /tmp/dnspilot-signing-test.XXXXXX)"

cleanup() {
  case "$TEST_ROOT" in
    /tmp/dnspilot-signing-test.*) rm -rf -- "$TEST_ROOT" ;;
  esac
}
trap cleanup EXIT

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

make_fixture() {
  local app_bundle="$1"
  local power_enabled="$2"

  mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Library/Helpers"
  cp /usr/bin/true "$app_bundle/Contents/MacOS/DNSPilotMac"
  cp /usr/bin/true "$app_bundle/Contents/Library/Helpers/dnspilot-cli"

  cat >"$app_bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>DNSPilotMac</string>
  <key>CFBundleIdentifier</key>
  <string>com.dnspilot.mac</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
</dict>
</plist>
PLIST

  if [[ "$power_enabled" == "1" ]]; then
    /usr/libexec/PlistBuddy -c 'Add :DNSPilotPowerActionsEnabled bool true' "$app_bundle/Contents/Info.plist"
  fi
}

signed_entitlements() {
  codesign -d --entitlements :- "$1" 2>&1 || true
}

store_app="$TEST_ROOT/Store.app"
make_fixture "$store_app" 0
"$ROOT_DIR/script/sign_macos_bundle.sh" "$store_app" >/dev/null
store_app_entitlements="$(signed_entitlements "$store_app")"
store_helper_entitlements="$(signed_entitlements "$store_app/Contents/Library/Helpers/dnspilot-cli")"
grep -q 'com.apple.security.app-sandbox' <<<"$store_app_entitlements" || fail "Store app signature is missing App Sandbox"
grep -q 'com.apple.security.network.client' <<<"$store_app_entitlements" || fail "Store app signature is missing network client"
grep -q 'com.apple.security.network.server' <<<"$store_app_entitlements" || fail "Store app signature is missing network server"
grep -q 'com.apple.security.app-sandbox' <<<"$store_helper_entitlements" || fail "Store helper signature is missing App Sandbox"
grep -q 'com.apple.security.inherit' <<<"$store_helper_entitlements" || fail "Store helper signature is missing sandbox inheritance"
printf 'PASS Store signature uses sandbox entitlements\n'

power_app="$TEST_ROOT/Power.app"
make_fixture "$power_app" 1
"$ROOT_DIR/script/sign_macos_bundle.sh" "$power_app" >/dev/null
power_app_entitlements="$(signed_entitlements "$power_app")"
power_helper_entitlements="$(signed_entitlements "$power_app/Contents/Library/Helpers/dnspilot-cli")"
if grep -q 'com.apple.security.app-sandbox' <<<"$power_app_entitlements"; then
  fail "Power app signature must not use App Sandbox"
fi
if grep -q 'com.apple.security.app-sandbox\|com.apple.security.inherit' <<<"$power_helper_entitlements"; then
  fail "Power helper signature must not inherit App Sandbox"
fi
printf 'PASS Power signature avoids sandbox entitlements\n'

printf 'macOS signing-mode tests passed.\n'
