#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT_DIR/script/install_macos_user_app.sh"
TEST_ROOT="$(mktemp -d /tmp/dnspilot-install-test.XXXXXX)"
APPLICATIONS_DIR="$TEST_ROOT/Applications"
SOURCE_APP="$TEST_ROOT/Source.app"

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

cleanup() {
  case "$TEST_ROOT" in
    /tmp/dnspilot-install-test.*) rm -rf -- "$TEST_ROOT" ;;
  esac
}
trap cleanup EXIT

make_fixture_app() {
  local app_bundle="$1"
  local bundle_identifier="$2"
  local marker="$3"
  mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Library/Helpers"
  printf '#!/bin/sh\nprintf %s\\n\n' "$marker" > "$app_bundle/Contents/MacOS/DNSPilotMac"
  printf '#!/bin/sh\nprintf helper\\n\n' > "$app_bundle/Contents/Library/Helpers/dnspilot-cli"
  chmod +x "$app_bundle/Contents/MacOS/DNSPilotMac" "$app_bundle/Contents/Library/Helpers/dnspilot-cli"
  /usr/bin/plutil -create xml1 "$app_bundle/Contents/Info.plist"
  /usr/bin/plutil -insert CFBundleIdentifier -string "$bundle_identifier" "$app_bundle/Contents/Info.plist"
  /usr/bin/codesign --force --sign - "$app_bundle/Contents/MacOS/DNSPilotMac" >/dev/null
  /usr/bin/codesign --force --sign - "$app_bundle/Contents/Library/Helpers/dnspilot-cli" >/dev/null
  /usr/bin/codesign --force --sign - "$app_bundle" >/dev/null
}

run_installer() {
  env \
    DNSPILOT_INSTALL_TEST_MODE=1 \
    DNSPILOT_INSTALL_TEST_APPLICATIONS_DIR="$APPLICATIONS_DIR" \
    "$INSTALLER" --source-app "$1"
}

run_installer_with_post_install_failure() {
  env \
    DNSPILOT_INSTALL_TEST_MODE=1 \
    DNSPILOT_INSTALL_TEST_APPLICATIONS_DIR="$APPLICATIONS_DIR" \
    DNSPILOT_INSTALL_TEST_FORCE_POST_INSTALL_VALIDATION_FAILURE=1 \
    "$INSTALLER" --source-app "$1"
}

bash -n "$INSTALLER"
printf 'PASS shell syntax\n'

rg -q 'post-install validation override requires the isolated test applications directory' "$INSTALLER" || fail "post-install validation override is not confined to the isolated test directory"
printf 'PASS test fault isolation\n'

help_output="$("$INSTALLER" --help 2>&1)"
[[ "$help_output" == *'~/Applications/DNS Pilot.app'* ]] || fail "help does not name the per-user app"
[[ "$help_output" == *'preserved'* ]] || fail "help does not state data preservation"
printf 'PASS help contract\n'

make_fixture_app "$SOURCE_APP" com.dnspilot.mac first
run_installer "$SOURCE_APP" >/dev/null
DESTINATION_APP="$APPLICATIONS_DIR/DNS Pilot.app"
[[ -x "$DESTINATION_APP/Contents/MacOS/DNSPilotMac" ]] || fail "first install is missing"
grep -q first "$DESTINATION_APP/Contents/MacOS/DNSPilotMac" || fail "first install has wrong content"
printf 'PASS first install\n'

rm -rf -- "$SOURCE_APP"
make_fixture_app "$SOURCE_APP" com.dnspilot.mac second
run_installer "$SOURCE_APP" >/dev/null
grep -q second "$DESTINATION_APP/Contents/MacOS/DNSPilotMac" || fail "update did not replace content"
if find "$APPLICATIONS_DIR" -maxdepth 1 -name '.dnspilot-install.*' -print -quit | grep -q .; then
  fail "installer left staging content"
fi
printf 'PASS update replacement\n'

rm -rf -- "$SOURCE_APP"
make_fixture_app "$SOURCE_APP" com.dnspilot.mac third
if run_installer_with_post_install_failure "$SOURCE_APP" >/dev/null 2>&1; then
  fail "installer accepted a forced post-install validation failure"
fi
grep -q second "$DESTINATION_APP/Contents/MacOS/DNSPilotMac" || fail "installer did not restore the previous app after post-install validation failed"
if find "$APPLICATIONS_DIR" -maxdepth 1 -name '.dnspilot-install.*' -print -quit | grep -q .; then
  fail "installer left staging content after rollback"
fi
printf 'PASS post-install rollback\n'

rm -rf -- "$DESTINATION_APP"
make_fixture_app "$DESTINATION_APP" com.example.other occupied
if run_installer "$SOURCE_APP" >/dev/null 2>&1; then
  fail "installer replaced an unrelated destination"
fi
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DESTINATION_APP/Contents/Info.plist")" == com.example.other ]] || fail "unrelated destination was changed"
printf 'PASS unrelated destination protection\n'

if env DNSPILOT_INSTALL_TEST_APPLICATIONS_DIR="$APPLICATIONS_DIR" "$INSTALLER" --source-app "$SOURCE_APP" >/dev/null 2>&1; then
  fail "test path override worked without explicit test mode"
fi
printf 'PASS test override protection\n'

printf 'Per-user macOS installer tests passed.\n'
