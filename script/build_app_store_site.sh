#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_DIR="$ROOT_DIR/apps/macos/AppStoreConnect/site"
OUTPUT_DIR="${DNSPILOT_SITE_OUTPUT_DIR:-"$ROOT_DIR/dist/app-store-site"}"
SUPPORT_EMAIL="${DNSPILOT_SUPPORT_EMAIL:-}"
SITE_URL="${DNSPILOT_SITE_URL:-}"

usage() {
  cat >&2 <<USAGE
usage: DNSPILOT_SUPPORT_EMAIL=<public email> DNSPILOT_SITE_URL=<https URL> $0

Builds deploy-ready support and privacy pages into DNSPILOT_SITE_OUTPUT_DIR.
Default output: dist/app-store-site
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ ! "$SUPPORT_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
  echo "DNSPILOT_SUPPORT_EMAIL must be a public email address." >&2
  exit 1
fi

if [[ "$SITE_URL" != https://* ]] \
  || [[ "$SITE_URL" == *[[:space:]]* ]] \
  || [[ "$SITE_URL" == *'"'* ]] \
  || [[ "$SITE_URL" == *'<'* ]] \
  || [[ "$SITE_URL" == *'>'* ]] \
  || [[ "$SITE_URL" == *'|'* ]]; then
  echo "DNSPILOT_SITE_URL must be an https URL." >&2
  exit 1
fi

SITE_URL="${SITE_URL%/}"
escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[&|\\]/\\&/g'
}

SUPPORT_EMAIL_ESCAPED="$(escape_sed_replacement "$SUPPORT_EMAIL")"
SITE_URL_ESCAPED="$(escape_sed_replacement "$SITE_URL")"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
cp "$TEMPLATE_DIR/styles.css" "$OUTPUT_DIR/styles.css"

render() {
  local source="$1"
  local destination="$2"
  sed \
    -e "s|{{SUPPORT_EMAIL}}|$SUPPORT_EMAIL_ESCAPED|g" \
    -e "s|{{SITE_URL}}|$SITE_URL_ESCAPED|g" \
    "$source" >"$destination"
}

render "$TEMPLATE_DIR/index.html.template" "$OUTPUT_DIR/index.html"
render "$TEMPLATE_DIR/privacy.html.template" "$OUTPUT_DIR/privacy.html"

if rg -F '{{' "$OUTPUT_DIR" >/dev/null; then
  echo "Rendered site still contains template placeholders." >&2
  exit 1
fi

if ! rg -F "$SUPPORT_EMAIL" "$OUTPUT_DIR/index.html" "$OUTPUT_DIR/privacy.html" >/dev/null; then
  echo "Rendered site does not contain the support contact." >&2
  exit 1
fi

printf 'App Store support site ready: %s\n' "$OUTPUT_DIR"
