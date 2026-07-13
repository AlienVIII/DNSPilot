#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILDER="$ROOT_DIR/script/build_app_store_site.sh"
TEST_ROOT="$(mktemp -d /tmp/dnspilot-site-safety.XXXXXX)"

cleanup() {
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

run_build() {
  local output_dir="$1"
  DNSPILOT_SUPPORT_EMAIL=release@example.com \
    DNSPILOT_SITE_URL=https://example.com/dns-pilot \
    DNSPILOT_SITE_OUTPUT_DIR="$output_dir" \
    "$BUILDER"
}

expect_rejected() {
  local label="$1"
  local output_dir="$2"
  if run_build "$output_dir" >/dev/null 2>&1; then
    fail "$label was accepted"
  fi
  printf 'PASS %s\n' "$label"
}

NORMAL_OUTPUT="$TEST_ROOT/dnspilot-site-render"
run_build "$NORMAL_OUTPUT"
[[ -f "$NORMAL_OUTPUT/index.html" ]] || fail "normal render is missing index.html"
[[ -f "$NORMAL_OUTPUT/privacy.html" ]] || fail "normal render is missing privacy.html"
[[ -f "$NORMAL_OUTPUT/styles.css" ]] || fail "normal render is missing styles.css"
if rg -F '{{' "$NORMAL_OUTPUT" >/dev/null; then
  fail "normal render contains placeholders"
fi
printf 'PASS normal render\n'

expect_rejected "root output" /
expect_rejected "HOME output" "$HOME"
expect_rejected "repository root output" "$ROOT_DIR"
expect_rejected "dist output" "$ROOT_DIR/dist"
expect_rejected "relative output" app-store-site
expect_rejected "ambiguous output" "$TEST_ROOT/../dnspilot-site-ambiguous"
expect_rejected "non-generated leaf" "$TEST_ROOT/release-site"

NONEMPTY_OUTPUT="$TEST_ROOT/dnspilot-site-nonempty"
mkdir -p "$NONEMPTY_OUTPUT"
printf 'preserve me\n' >"$NONEMPTY_OUTPUT/keep.txt"
expect_rejected "nonempty external output" "$NONEMPTY_OUTPUT"
[[ -f "$NONEMPTY_OUTPUT/keep.txt" ]] || fail "nonempty external output was modified"
printf 'PASS nonempty external output preserved\n'

printf 'App Store site safety tests passed.\n'
