#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DNSPilotMac"
APP_BUNDLE="$ROOT_DIR/dist/DNSPilot.app"
OUTPUT_DIR=""
SKIP_BUILD=0

usage() {
  cat >&2 <<USAGE
usage: $0 [--output-dir ABSOLUTE_NEW_DIRECTORY] [--skip-build]

Builds and visually smokes the packaged macOS app in English and Vietnamese.

The command requires an interactive macOS desktop with Accessibility and Screen
Recording permission for the invoking terminal. It captures one PNG per locale
and verifies the app window plus localized Setup and Quick Test actions through
the accessibility tree. Review the captured sidebar labels visually.

Options:
  --output-dir  New absolute directory with a name beginning dnspilot-visual-.
  --skip-build  Reuse dist/DNSPilot.app instead of rebuilding it.
USAGE
}

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --output-dir)
      [[ $# -ge 2 ]] || fail "--output-dir requires an absolute new directory"
      OUTPUT_DIR="$2"
      shift
      ;;
    --skip-build)
      SKIP_BUILD=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
  shift
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "visual smoke requires an interactive macOS desktop"
fi

if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="$(mktemp -d /tmp/dnspilot-visual.XXXXXX)"
else
  [[ "$OUTPUT_DIR" = /* ]] || fail "--output-dir must be absolute"
  [[ "$(basename "$OUTPUT_DIR")" == dnspilot-visual-* ]] || fail "--output-dir must end with a dnspilot-visual-* directory name"
  [[ ! -e "$OUTPUT_DIR" ]] || fail "--output-dir must not already exist: $OUTPUT_DIR"
  mkdir "$OUTPUT_DIR"
fi

if (( ! SKIP_BUILD )); then
  "$ROOT_DIR/script/build_and_run.sh" --verify >/dev/null
elif [[ ! -d "$APP_BUNDLE" ]]; then
  fail "app bundle missing: $APP_BUNDLE; run without --skip-build"
fi

wait_for_window() {
  local expected_labels="$1"

  EXPECTED_AX_LABELS="$expected_labels" /usr/bin/swift -e 'import AppKit
import ApplicationServices
import Foundation

func attribute(_ element: AXUIElement, _ key: String) -> Any? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, key as NSString, &value) == .success ? value : nil
}

func collectStrings(from element: AXUIElement, visited: inout Set<CFHashCode>, depth: Int = 0) -> [String] {
    guard depth < 20 else { return [] }
    let identifier = CFHash(element)
    guard visited.insert(identifier).inserted else { return [] }
    var values: [String] = []
    for key in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute] {
        if let value = attribute(element, key), let string = value as? String, !string.isEmpty {
            values.append(string)
        }
    }
    let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    return values + children.flatMap { collectStrings(from: $0, visited: &visited, depth: depth + 1) }
}

guard AXIsProcessTrusted() else {
    fputs("Accessibility access is not granted to this terminal.\n", stderr)
    exit(3)
}
guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.dnspilot.mac" }) else {
    fputs("DNS Pilot is not running.\n", stderr)
    exit(4)
}
let application = AXUIElementCreateApplication(app.processIdentifier)
let windows = attribute(application, kAXWindowsAttribute) as? [AXUIElement] ?? []
guard windows.count == 1 else {
    fputs("Expected one DNS Pilot window, found \(windows.count).\n", stderr)
    exit(5)
}
// AXApplication can occur again inside the hierarchy. Traverse the direct
// window and menu roots, with cycle detection, to avoid false timeouts.
var visited: Set<CFHashCode> = []
var strings = windows.flatMap { collectStrings(from: $0, visited: &visited) }
if let menuBar = attribute(application, kAXMenuBarAttribute) {
    strings += collectStrings(from: menuBar as! AXUIElement, visited: &visited)
}
let expected = (ProcessInfo.processInfo.environment["EXPECTED_AX_LABELS"] ?? "").split(separator: "|").map(String.init)
let missing = expected.filter { label in !strings.contains(label) }
guard missing.isEmpty else {
    fputs("Missing accessibility labels: \(missing.joined(separator: ", ")).\n", stderr)
    exit(6)
}
'
}

window_id() {
  /usr/bin/swift -e 'import CoreGraphics
import Foundation

let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
let matches = windows.filter { window in
    (window[kCGWindowOwnerName as String] as? String) == "DNS Pilot" &&
    (window[kCGWindowLayer as String] as? Int) == 0 &&
    (window[kCGWindowIsOnscreen as String] as? Int) == 1
}
guard matches.count == 1, let number = matches[0][kCGWindowNumber as String] as? NSNumber else {
    fputs("Expected one on-screen DNS Pilot window, found \(matches.count).\n", stderr)
    exit(1)
}
print(number.intValue)
'
}

launch_locale() {
  local language="$1"
  local labels="$2"
  local screenshot_path="$OUTPUT_DIR/dns-pilot-$language.png"

  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  for _ in {1..40}; do
    pgrep -x "$APP_NAME" >/dev/null || break
    sleep 0.25
  done

  /usr/bin/open -n "$APP_BUNDLE" --args -dnspilot.language "$language"
  for _ in {1..80}; do
    if pgrep -x "$APP_NAME" >/dev/null && wait_for_window "$labels" >/dev/null 2>&1; then
      local identifier
      identifier="$(window_id)"
      /usr/sbin/screencapture -x -l "$identifier" "$screenshot_path"
      [[ -s "$screenshot_path" ]] || fail "screenshot is empty: $screenshot_path"
      /usr/bin/sips -g pixelWidth -g pixelHeight "$screenshot_path" | /usr/bin/grep -q 'pixelWidth: [1-9]' || fail "screenshot is invalid: $screenshot_path"
      printf 'PASS %s visual/accessibility smoke: %s\n' "$language" "$screenshot_path"
      return 0
    fi
    sleep 0.25
  done

  wait_for_window "$labels"
  fail "DNS Pilot did not reach the expected $language visual state"
}

launch_locale en 'Show Setup|Run Quick Test'
launch_locale vi 'Mở thiết lập|Kiểm tra nhanh'

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
/usr/bin/open -n "$APP_BUNDLE"

printf '\nVisual macOS smoke passed. Evidence: %s\n' "$OUTPUT_DIR"
