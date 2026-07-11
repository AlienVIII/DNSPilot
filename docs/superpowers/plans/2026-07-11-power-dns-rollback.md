# Power DNS Rollback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a successful macOS Power DNS Apply reversible for the exact active
network service without exposing the capability in Store-safe builds.

**Architecture:** The Power runner captures and parses the active network
service and its pre-apply DNS mode before requesting elevation. The elevated
Apply transaction rechecks both the active service and captured configuration
before mutation. A separate local `PowerDNSRollbackStore` persists exactly one
fresh record. Restore verifies the captured service remains active, restores
literal servers or automatic/DHCP mode, flushes cache, and clears the record
only after success.

**Tech Stack:** Swift 6, SwiftUI, Foundation `Codable`, Network `IPv4Address` /
`IPv6Address`, `networksetup`, `osascript`, XCTest.

---

### Task 1: Model and persist a bounded Power rollback record

**Files:**
- Create: `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/PowerDNSRollbackSnapshot.swift`
- Create: `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/PowerDNSRollbackSnapshotTests.swift`

- [x] **Step 1: Write failing snapshot/store tests**

```swift
func testAutomaticSnapshotIsFreshAndRestorable() {
    let snapshot = PowerDNSRollbackSnapshot(
        service: "Wi-Fi",
        mode: .automatic,
        servers: [],
        createdAt: Date(timeIntervalSince1970: 1_000)
    )
    XCTAssertTrue(snapshot.isFresh(now: Date(timeIntervalSince1970: 1_100)))
    XCTAssertTrue(snapshot.isRestorable)
}

func testStoreClearsStaleSnapshot() {
    let defaults = UserDefaults(suiteName: "PowerDNSRollbackSnapshotTests")!
    defaults.removePersistentDomain(forName: "PowerDNSRollbackSnapshotTests")
    let store = PowerDNSRollbackStore(
        userDefaults: defaults,
        maxAge: 86_400,
        now: { Date(timeIntervalSince1970: 100_000) }
    )
    store.save(PowerDNSRollbackSnapshot(
        service: "Wi-Fi", mode: .servers, servers: ["1.1.1.1"],
        createdAt: Date(timeIntervalSince1970: 1_000)
    ))
    XCTAssertNil(store.load())
}
```

- [x] **Step 2: Run the new tests and verify RED**

Run:

```bash
swift test --package-path apps/macos/DNSPilotMac --filter PowerDNSRollbackSnapshotTests
```

Expected: compilation fails because `PowerDNSRollbackSnapshot` and
`PowerDNSRollbackStore` do not exist.

- [x] **Step 3: Add the minimal domain types and local store**

Create these public types:

```swift
public enum PowerDNSRollbackMode: String, Codable, Equatable, Sendable {
    case automatic
    case servers
}

public struct PowerDNSRollbackSnapshot: Codable, Equatable, Sendable {
    public let service: String
    public let mode: PowerDNSRollbackMode
    public let servers: [String]
    public let createdAt: Date

    public var isRestorable: Bool {
        !service.isEmpty && (mode == .automatic || !servers.isEmpty)
    }

    public func isFresh(now: Date = Date(), maxAge: TimeInterval = 86_400) -> Bool {
        now.timeIntervalSince(createdAt) <= maxAge
    }
}
```

`PowerDNSRollbackStore` must mirror `GuidedApplyPlanStore` only for JSON
encoding, corruption clearing, 24-hour freshness, and one key named
`DNSPilot.lastPowerDNSRollback`. It must not reuse guided-apply state because
guided snapshots lack an exact network service and automatic-DNS mode.

- [x] **Step 4: Run snapshot/store tests and verify GREEN**

Run:

```bash
swift test --package-path apps/macos/DNSPilotMac --filter PowerDNSRollbackSnapshotTests
```

Expected: all new tests pass.

- [x] **Step 5: Commit the domain/persistence slice**

```bash
git add apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/PowerDNSRollbackSnapshot.swift \
  apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/PowerDNSRollbackSnapshotTests.swift
git commit -m "[macos] add Power DNS rollback state"
```

### Task 2: Capture rollback state before mutation and restore it safely

**Files:**
- Modify: `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/MacOSPowerDNSActionRunner.swift`
- Modify: `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/MacOSPowerDNSActionRunnerTests.swift`

- [x] **Step 1: Write failing runner tests**

Add tests with a queued recording process runner. Its first output, from the
non-admin `/bin/sh` capture command, is:

```text
DNSPILOT_ROLLBACK_V1
service_b64=V2ktRmk=
mode=servers
server=192.168.1.1
DNSPILOT_ROLLBACK_END
```

Assert that `applyDNS(servers:)` returns a snapshot for `Wi-Fi` with mode
`.servers` and `192.168.1.1`. Assert that the first invocation is `/bin/sh`
and the second is `/usr/bin/osascript`; the second invocation must contain the
captured service and expected DNS configuration check. Add a second test with
`mode=automatic` and no `server` line. Add failure tests for a missing end
marker, an invalid base64 service, a manual mode without a literal IP, and a
server hostname. Each capture failure must stop before the test runner records
an `osascript` invocation.

Add a stale-configuration test where the elevated script receives a snapshot for
`Wi-Fi` and `192.168.1.1`; assert it contains the exact expected-config guard
and the failure text `DNS configuration changed`.

Add restore-script tests that assert:

```swift
XCTAssertTrue(script.contains("networksetup -setdnsservers 'Wi-Fi' Empty"))
XCTAssertTrue(script.contains("Active network service changed"))
XCTAssertTrue(script.contains("dscacheutil -flushcache"))
```

Remove the old single-output recording helper only after every existing Power
test has migrated to an explicit queued output.

- [x] **Step 2: Run the runner test target and verify RED**

Run:

```bash
swift test --package-path apps/macos/DNSPilotMac --filter MacOSPowerDNSActionRunnerTests
```

Expected: return-type and capture-order assertions fail because Apply returns
`Void`, never runs a non-admin capture, and Restore is absent.

- [x] **Step 3: Capture and parse rollback state before elevation**

Change the public runner API to:

```swift
public func applyDNS(servers: [String]) throws -> PowerDNSRollbackSnapshot
public func restoreDNS(snapshot: PowerDNSRollbackSnapshot) throws
```

Before Apply, call the existing injected process runner with `/bin/sh -c` and a
capture script that uses `LC_ALL=C`, resolves the active service, and reads
`networksetup -getdnsservers` without elevation. It emits this structured
protocol:

```sh
export LC_ALL=C
printf '%s\n' DNSPILOT_ROLLBACK_V1
printf 'service_b64=%s\n' "$(printf '%s' "$service" | /usr/bin/base64 | /usr/bin/tr -d '\n')"
printf 'mode=%s\n' "$rollback_mode"
printf 'server=%s\n' "$server"
printf '%s\n' DNSPILOT_ROLLBACK_END
```

Map the stable C-locale `There aren't any DNS Servers set` result to
`.automatic`. For manual mode, parse every `server` in Swift with
`IPv4Address`/`IPv6Address`; reject duplicate servers, unknown keys, duplicate
markers, invalid base64, and trailing protocol data before `osascript` starts.

Change the elevated Apply script to receive the parsed snapshot. It must resolve
the active service again, fail with `Active network service changed` when it no
longer equals `snapshot.service`, read current DNS with `LC_ALL=C`, and fail
with `DNS configuration changed` when it no longer matches the snapshot. Only
then run `networksetup -setdnsservers` and flush.

For Restore, validate snapshot freshness inside the runner with injected
`now`/`maxAge` defaults so callers cannot bypass the view-model freshness check.
Resolve and compare the active service before mutation. Use
`networksetup -setdnsservers <service> Empty` for `.automatic`; otherwise use
the existing shell quoting function for each validated literal server. Flush
only after `networksetup` succeeds.

- [x] **Step 4: Run targeted runner tests and verify GREEN**

Run:

```bash
swift test --package-path apps/macos/DNSPilotMac --filter MacOSPowerDNSActionRunnerTests
```

Expected: all Power runner tests pass, including disabled, unsafe-input,
manual/automatic capture, capture-before-elevation, configuration-race guard,
and service-mismatch restore coverage.

- [x] **Step 5: Commit the privileged-boundary slice**

```bash
git add apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/MacOSPowerDNSActionRunner.swift \
  apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/MacOSPowerDNSActionRunnerTests.swift
git commit -m "[macos] capture Power DNS rollback"
```

### Task 3: Expose explicit Power-only Restore UX

**Files:**
- Modify: `apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/StoreSafeDNSActionViewModel.swift`
- Modify: `apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/StoreSafeDNSActionViewModelTests.swift`
- Modify: `apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift`

- [x] **Step 1: Write failing view-model tests**

Add a `PowerDNSRollbackViewModel` test suite that verifies:

```swift
let snapshot = PowerDNSRollbackSnapshot(
    service: "Wi-Fi", mode: .automatic, servers: [], createdAt: Date()
)
let viewModel = PowerDNSRollbackViewModel(snapshot: snapshot, now: Date())
XCTAssertEqual(viewModel.restoreButtonLabel, "Restore Previous DNS (Admin)")
XCTAssertTrue(viewModel.confirmationMessage.contains("Wi-Fi"))
XCTAssertTrue(viewModel.confirmationMessage.contains("automatic DNS"))
```

Assert `restoreButtonLabel == nil` for a stale snapshot or when Power actions
are disabled. The confirmation must state that macOS will ask for administrator
approval and that no restore happens after Cancel.

- [x] **Step 2: Run the view-model test target and verify RED**

Run:

```bash
swift test --package-path apps/macos/DNSPilotMac --filter StoreSafeDNSActionViewModelTests
```

Expected: compilation fails because `PowerDNSRollbackViewModel` does not exist.

- [x] **Step 3: Add the model and wire the SwiftUI action**

Add `PowerDNSRollbackViewModel` beside `MacOSPowerDNSActionViewModel`. Its
initializer takes `isEnabled`, an optional snapshot, `now`, and `maxAge`; it
exposes a restore label, confirmation message, and service/mode detail without
performing I/O.

In `DNSPilotMacApp.swift`, have the Power Apply control save the returned
snapshot only after successful `applyDNS`. Render a Power-only Restore button
when the store returns a fresh snapshot. On confirmation, call
`restoreDNS(snapshot:)` on the detached task used by Apply/Flush, show explicit
success/failure alerts, and clear the store only after a successful restore.
Load the store on view appearance so a successful Apply can be reversed after
window navigation or relaunch. Keep this control absent in Store-safe builds.

- [x] **Step 4: Run view-model tests and full macOS tests**

Run:

```bash
swift test --package-path apps/macos/DNSPilotMac --filter StoreSafeDNSActionViewModelTests
swift test --package-path apps/macos/DNSPilotMac
```

Expected: targeted tests and the full macOS suite pass.

- [x] **Step 5: Commit the Power-only UX slice**

```bash
git add apps/macos/DNSPilotMac/Sources/DNSPilotMacCore/StoreSafeDNSActionViewModel.swift \
  apps/macos/DNSPilotMac/Tests/DNSPilotMacCoreTests/StoreSafeDNSActionViewModelTests.swift \
  apps/macos/DNSPilotMac/Sources/DNSPilotMac/DNSPilotMacApp.swift
git commit -m "[macos] add Power DNS restore action"
```

### Task 4: Validate the release gate and manual rollback flow

**Files:**
- Modify: `apps/macos/PUBLISHING.md`
- Modify: `apps/macos/macos-progress.md`
- Modify: `STATE.md`
- Modify: `TODO.md`

- [ ] **Step 1: Update the Power release documentation**

Replace the current Power rollback blocker with the precise required QA flow:

```markdown
1. Capture the active service and whether it uses automatic or manual DNS.
2. Apply a known-safe resolver through Power Apply.
3. Confirm the in-app Restore action names the same active service.
4. Restore it, verify the original DNS mode/servers, and confirm the rollback
   record disappears only after success.
5. Change to another active service before Restore and confirm no DNS mutation
   occurs.
```

- [ ] **Step 2: Run automated release checks**

Run:

```bash
./script/preflight_macos_release.sh --include-power
./script/ci_macos.sh
git diff --check
```

Expected: all local checks pass. These commands must not press Power Apply or
Restore and therefore do not replace manual network QA.

- [ ] **Step 3: Perform manual Power QA on a disposable network**

Run:

```bash
DNSPILOT_POWER_EDITION=1 ./script/build_and_run.sh --verify
```

Expected: Store-safe mode never shows Restore; Power mode only shows Restore
after a successful Apply; Cancel leaves DNS unchanged; a changed active service
blocks Restore; successful Restore returns to the prior manual server list or
automatic/DHCP mode.

- [ ] **Step 4: Update durable state and commit**

After the automated and manual checks succeed, update `STATE.md`, complete the
rollback item in `TODO.md`, then run:

```bash
git add apps/macos/PUBLISHING.md apps/macos/macos-progress.md STATE.md TODO.md
git commit -m "[docs] record Power rollback QA"
```

## Plan Review

- Coverage: captures manual and automatic DNS modes, binds rollback to the
  original active service, validates at the privileged boundary, persists only
  after success, confines UI to Power builds, and preserves Store-safe behavior.
- Out of scope: a privileged helper/service, restoring search domains or VPN/MDM
  configuration, and silent/background DNS mutation. These require a separate
  capability and release architecture decision.
- Main risk: `networksetup` output can vary across macOS versions. The parser
  fails closed before returning a rollback snapshot, and manual QA must cover a
  service with automatic DNS and one with literal servers.
