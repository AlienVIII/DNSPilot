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
[[ "$help_output" == *'~/Applications/DNS Pilot.app'* ]] || fail "help does not name the installed bundle"
[[ "$help_output" == *'--no-open'* ]] || fail "help does not document --no-open"
[[ "$help_output" == *'--power'* ]] || fail "help does not document --power"
[[ "$help_output" == *'--no-install'* ]] || fail "help does not document --no-install"
[[ "$help_output" == *'--dry-run'* ]] || fail "help does not document --dry-run"
printf 'PASS help contract\n'

expect_rejected "unknown option" --unsupported-option

dry_run_output="$("$BUILDER" --dry-run --no-open)"
[[ "$dry_run_output" == *'build_and_run.sh --verify --no-open'* ]] || fail "dry run does not use canonical verified builder"
[[ "$dry_run_output" == *'install_macos_user_app.sh --source-app'* ]] || fail "dry run does not use the per-user installer"
[[ "$dry_run_output" == *'Applications/DNS Pilot.app'* ]] || fail "dry run does not name the installed bundle"
[[ "$dry_run_output" == *'Swift 6'* ]] || fail "dry run does not confirm the required Swift toolchain"
rg -q 'refusing unsafe generated-bundle cleanup' "$BUILDER" || fail "source build does not guard generated-bundle cleanup"
rg -q 'installed DNS Pilot did not launch' "$BUILDER" || fail "source build does not verify the installed process"
printf 'PASS canonical build contract\n'

dev_dry_run_output="$("$BUILDER" --dry-run --no-install --no-open)"
[[ "$dev_dry_run_output" == *'dist/DNSPilot.app'* ]] || fail "no-install dry run does not preserve development output"
[[ "$dev_dry_run_output" != *'Install command:'* ]] || fail "no-install dry run still installs"
printf 'PASS development build contract\n'

power_dry_run_output="$("$BUILDER" --dry-run --power --no-open)"
[[ "$power_dry_run_output" == *'DNSPILOT_POWER_EDITION=1'* ]] || fail "Power dry run does not enable Power edition"
[[ "$power_dry_run_output" == *'Power direct-install'* ]] || fail "Power dry run does not identify the direct-install edition"
printf 'PASS Power build contract\n'

printf 'Build-from-source shell tests passed.\n'
