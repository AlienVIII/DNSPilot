#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME_ROOT="$(cd "$APP_ROOT/../../../packages/mobile/dnspilot-mobile-runtime" && pwd)"
OUTPUT_ROOT="$APP_ROOT/modules/dnspilot-runtime/android/src/main/jniLibs"

rustup target add --toolchain 1.96.0 aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android
if ! cargo ndk --version >/dev/null 2>&1; then
  cargo +1.96.0 install cargo-ndk --version 4.1.2 --locked
fi

rm -rf "$OUTPUT_ROOT"
cargo +1.96.0 ndk \
  --target arm64-v8a \
  --target armeabi-v7a \
  --target x86 \
  --target x86_64 \
  --platform 24 \
  --output-dir "$OUTPUT_ROOT" \
  build --manifest-path "$RUNTIME_ROOT/Cargo.toml" --release
