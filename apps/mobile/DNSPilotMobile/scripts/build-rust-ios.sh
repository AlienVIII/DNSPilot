#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME_ROOT="$(cd "$APP_ROOT/../../../packages/mobile/dnspilot-mobile-runtime" && pwd)"
OUTPUT_ROOT="$APP_ROOT/modules/dnspilot-runtime/ios/native/apple"
FRAMEWORK="$OUTPUT_ROOT/DNSPilotMobileRuntime.xcframework"
MANIFEST="$RUNTIME_ROOT/Cargo.toml"
IOS_DEPLOYMENT_TARGET="16.4"

rustup target add --toolchain 1.96.0 aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
IPHONEOS_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET" \
  RUSTFLAGS="-C link-arg=-mios-version-min=$IOS_DEPLOYMENT_TARGET" \
  cargo +1.96.0 build --manifest-path "$MANIFEST" --target aarch64-apple-ios --release
IPHONEOS_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET" \
  RUSTFLAGS="-C link-arg=-mios-simulator-version-min=$IOS_DEPLOYMENT_TARGET" \
  cargo +1.96.0 build --manifest-path "$MANIFEST" --target aarch64-apple-ios-sim --release
IPHONEOS_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET" \
  RUSTFLAGS="-C link-arg=-mios-simulator-version-min=$IOS_DEPLOYMENT_TARGET" \
  cargo +1.96.0 build --manifest-path "$MANIFEST" --target x86_64-apple-ios --release

rm -rf "$FRAMEWORK"
mkdir -p "$OUTPUT_ROOT"
SIMULATOR_DIRECTORY="$OUTPUT_ROOT/.simulator"
SIMULATOR_LIBRARY="$SIMULATOR_DIRECTORY/libdnspilot_mobile_runtime.a"
rm -rf "$SIMULATOR_DIRECTORY"
mkdir -p "$SIMULATOR_DIRECTORY"
lipo -create \
  "$RUNTIME_ROOT/target/aarch64-apple-ios-sim/release/libdnspilot_mobile_runtime.a" \
  "$RUNTIME_ROOT/target/x86_64-apple-ios/release/libdnspilot_mobile_runtime.a" \
  -output "$SIMULATOR_LIBRARY"
xcodebuild -create-xcframework \
  -library "$RUNTIME_ROOT/target/aarch64-apple-ios/release/libdnspilot_mobile_runtime.a" \
  -headers "$RUNTIME_ROOT/include" \
  -library "$SIMULATOR_LIBRARY" \
  -headers "$RUNTIME_ROOT/include" \
  -output "$FRAMEWORK"
rm "$SIMULATOR_LIBRARY"
rmdir "$SIMULATOR_DIRECTORY"
