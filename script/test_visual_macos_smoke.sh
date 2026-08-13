#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SMOKE="$ROOT_DIR/script/visual_macos_smoke.sh"
IMAGE_CHECKER="$ROOT_DIR/script/check_macos_screenshot.swift"
TEST_DIR="$(mktemp -d /tmp/dnspilot-visual-test.XXXXXX)"

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

cleanup() {
  case "$TEST_DIR" in
    /tmp/dnspilot-visual-test.*) rm -rf -- "$TEST_DIR" ;;
  esac
}
trap cleanup EXIT

[[ -x "$SMOKE" ]] || fail "visual smoke script is missing or not executable"
[[ -f "$IMAGE_CHECKER" ]] || fail "screenshot checker is missing"

bash -n "$SMOKE"
printf 'PASS shell syntax\n'

help_output="$("$SMOKE" --help 2>&1)"
[[ "$help_output" == *'--output-dir'* ]] || fail "help does not document --output-dir"
[[ "$help_output" == *'--skip-build'* ]] || fail "help does not document --skip-build"
[[ "$help_output" == *'~/Applications/DNS Pilot.app'* ]] || fail "help does not name the installed app"
[[ "$help_output" == *'English and Vietnamese'* ]] || fail "help does not declare localized coverage"
[[ "$help_output" == *'visible, nonblank'* ]] || fail "help does not declare visible screenshot evidence"
rg -q 'build_from_source.sh.*--no-open' "$SMOKE" || fail "visual smoke does not update the installed app"
if rg -q 'build_and_run.sh.*--verify' "$SMOKE"; then
  fail "visual smoke still launches a duplicate development bundle"
fi
rg -q 'image_has_visible_pixels' "$SMOKE" || fail "visual smoke does not verify screenshot pixels"
rg -q 'kAXMenuBarRole' "$SMOKE" || fail "visual smoke can satisfy window labels from the menu bar"
if rg -q 'saving full-screen evidence' "$SMOKE"; then
  fail "visual smoke must not fall back to full-screen capture"
fi
printf 'PASS help contract\n'

/usr/bin/swift -e 'import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let color: NSColor = CommandLine.arguments[2] == "white" ? .white : .black
let image = NSImage(size: NSSize(width: 32, height: 32))
image.lockFocus()
color.setFill()
NSRect(x: 0, y: 0, width: 32, height: 32).fill()
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: output)
' "$TEST_DIR/white.png" white
/usr/bin/swift "$IMAGE_CHECKER" "$TEST_DIR/white.png" >/dev/null || fail "visible image was rejected"

/usr/bin/swift -e 'import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(size: NSSize(width: 32, height: 32))
image.lockFocus()
NSColor.black.setFill()
NSRect(x: 0, y: 0, width: 32, height: 32).fill()
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: output)
' "$TEST_DIR/black.png"
if /usr/bin/swift "$IMAGE_CHECKER" "$TEST_DIR/black.png" >/dev/null 2>&1; then
  fail "blank image was accepted"
fi
printf 'PASS screenshot pixel evidence\n'

if "$SMOKE" --unsupported-option >/dev/null 2>&1; then
  fail "unknown option was accepted"
fi
printf 'PASS option rejection\n'

printf 'Visual macOS smoke shell tests passed.\n'
