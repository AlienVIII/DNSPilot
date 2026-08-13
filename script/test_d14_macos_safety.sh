#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$ROOT_DIR/script/check_d14_macos_safety.sh"
CI_SCRIPT="$ROOT_DIR/script/ci_macos.sh"
PREFLIGHT_SCRIPT="$ROOT_DIR/script/preflight_macos_release.sh"
FIXTURE_DIR=""

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

cleanup() {
  [[ -z "$FIXTURE_DIR" ]] || rm -rf "$FIXTURE_DIR"
}
trap cleanup EXIT

[[ -x "$GUARD" ]] || fail "D14 safety guard is missing or not executable"

"$GUARD"
printf 'PASS current macOS D14 sources are Store-safe\n'

rg -q 'test_d14_macos_safety.sh' "$CI_SCRIPT" || fail "CI does not run the D14 safety contract"
rg -q 'test_d14_macos_safety.sh' "$PREFLIGHT_SCRIPT" || fail "release preflight does not run the D14 safety contract"
printf 'PASS CI and release preflight run the D14 safety contract\n'

FIXTURE_DIR="$(mktemp -d /tmp/dnspilot-d14-safety.XXXXXX)"
mkdir -p "$FIXTURE_DIR/Sources/DNSPilotMac" "$FIXTURE_DIR/Packaging"
printf 'PKPushRegistry\n' > "$FIXTURE_DIR/Sources/DNSPilotMac/RemotePush.swift"
printf '<plist><dict><key>aps-environment</key></dict></plist>\n' > "$FIXTURE_DIR/Packaging/DNSPilotMac.entitlements"

if "$GUARD" --source-root "$FIXTURE_DIR" >/dev/null 2>&1; then
  fail "D14 safety guard accepted a remote-push fixture"
fi
printf 'PASS remote-push fixture is rejected\n'

printf 'D14 macOS safety tests passed.\n'
