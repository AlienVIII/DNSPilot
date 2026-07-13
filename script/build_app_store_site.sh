#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_DIR="$ROOT_DIR/apps/macos/AppStoreConnect/site"
OUTPUT_DIR="${DNSPILOT_SITE_OUTPUT_DIR:-"$ROOT_DIR/dist/app-store-site"}"
SUPPORT_EMAIL="${DNSPILOT_SUPPORT_EMAIL:-}"
SITE_URL="${DNSPILOT_SITE_URL:-}"
DIST_DIR="$ROOT_DIR/dist"
SAFE_OUTPUT_DIR=""
STAGING_DIR=""

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

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

validate_output_directory() {
  if [[ -z "$OUTPUT_DIR" || "$OUTPUT_DIR" != /* ]]; then
    fail "DNSPILOT_SITE_OUTPUT_DIR must be an absolute generated-output path."
  fi

  if [[ "$OUTPUT_DIR" == / || "$OUTPUT_DIR" == "$HOME" || "$OUTPUT_DIR" == "$ROOT_DIR" || "$OUTPUT_DIR" == "$DIST_DIR" ]]; then
    fail "DNSPILOT_SITE_OUTPUT_DIR must not be /, HOME, the repository root, or dist."
  fi

  if [[ "$OUTPUT_DIR" == *'//'* || "$OUTPUT_DIR" == *'/./'* || "$OUTPUT_DIR" == *'/../'* || "$OUTPUT_DIR" == */. || "$OUTPUT_DIR" == */.. ]]; then
    fail "DNSPILOT_SITE_OUTPUT_DIR must not contain ambiguous path segments."
  fi

  local parent leaf
  parent="$(dirname "$OUTPUT_DIR")"
  leaf="$(basename "$OUTPUT_DIR")"
  case "$leaf" in
    app-store-site|app-store-site-*|dnspilot-app-store-site.*|dnspilot-site-*)
      ;;
    *)
      fail "DNSPILOT_SITE_OUTPUT_DIR must use a dedicated generated leaf (app-store-site or dnspilot-site-*)."
      ;;
  esac

  if [[ ! -d "$parent" ]]; then
    fail "DNSPILOT_SITE_OUTPUT_DIR parent must already exist."
  fi

  local canonical_parent
  canonical_parent="$(cd -P "$parent" && pwd)"
  SAFE_OUTPUT_DIR="$canonical_parent/$leaf"

  if [[ -L "$SAFE_OUTPUT_DIR" ]]; then
    fail "DNSPILOT_SITE_OUTPUT_DIR must not be a symlink."
  fi

  if [[ -e "$SAFE_OUTPUT_DIR" && ! -d "$SAFE_OUTPUT_DIR" ]]; then
    fail "DNSPILOT_SITE_OUTPUT_DIR must be a directory when it already exists."
  fi

  case "$SAFE_OUTPUT_DIR" in
    "$DIST_DIR"/*)
      ;;
    *)
      if [[ -d "$SAFE_OUTPUT_DIR" ]] && find "$SAFE_OUTPUT_DIR" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
        fail "DNSPILOT_SITE_OUTPUT_DIR outside dist must be empty or new."
      fi
      ;;
  esac
}

cleanup() {
  if [[ -n "$STAGING_DIR" ]]; then
    rm -rf -- "$STAGING_DIR"
  fi
}

trap cleanup EXIT

if [[ ! "$SUPPORT_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
  fail "DNSPILOT_SUPPORT_EMAIL must be a public email address."
fi

if [[ "$SITE_URL" != https://* ]] \
  || [[ "$SITE_URL" == *[[:space:]]* ]] \
  || [[ "$SITE_URL" == *'"'* ]] \
  || [[ "$SITE_URL" == *'<'* ]] \
  || [[ "$SITE_URL" == *'>'* ]] \
  || [[ "$SITE_URL" == *'|'* ]]; then
  fail "DNSPILOT_SITE_URL must be an https URL."
fi

validate_output_directory

SITE_URL="${SITE_URL%/}"
escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[&|\\]/\\&/g'
}

SUPPORT_EMAIL_ESCAPED="$(escape_sed_replacement "$SUPPORT_EMAIL")"
SITE_URL_ESCAPED="$(escape_sed_replacement "$SITE_URL")"
STAGING_DIR="$(mktemp -d "$(dirname "$SAFE_OUTPUT_DIR")/.${SAFE_OUTPUT_DIR##*/}.staging.XXXXXX")"
cp "$TEMPLATE_DIR/styles.css" "$STAGING_DIR/styles.css"

render() {
  local source="$1"
  local destination="$2"
  sed \
    -e "s|{{SUPPORT_EMAIL}}|$SUPPORT_EMAIL_ESCAPED|g" \
    -e "s|{{SITE_URL}}|$SITE_URL_ESCAPED|g" \
    "$source" >"$destination"
}

render "$TEMPLATE_DIR/index.html.template" "$STAGING_DIR/index.html"
render "$TEMPLATE_DIR/privacy.html.template" "$STAGING_DIR/privacy.html"

if rg -F '{{' "$STAGING_DIR" >/dev/null; then
  fail "Rendered site still contains template placeholders."
fi

if ! rg -F "$SUPPORT_EMAIL" "$STAGING_DIR/index.html" "$STAGING_DIR/privacy.html" >/dev/null; then
  fail "Rendered site does not contain the support contact."
fi

if [[ -e "$SAFE_OUTPUT_DIR" ]]; then
  rm -rf -- "$SAFE_OUTPUT_DIR"
fi
mv "$STAGING_DIR" "$SAFE_OUTPUT_DIR"
STAGING_DIR=""

printf 'App Store support site ready: %s\n' "$SAFE_OUTPUT_DIR"
