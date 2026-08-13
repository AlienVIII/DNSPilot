#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SMOKE="$ROOT_DIR/script/visual_macos_smoke.sh"

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

[[ -x "$SMOKE" ]] || fail "visual smoke script is missing or not executable"

bash -n "$SMOKE"
printf 'PASS shell syntax\n'

help_output="$("$SMOKE" --help 2>&1)"
[[ "$help_output" == *'--output-dir'* ]] || fail "help does not document --output-dir"
[[ "$help_output" == *'--skip-build'* ]] || fail "help does not document --skip-build"
[[ "$help_output" == *'English and Vietnamese'* ]] || fail "help does not declare localized coverage"
[[ "$help_output" == *'visible, nonblank'* ]] || fail "help does not declare visible screenshot evidence"
rg -q 'image_has_visible_pixels' "$SMOKE" || fail "visual smoke does not verify screenshot pixels"
if rg -q 'saving full-screen evidence' "$SMOKE"; then
  fail "visual smoke must not fall back to full-screen capture"
fi
printf 'PASS help contract\n'

if "$SMOKE" --unsupported-option >/dev/null 2>&1; then
  fail "unknown option was accepted"
fi
printf 'PASS option rejection\n'

printf 'Visual macOS smoke shell tests passed.\n'
