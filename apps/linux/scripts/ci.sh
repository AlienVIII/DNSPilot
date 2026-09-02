#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINUX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$LINUX_ROOT/../.." && pwd)"

cd "$REPO_ROOT"
cargo build -p dnspilot-cli
cargo fmt --manifest-path apps/linux/DNSPilotLinux/Cargo.toml --check
cargo test --manifest-path apps/linux/DNSPilotLinux/Cargo.toml
cargo clippy --manifest-path apps/linux/DNSPilotLinux/Cargo.toml -- -D warnings
cargo test -p dnspilot-cli
"$SCRIPT_DIR/validate-release-metadata.sh"
bash -n "$SCRIPT_DIR"/*.sh
git diff --check
