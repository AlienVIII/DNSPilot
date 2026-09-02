#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINUX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="$($SCRIPT_DIR/release-version.sh)"

die() {
  echo "error: $*" >&2
  exit 1
}

[[ -n "$VERSION" ]] || die "could not read Linux package version"

grep -Fq "version: '$VERSION'" "$LINUX_ROOT/packaging/snap/snapcraft.yaml" \
  || die "Snap version does not match Cargo version $VERSION"
grep -Fq "Version: $VERSION" "$LINUX_ROOT/packaging/deb/control.binary" \
  || die "deb version does not match Cargo version $VERSION"
grep -Fq "Version: $VERSION" "$LINUX_ROOT/packaging/rpm/dnspilot-linux.spec" \
  || die "rpm version does not match Cargo version $VERSION"
grep -Fq "<release version=\"$VERSION\"" \
  "$LINUX_ROOT/packaging/shared/io.dnspilot.DNSPilot.metainfo.xml" \
  || die "AppStream release version does not match Cargo version $VERSION"

echo "Linux release metadata version $VERSION is consistent"
