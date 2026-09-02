#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: apps/linux/scripts/package-smoke.sh MODE

Modes: flatpak, snap, deb, rpm, all

Run this only on a disposable Linux QA host after installing the corresponding
artifact. It executes the packaged non-mutating `readiness` command and checks
that the default payload has no native helper or polkit policy. It never applies
or changes system DNS.
EOF
}

MODE="${1:-}"
case "$MODE" in
  flatpak | snap | deb | rpm | all) ;;
  *) usage >&2; exit 2 ;;
esac

require_linux() {
  [[ "$(uname -s)" == "Linux" ]] || {
    echo "error: package smoke requires a Linux host" >&2
    exit 1
  }
}

assert_no_power_payload() {
  local contents="$1"
  if grep -Eq 'dnspilot-native-helper|polkit-1/actions|org\.freedesktop\.NetworkManager|org\.freedesktop\.resolve1' <<<"$contents"; then
    echo "error: default package contains unavailable Power payload" >&2
    exit 1
  fi
}

smoke_flatpak() {
  command -v flatpak >/dev/null || { echo "NOT RUN: flatpak not installed"; return; }
  flatpak run --command=dnspilot-linux-shell io.dnspilot.DNSPilot readiness
}

smoke_snap() {
  command -v snap >/dev/null || { echo "NOT RUN: snap not installed"; return; }
  snap run dnspilot.dnspilot-linux-shell readiness
}

smoke_deb() {
  command -v dpkg-query >/dev/null || { echo "NOT RUN: dpkg-query not installed"; return; }
  dpkg-query -L dnspilot | tee /tmp/dnspilot-deb-files.txt
  assert_no_power_payload "$(cat /tmp/dnspilot-deb-files.txt)"
  dnspilot-linux-shell readiness
}

smoke_rpm() {
  command -v rpm >/dev/null || { echo "NOT RUN: rpm not installed"; return; }
  rpm -ql dnspilot | tee /tmp/dnspilot-rpm-files.txt
  assert_no_power_payload "$(cat /tmp/dnspilot-rpm-files.txt)"
  dnspilot-linux-shell readiness
}

require_linux
case "$MODE" in
  flatpak) smoke_flatpak ;;
  snap) smoke_snap ;;
  deb) smoke_deb ;;
  rpm) smoke_rpm ;;
  all)
    smoke_flatpak
    smoke_snap
    smoke_deb
    smoke_rpm
    ;;
esac
