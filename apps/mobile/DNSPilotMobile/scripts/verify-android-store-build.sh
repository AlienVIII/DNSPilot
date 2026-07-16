#!/usr/bin/env bash
set -euo pipefail

export EAS_BUILD_PROFILE=production
export DNSPILOT_PRODUCTION_BUILD=1
export NODE_ENV=production
npx expo prebuild --clean --platform android --no-install
./android/gradlew --no-daemon --console=plain -p android :app:bundleRelease

manifest_path="android/app/build/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml"
test -f "$manifest_path"
node scripts/verify-android-release-manifest.mjs "$manifest_path"

artifact_path="$(find android/app/build/outputs -type f -name '*.aab' -print -quit)"
test -n "$artifact_path"
unzip -p "$artifact_path" 'base/dex/*.dex' | strings | node scripts/verify-android-release-dex.mjs
echo "Android Store AAB built at $artifact_path"
