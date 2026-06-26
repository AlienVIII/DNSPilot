#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DNSPilotMac"
APP_BUNDLE="${DNSPILOT_APP_BUNDLE:-"$ROOT_DIR/dist/$APP_NAME.app"}"
OUTPUT_DIR="${DNSPILOT_OUTPUT_DIR:-"$ROOT_DIR/dist/release"}"
PACKAGE_PATH="${DNSPILOT_PACKAGE_PATH:-"$OUTPUT_DIR/$APP_NAME.pkg"}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-${DNSPILOT_CODESIGN_IDENTITY:-}}"
INSTALLER_IDENTITY="${DNSPILOT_INSTALLER_IDENTITY:-}"
POWER_EDITION="${DNSPILOT_POWER_EDITION:-0}"

usage() {
  cat >&2 <<USAGE
usage: $0

Environment:
  DNSPILOT_APP_BUNDLE          Existing .app bundle to sign/package.
                               Default: dist/DNSPilotMac.app
  DNSPILOT_OUTPUT_DIR          Release output directory.
                               Default: dist/release
  DNSPILOT_PACKAGE_PATH        Output .pkg path.
                               Default: dist/release/DNSPilotMac.pkg
  DNSPILOT_CODESIGN_IDENTITY   Required app signing identity.
                               Also accepts CODESIGN_IDENTITY.
  DNSPILOT_INSTALLER_IDENTITY  Optional installer signing identity.
                               If omitted, creates an unsigned local .pkg.
  DNSPILOT_POWER_EDITION       Set to 1 for direct-install Power edition
                               validation/package behavior.

This script does not upload to App Store Connect.
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

fail() {
  printf "FAIL %s\n" "$1" >&2
  exit 1
}

truthy() {
  case "$(printf "%s" "$1" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

if [[ -z "$CODESIGN_IDENTITY" || "$CODESIGN_IDENTITY" == "-" ]]; then
  fail "set DNSPILOT_CODESIGN_IDENTITY to a distribution signing identity"
fi

if [[ ! -d "$APP_BUNDLE" ]]; then
  fail "app bundle missing: $APP_BUNDLE; run ./script/build_and_run.sh --validate or build the bundle first"
fi

mkdir -p "$OUTPUT_DIR"

printf "Signing app bundle: %s\n" "$APP_BUNDLE"
CODESIGN_IDENTITY="$CODESIGN_IDENTITY" "$ROOT_DIR/script/sign_macos_bundle.sh" "$APP_BUNDLE"

printf "Validating distribution bundle.\n"
validation_args=("$APP_BUNDLE" "--distribution")
if truthy "$POWER_EDITION"; then
  validation_args+=("--power-edition")
fi
"$ROOT_DIR/script/validate_macos_bundle.sh" "${validation_args[@]}"

if [[ -n "$INSTALLER_IDENTITY" ]]; then
  printf "Building signed installer package: %s\n" "$PACKAGE_PATH"
  productbuild \
    --component "$APP_BUNDLE" /Applications \
    --sign "$INSTALLER_IDENTITY" \
    "$PACKAGE_PATH"
else
  printf "Building unsigned local installer package: %s\n" "$PACKAGE_PATH"
  productbuild \
    --component "$APP_BUNDLE" /Applications \
    "$PACKAGE_PATH"
fi

pkgutil --check-signature "$PACKAGE_PATH" || true

printf "Distribution package created: %s\n" "$PACKAGE_PATH"
