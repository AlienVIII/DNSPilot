#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILDER="$ROOT_DIR/script/build_from_source.sh"

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

expect_rejected() {
  local label="$1"
  shift
  if "$BUILDER" "$@" >/dev/null 2>&1; then
    fail "$label was accepted"
  fi
  printf 'PASS %s\n' "$label"
}

bash -n "$BUILDER"
printf 'PASS shell syntax\n'

help_output="$("$BUILDER" --help 2>&1)"
[[ "$help_output" == *'dist/DNSPilot.app'* ]] || fail "help does not name the user-facing bundle"
[[ "$help_output" == *'--no-open'* ]] || fail "help does not document --no-open"
[[ "$help_output" == *'--dry-run'* ]] || fail "help does not document --dry-run"
printf 'PASS help contract\n'

expect_rejected "unknown option" --unsupported-option

dry_run_output="$("$BUILDER" --dry-run --no-open)"
[[ "$dry_run_output" == *'build_and_run.sh --verify --no-open'* ]] || fail "dry run does not use canonical verified builder"
[[ "$dry_run_output" == *'dist/DNSPilot.app'* ]] || fail "dry run does not name the user-facing bundle"
[[ "$dry_run_output" == *'Swift 6'* ]] || fail "dry run does not confirm the required Swift toolchain"
printf 'PASS canonical build contract\n'

printf 'Build-from-source shell tests passed.\n'
