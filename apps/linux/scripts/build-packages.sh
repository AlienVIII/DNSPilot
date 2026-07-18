#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINUX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$LINUX_ROOT/../.." && pwd)"
DIST_DIR="$LINUX_ROOT/dist"
PAYLOAD_DIR="$DIST_DIR/payload"
SNAP_PAYLOAD_DIR="$LINUX_ROOT/packaging/snap-payload"
VERSION="0.1.0"

usage() {
  cat <<'EOF'
Usage: apps/linux/scripts/build-packages.sh MODE

Modes:
  stage     Build and validate one shared Linux release payload.
  flatpak   Build the local store-safe Flatpak artifact.
  snap      Build the local strict store-safe Snap artifact.
  deb       Build the native deb artifact.
  rpm       Build the native rpm artifact.
  all       Build all four package formats.

Run on a Linux build host from any working directory. Package tools and real
distro QA remain host-specific; this script never enables DNS mutation.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

require_linux_host() {
  [[ "$(uname -s)" == "Linux" ]] || die "Linux package builds require a Linux host"
}

build_release() {
  (
    cd "$REPO_ROOT"
    cargo build --locked --release -p dnspilot-cli
    cargo build --locked --release --manifest-path apps/linux/DNSPilotLinux/Cargo.toml
  )
}

stage_payload() {
  rm -rf "$PAYLOAD_DIR"
  mkdir -p "$PAYLOAD_DIR"

  install -m755 "$LINUX_ROOT/DNSPilotLinux/target/release/dnspilot-linux-gui" "$PAYLOAD_DIR/"
  install -m755 "$LINUX_ROOT/DNSPilotLinux/target/release/dnspilot-linux-shell" "$PAYLOAD_DIR/"
  install -m755 "$REPO_ROOT/target/release/dnspilot-cli" "$PAYLOAD_DIR/"
  install -m644 "$LINUX_ROOT/packaging/shared/io.dnspilot.DNSPilot.desktop" "$PAYLOAD_DIR/"
  install -m644 "$LINUX_ROOT/packaging/shared/io.dnspilot.DNSPilot.metainfo.xml" "$PAYLOAD_DIR/"
  install -m644 "$LINUX_ROOT/packaging/shared/io.dnspilot.DNSPilot.svg" "$PAYLOAD_DIR/"

  for binary in dnspilot-linux-gui dnspilot-linux-shell dnspilot-cli; do
    file -b "$PAYLOAD_DIR/$binary" | grep -q 'ELF' \
      || die "$binary is not a Linux ELF executable"
  done
}

validate_metadata() {
  require_command appstreamcli
  require_command desktop-file-validate
  appstreamcli validate "$PAYLOAD_DIR/io.dnspilot.DNSPilot.metainfo.xml"
  desktop-file-validate "$PAYLOAD_DIR/io.dnspilot.DNSPilot.desktop"
}

prepare_payload() {
  require_linux_host
  require_command cargo
  require_command file
  build_release
  stage_payload
  validate_metadata
}

build_flatpak() {
  require_command flatpak-builder
  rm -rf "$DIST_DIR/flatpak-build"
  flatpak-builder --force-clean \
    "$DIST_DIR/flatpak-build" \
    "$LINUX_ROOT/packaging/flatpak/io.dnspilot.DNSPilot.yml"
}

build_snap() {
  require_command snapcraft
  rm -rf "$SNAP_PAYLOAD_DIR"
  mkdir -p "$SNAP_PAYLOAD_DIR"
  install -m755 "$PAYLOAD_DIR/dnspilot-linux-gui" "$SNAP_PAYLOAD_DIR/"
  install -m755 "$PAYLOAD_DIR/dnspilot-linux-shell" "$SNAP_PAYLOAD_DIR/"
  install -m755 "$PAYLOAD_DIR/dnspilot-cli" "$SNAP_PAYLOAD_DIR/"
  install -m644 "$PAYLOAD_DIR/io.dnspilot.DNSPilot.desktop" "$SNAP_PAYLOAD_DIR/"
  install -m644 "$PAYLOAD_DIR/io.dnspilot.DNSPilot.metainfo.xml" "$SNAP_PAYLOAD_DIR/"
  install -m644 "$PAYLOAD_DIR/io.dnspilot.DNSPilot.svg" "$SNAP_PAYLOAD_DIR/"
  snapcraft pack "$LINUX_ROOT/packaging/snap" \
    --output "$DIST_DIR/dnspilot_${VERSION}.snap"
}

deb_architecture() {
  case "$(uname -m)" in
    x86_64) echo "amd64" ;;
    aarch64 | arm64) echo "arm64" ;;
    *) die "unsupported deb architecture: $(uname -m)" ;;
  esac
}

build_deb() {
  require_command dpkg-deb
  local architecture
  architecture="$(deb_architecture)"
  local root="$DIST_DIR/deb/root"
  local output="$DIST_DIR/deb/dnspilot_${VERSION}_${architecture}.deb"
  rm -rf "$DIST_DIR/deb"
  mkdir -p "$root/DEBIAN"

  sed "s/@ARCH@/$architecture/g" "$LINUX_ROOT/packaging/deb/control.binary" \
    > "$root/DEBIAN/control"
  install -Dm755 "$PAYLOAD_DIR/dnspilot-linux-gui" "$root/usr/bin/dnspilot-linux-gui"
  install -Dm755 "$PAYLOAD_DIR/dnspilot-linux-shell" "$root/usr/bin/dnspilot-linux-shell"
  install -Dm755 "$PAYLOAD_DIR/dnspilot-cli" "$root/usr/bin/dnspilot-cli"
  install -Dm644 "$PAYLOAD_DIR/io.dnspilot.DNSPilot.desktop" \
    "$root/usr/share/applications/io.dnspilot.DNSPilot.desktop"
  install -Dm644 "$PAYLOAD_DIR/io.dnspilot.DNSPilot.metainfo.xml" \
    "$root/usr/share/metainfo/io.dnspilot.DNSPilot.metainfo.xml"
  install -Dm644 "$PAYLOAD_DIR/io.dnspilot.DNSPilot.svg" \
    "$root/usr/share/icons/hicolor/scalable/apps/io.dnspilot.DNSPilot.svg"
  dpkg-deb --build --root-owner-group "$root" "$output"
}

build_rpm() {
  require_command rpmbuild
  local topdir="$DIST_DIR/rpmbuild"
  rm -rf "$topdir"
  mkdir -p "$topdir"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
  cp "$PAYLOAD_DIR"/* "$topdir/SOURCES/"
  cp "$LINUX_ROOT/packaging/rpm/dnspilot-linux.spec" "$topdir/SPECS/"
  rpmbuild --define "_topdir $topdir" -bb "$topdir/SPECS/dnspilot-linux.spec"
}

MODE="${1:-stage}"
if [[ "$MODE" == "--help" || "$MODE" == "-h" ]]; then
  usage
  exit 0
fi

case "$MODE" in
  stage | flatpak | snap | deb | rpm | all) ;;
  *) usage >&2; die "unknown mode: $MODE" ;;
esac

prepare_payload
case "$MODE" in
  stage) echo "Linux payload staged at $PAYLOAD_DIR" ;;
  flatpak) build_flatpak ;;
  snap) build_snap ;;
  deb) build_deb ;;
  rpm) build_rpm ;;
  all)
    build_flatpak
    build_snap
    build_deb
    build_rpm
    ;;
esac
