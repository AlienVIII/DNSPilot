#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMEOUT_SECONDS="${DNSPILOT_GOAL_SMOKE_TIMEOUT_SECONDS:-45}"
INCLUDE_NETWORK=0
INCLUDE_BUNDLES=0

usage() {
  cat >&2 <<USAGE
usage: $0 [--include-network] [--include-bundles]

Runs non-mutating smoke checks for the main macOS product goals.

Default local checks:
  - store-safe apply-plan guidance
  - Power apply-plan contract without administrator prompt
  - system-DNS validation progress/history against localhost

Options:
  --include-network  Also run live DNS-only, DNS+TCP, and game-target probes.
  --include-bundles  Also validate Store-safe and Power sandbox bundles.
USAGE
}

while (($#)); do
  case "$1" in
    --include-network)
      INCLUDE_NETWORK=1
      ;;
    --include-bundles)
      INCLUDE_BUNDLES=1
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

RESULT_JSON=""
PROGRESS_LOG=""
DB_PATH=""
TEMP_FILES=()

cleanup() {
  if ((${#TEMP_FILES[@]})); then
    rm -f "${TEMP_FILES[@]}"
  fi
}
trap cleanup EXIT

cd "$ROOT_DIR"

run_step() {
  local label="$1"
  shift
  printf "\n==> %s\n" "$label"
  "$@"
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if grep -q "$pattern" "$file"; then
    printf "PASS %s\n" "$label"
  else
    printf "FAIL %s\n" "$label" >&2
    sed -n '1,120p' "$file" >&2
    exit 1
  fi
}

run_json() {
  RESULT_JSON="$(mktemp /tmp/dnspilot-goal-result.XXXXXX)"
  TEMP_FILES+=("$RESULT_JSON")
  "$@" >"$RESULT_JSON"
}

run_json_with_progress() {
  RESULT_JSON="$(mktemp /tmp/dnspilot-goal-result.XXXXXX)"
  PROGRESS_LOG="$(mktemp /tmp/dnspilot-goal-progress.XXXXXX)"
  TEMP_FILES+=("$RESULT_JSON" "$PROGRESS_LOG")
  "$@" >"$RESULT_JSON" 2>"$PROGRESS_LOG"
}

run_timeout_json_with_progress() {
  RESULT_JSON="$(mktemp /tmp/dnspilot-goal-result.XXXXXX)"
  PROGRESS_LOG="$(mktemp /tmp/dnspilot-goal-progress.XXXXXX)"
  TEMP_FILES+=("$RESULT_JSON" "$PROGRESS_LOG")
  local pid=""
  local killer_pid=""

  "$@" >"$RESULT_JSON" 2>"$PROGRESS_LOG" &
  pid="$!"
  (sleep "$TIMEOUT_SECONDS"; kill "$pid" 2>/dev/null || true) &
  killer_pid="$!"

  set +e
  wait "$pid"
  local exit_code="$?"
  set -e
  kill "$killer_pid" 2>/dev/null || true
  wait "$killer_pid" 2>/dev/null || true

  if [[ "$exit_code" -ne 0 ]]; then
    printf "FAIL live smoke command exited %s\n" "$exit_code" >&2
    sed -n '1,120p' "$PROGRESS_LOG" >&2
    exit "$exit_code"
  fi
}

assert_progress_lines() {
  local min_lines="$1"
  local label="$2"
  local line_count
  line_count="$(wc -l <"$PROGRESS_LOG" | tr -d ' ')"
  if [[ "$line_count" -ge "$min_lines" ]]; then
    printf "PASS %s emitted %s progress line(s)\n" "$label" "$line_count"
  else
    printf "FAIL %s emitted only %s progress line(s)\n" "$label" "$line_count" >&2
    sed -n '1,120p' "$PROGRESS_LOG" >&2
    exit 1
  fi
}

run_step "Store-safe guided apply-plan contract" \
  run_json cargo run -q -p dnspilot-cli -- apply-plan macos-store \
    --profile-id cloudflare \
    --tested-resolver 1.0.0.1:53
assert_contains "$RESULT_JSON" '"platform": "macos-store"' "store apply-plan platform"
assert_contains "$RESULT_JSON" '"disposition": "guide-only"' "store apply-plan stays guide-only"
assert_contains "$RESULT_JSON" '"can_apply": false' "store apply-plan does not mutate DNS"
assert_contains "$RESULT_JSON" '"1.0.0.1"' "tested resolver is preserved first"

run_step "Power apply-plan contract without admin prompt" \
  run_json cargo run -q -p dnspilot-cli -- apply-plan macos-power \
    --profile-id cloudflare \
    --tested-resolver 1.0.0.1:53
assert_contains "$RESULT_JSON" '"platform": "macos-power"' "Power apply-plan platform"
assert_contains "$RESULT_JSON" '"disposition": "apply-with-user-approval"' "Power apply requires approval"
assert_contains "$RESULT_JSON" '"can_apply": true' "Power apply is capability-only in CLI"

run_step "System DNS validation preflight" \
  run_json cargo run -q -p dnspilot-cli -- preflight macos-store --scope system-dns-validation
assert_contains "$RESULT_JSON" '"flush_requirement": "recommended-before-test"' "System DNS validation recommends flush"

DB_PATH="$(mktemp /tmp/dnspilot-goal-smoke.XXXXXX.sqlite)"
TEMP_FILES+=("$DB_PATH")
run_step "System DNS validation progress/history" \
  run_json_with_progress cargo run -q -p dnspilot-cli -- system-benchmark \
    --domain localhost \
    --attempts 1 \
    --ip-family ipv4-only \
    --timeout-ms 500 \
    --progress-jsonl \
    --save-db "$DB_PATH" \
    --history-id system-smoke
assert_progress_lines 2 "System DNS validation"
assert_contains "$RESULT_JSON" '"scope": "system-dns-validation"' "System DNS validation scope"
assert_contains "$RESULT_JSON" '"summary"' "System DNS validation canonical summary"
assert_contains "$RESULT_JSON" '"runs"' "System DNS validation canonical runs"
assert_contains "$RESULT_JSON" '"saved_history_id": "system-smoke"' "System DNS validation saves history"

run_step "Saved history lookup" \
  run_json cargo run -q -p dnspilot-cli -- history-list --db "$DB_PATH"
assert_contains "$RESULT_JSON" '"id": "system-smoke"' "saved System DNS history is readable"

if (( INCLUDE_NETWORK )); then
  run_step "Live DNS-only benchmark smoke" ./script/smoke_quick_benchmark.sh dns-only
  run_step "Live DNS+TCP benchmark smoke" ./script/smoke_quick_benchmark.sh quick

  run_step "Live Dota 2 SEA target smoke" \
    run_timeout_json_with_progress cargo run -q -p dnspilot-cli -- path-compare \
      --resolver cloudflare=1.1.1.1:53 \
      --resolver google-public-dns=8.8.8.8:53 \
      --domain dota2.com \
      --domain steamcommunity.com \
      --domain steampowered.com \
      --domain steamcontent.com \
      --domain api.steampowered.com \
      --attempts 1 \
      --dns-timeout-ms 800 \
      --connect-timeout-ms 800 \
      --max-connect-targets-per-domain 1 \
      --progress-jsonl
  assert_progress_lines 2 "Dota 2 SEA target"
  assert_contains "$RESULT_JSON" '"measurement_scope": "dns-tcp"' "Dota 2 SEA target uses DNS+TCP path scope"
  assert_contains "$RESULT_JSON" '"runs"' "Dota 2 SEA target returns candidate runs"
fi

if (( INCLUDE_BUNDLES )); then
  run_step "Store-safe sandbox bundle validation" ./script/build_and_run.sh --sandbox-verify
  run_step "Power sandbox bundle validation without DNS mutation" \
    env DNSPILOT_POWER_EDITION=1 ./script/build_and_run.sh --sandbox-verify
  run_step "Restore Store-safe sandbox bundle" ./script/build_and_run.sh --sandbox-verify
fi

printf "\nDNS Pilot macOS goal smoke passed.\n"
