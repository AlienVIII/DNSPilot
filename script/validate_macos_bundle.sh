#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/DNSPilotMac.app"
APP_NAME="DNSPilotMac"
CLI_NAME="dnspilot-cli"
EXPECTED_MIN_SYSTEM_VERSION="14.0"
ENTITLEMENTS_TEMPLATE="$ROOT_DIR/apps/macos/DNSPilotMac/Packaging/DNSPilotMac.entitlements"
HELPER_ENTITLEMENTS_TEMPLATE="$ROOT_DIR/apps/macos/DNSPilotMac/Packaging/DNSPilotHelper.entitlements"
DISTRIBUTION=0

usage() {
  cat >&2 <<USAGE
usage: $0 [APP_BUNDLE] [--distribution]

  --distribution  Treat debug-only signing warnings as release-blocking failures.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --distribution)
      DISTRIBUTION=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      usage
      exit 2
      ;;
    *)
      APP_BUNDLE="$arg"
      ;;
  esac
done

INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
HELPER_BINARY="$APP_BUNDLE/Contents/Library/Helpers/$CLI_NAME"
LEGACY_HELPER="$APP_BUNDLE/Contents/Resources/$CLI_NAME"

failures=0

pass() {
  printf "PASS %s\n" "$1"
}

fail() {
  printf "FAIL %s\n" "$1" >&2
  failures=$((failures + 1))
}

warn() {
  printf "WARN %s\n" "$1" >&2
}

warn_or_fail_distribution() {
  if (( DISTRIBUTION )); then
    fail "$1"
  else
    warn "$1"
  fi
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || true
}

plist_bool_is_true() {
  [[ "$(plist_value "$1" "$2")" == "true" ]]
}

if [[ -d "$APP_BUNDLE" ]]; then
  pass "app bundle exists: $APP_BUNDLE"
else
  fail "app bundle missing: $APP_BUNDLE"
fi

if [[ -f "$INFO_PLIST" ]] && plutil -lint "$INFO_PLIST" >/dev/null; then
  pass "Info.plist is valid"
else
  fail "Info.plist is missing or invalid"
fi

minimum_system_version="$(plist_value "$INFO_PLIST" "LSMinimumSystemVersion")"
if [[ "$minimum_system_version" == "$EXPECTED_MIN_SYSTEM_VERSION" ]]; then
  pass "LSMinimumSystemVersion is $EXPECTED_MIN_SYSTEM_VERSION"
else
  fail "LSMinimumSystemVersion expected $EXPECTED_MIN_SYSTEM_VERSION, got ${minimum_system_version:-missing}"
fi

bundle_executable="$(plist_value "$INFO_PLIST" "CFBundleExecutable")"
if [[ "$bundle_executable" == "$APP_NAME" ]]; then
  pass "CFBundleExecutable is $APP_NAME"
else
  fail "CFBundleExecutable expected $APP_NAME, got ${bundle_executable:-missing}"
fi

if [[ -x "$APP_BINARY" ]]; then
  pass "main executable exists"
else
  fail "main executable missing or not executable"
fi

if [[ -x "$HELPER_BINARY" ]]; then
  pass "CLI helper exists in Contents/Library/Helpers"
else
  fail "CLI helper missing or not executable in Contents/Library/Helpers"
fi

if [[ ! -e "$LEGACY_HELPER" ]]; then
  pass "legacy Resources CLI helper is absent"
else
  fail "legacy Resources CLI helper should not be bundled"
fi

if [[ -f "$ENTITLEMENTS_TEMPLATE" ]] && plutil -lint "$ENTITLEMENTS_TEMPLATE" >/dev/null; then
  pass "store entitlements template is valid"
else
  fail "store entitlements template is missing or invalid"
fi

if plist_bool_is_true "$ENTITLEMENTS_TEMPLATE" "com.apple.security.app-sandbox"; then
  pass "store entitlements enable App Sandbox"
else
  fail "store entitlements must enable App Sandbox"
fi

if plist_bool_is_true "$ENTITLEMENTS_TEMPLATE" "com.apple.security.network.client"; then
  pass "store entitlements allow outbound network client"
else
  fail "store entitlements must allow outbound network client"
fi

if [[ -f "$HELPER_ENTITLEMENTS_TEMPLATE" ]] && plutil -lint "$HELPER_ENTITLEMENTS_TEMPLATE" >/dev/null; then
  pass "helper entitlements template is valid"
else
  fail "helper entitlements template is missing or invalid"
fi

if plist_bool_is_true "$HELPER_ENTITLEMENTS_TEMPLATE" "com.apple.security.app-sandbox"; then
  pass "helper entitlements enable App Sandbox"
else
  fail "helper entitlements must enable App Sandbox"
fi

if plist_bool_is_true "$HELPER_ENTITLEMENTS_TEMPLATE" "com.apple.security.inherit"; then
  pass "helper entitlements inherit containing app sandbox"
else
  fail "helper entitlements must inherit containing app sandbox"
fi

if plist_bool_is_true "$HELPER_ENTITLEMENTS_TEMPLATE" "com.apple.security.network.client"; then
  fail "helper entitlements should not declare network.client when using sandbox inheritance"
else
  pass "helper entitlements avoid extra App Sandbox rights"
fi

if codesign --verify --strict "$APP_BUNDLE" >/dev/null 2>&1; then
  pass "app bundle code signature verifies"
else
  fail "app bundle code signature does not verify"
fi

if codesign --verify --strict "$HELPER_BINARY" >/dev/null 2>&1; then
  pass "CLI helper code signature verifies"
else
  fail "CLI helper code signature does not verify"
fi

app_signing_report="$(codesign -dvvv --entitlements :- "$APP_BUNDLE" 2>&1 || true)"
if grep -q "Signature=adhoc" <<<"$app_signing_report"; then
  warn_or_fail_distribution "app bundle is ad-hoc signed; expected for local debug, not distribution-ready"
elif grep -q "Authority=" <<<"$app_signing_report"; then
  pass "app bundle has a certificate-backed signature"
else
  warn_or_fail_distribution "app bundle signing state could not be classified"
fi

if grep -q "com.apple.security.app-sandbox" <<<"$app_signing_report"; then
  pass "signed app entitlements include App Sandbox"
else
  warn_or_fail_distribution "signed app entitlements do not include App Sandbox; release signing must use Packaging/DNSPilotMac.entitlements"
fi

if grep -q "com.apple.security.get-task-allow" <<<"$app_signing_report"; then
  warn_or_fail_distribution "signed app entitlements include get-task-allow; acceptable for debug only"
fi

helper_signing_report="$(codesign -dvvv --entitlements :- "$HELPER_BINARY" 2>&1 || true)"
if grep -q "Signature=adhoc" <<<"$helper_signing_report"; then
  warn_or_fail_distribution "CLI helper is ad-hoc signed; release packaging must sign helper with Packaging/DNSPilotHelper.entitlements"
elif grep -q "Authority=" <<<"$helper_signing_report"; then
  pass "CLI helper has a certificate-backed signature"
else
  warn_or_fail_distribution "CLI helper signing state could not be classified"
fi

if grep -q "com.apple.security.inherit" <<<"$helper_signing_report"; then
  pass "signed CLI helper entitlements include sandbox inheritance"
else
  warn_or_fail_distribution "signed CLI helper entitlements do not include sandbox inheritance; release signing must use Packaging/DNSPilotHelper.entitlements"
fi

if (( failures > 0 )); then
  printf "%s structural validation failure(s).\n" "$failures" >&2
  exit 1
fi

printf "macOS bundle structural validation passed.\n"
