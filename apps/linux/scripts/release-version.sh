#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CARGO_TOML="$SCRIPT_DIR/../DNSPilotLinux/Cargo.toml"

awk -F '"' '/^version = "/ { print $2; exit }' "$CARGO_TOML"
