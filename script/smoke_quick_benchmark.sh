#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMEOUT_SECONDS="${DNSPILOT_SMOKE_TIMEOUT_SECONDS:-20}"
MODE="${1:-quick}"

RESULT_JSON="$(mktemp /tmp/dnspilot-smoke-result.XXXXXX)"
PROGRESS_LOG="$(mktemp /tmp/dnspilot-smoke-progress.XXXXXX)"
PID=""
KILLER_PID=""

cleanup() {
  if [[ -n "$KILLER_PID" ]]; then
    kill "$KILLER_PID" 2>/dev/null || true
    wait "$KILLER_PID" 2>/dev/null || true
    KILLER_PID=""
  fi
  if [[ -n "$PID" ]]; then
    kill "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
    PID=""
  fi
  rm -f "$RESULT_JSON" "$PROGRESS_LOG"
}
trap cleanup EXIT

start_ms="$(perl -MTime::HiRes=time -e 'printf "%.0f", time()*1000')"

case "$MODE" in
  quick|dns-tcp)
    SMOKE_LABEL="quick benchmark"
    COMMAND=(
      cargo run -q -p dnspilot-cli -- path-compare
      --resolver cloudflare=1.1.1.1:53
      --resolver google-public-dns=8.8.8.8:53
      --domain github.com
      --attempts 1
      --dns-timeout-ms 800
      --connect-timeout-ms 800
      --max-connect-targets-per-domain 2
      --progress-jsonl
    )
    ;;
  dns-only)
    SMOKE_LABEL="DNS-only benchmark"
    COMMAND=(
      cargo run -q -p dnspilot-cli -- compare
      --resolver cloudflare=1.1.1.1:53
      --resolver google-public-dns=8.8.8.8:53
      --domain github.com
      --attempts 1
      --timeout-ms 800
      --progress-jsonl
    )
    ;;
  *)
    echo "usage: $0 [quick|dns-tcp|dns-only]" >&2
    exit 2
    ;;
esac

(
  cd "$ROOT_DIR"
  "${COMMAND[@]}"
) >"$RESULT_JSON" 2>"$PROGRESS_LOG" &
PID="$!"

(sleep "$TIMEOUT_SECONDS"; kill "$PID" 2>/dev/null) &
KILLER_PID="$!"

set +e
wait "$PID"
exit_code="$?"
set -e
PID=""

end_ms="$(perl -MTime::HiRes=time -e 'printf "%.0f", time()*1000')"
elapsed_ms=$((end_ms - start_ms))

if [[ "$exit_code" -ne 0 ]]; then
  echo "$SMOKE_LABEL smoke failed with exit code $exit_code after ${elapsed_ms}ms" >&2
  sed -n '1,80p' "$PROGRESS_LOG" >&2
  exit "$exit_code"
fi

progress_lines="$(wc -l <"$PROGRESS_LOG" | tr -d ' ')"
if [[ "$progress_lines" -lt 2 ]]; then
  echo "$SMOKE_LABEL smoke did not emit enough progress lines" >&2
  sed -n '1,80p' "$PROGRESS_LOG" >&2
  exit 1
fi

if ! grep -q '"runs"' "$RESULT_JSON"; then
  echo "$SMOKE_LABEL smoke result did not include runs JSON" >&2
  perl -0777 -pe 's/\s+/ /g' "$RESULT_JSON" >&2
  exit 1
fi

echo "$SMOKE_LABEL smoke passed in ${elapsed_ms}ms with ${progress_lines} progress lines"
sed -n '1,8p' "$PROGRESS_LOG"
