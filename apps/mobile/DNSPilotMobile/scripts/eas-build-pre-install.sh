#!/usr/bin/env bash
set -euo pipefail

if ! command -v rustup >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain 1.96.0
  export PATH="$HOME/.cargo/bin:$PATH"
fi

rustup toolchain install 1.96.0 --profile minimal --no-self-update

case "${EAS_BUILD_PLATFORM:-}" in
  ios) npm run native:prepare:ios ;;
  android) npm run native:prepare:android ;;
  *) echo "EAS_BUILD_PLATFORM must be ios or android" >&2; exit 1 ;;
esac
