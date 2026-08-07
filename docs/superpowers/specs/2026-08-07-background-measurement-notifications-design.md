# Background Measurements And Local Completion Notifications

Status: Approved architecture for lane planning.
Last reviewed: 2026-08-07.

## Decision

### Problem

Health Check and DNS Benchmark can take long enough that users should not have to keep
DNSPilot visible. The result is time- and network-context-sensitive, so silently rerunning
later or after a restart can produce evidence for a network the user did not intend to test.

### Options And Trade-offs

1. Foreground-only: lowest complexity, but forces users to wait and makes long checks feel
   broken when they switch apps.
2. OS-bounded continuation plus local notification: better UX and no server, but cannot
   promise survival after force-quit or OS termination.
3. Daemon, periodic scheduler, or cloud job plus remote push: survives longer, but adds
   privilege, battery, privacy, account, infrastructure, and Store-review cost while
   weakening measurement context.

### Recommendation

Choose option 2. Continue one user-initiated, read-only measurement while DNSPilot is not
active only for as long as the OS permits. Persist local lifecycle state, never auto-retry,
and use an opt-in local completion notification. Do not add a push provider or server.

Reason: it solves the waiting problem without changing DNSPilot's local-first trust model.

Confidence: High on desktop; Medium on mobile until real-device evidence exists.

## Scope

In scope:

- `Health Check` and `DNS Benchmark` started explicitly by the user.
- One active measurement globally to avoid self-interference and storage races.
- Continue after window hide, app switch, or loss of focus when the OS allows it.
- Visible progress, cancellation, terminal result, interrupted recovery, and local
  completion notification.
- EN/VI, keyboard/touch, screen reader, reduced-distraction, and lock-screen privacy.

Out of scope:

- Periodic, scheduled, startup, login, reboot, remote-triggered, or silent checks.
- Survival after force-quit as a product promise.
- Automatic retry or resume after process death, reboot, or network change.
- Remote push, APNs/FCM/WNS registration, accounts, cloud storage, or analytics.
- Background DNS Apply/Restore, router access, privileged helpers, or network mutation.

## User Experience

1. The user starts Health Check or DNS Benchmark normally.
2. DNSPilot immediately shows one concise running state and a `Cancel` action.
3. On the first eligible run, a dismissible in-app prompt offers `Notify me when done`.
   Only that affirmative action may open the OS notification permission prompt. Never ask
   during first launch or tutorial. If dismissed, do not offer it automatically again;
   keep a Settings control available.
4. Leaving the window/app does not cancel the run when the OS grants background time.
5. If the run finishes while DNSPilot is inactive and notifications are enabled, send one
   local notification. If DNSPilot is active, update the result in-app without a system
   alert.
6. Tapping the notification opens the exact local result and removes the stale notification.
7. Cancellation sends no completion notification. A background failure may send one
   actionable notification; an interruption discovered only on next launch is shown in-app.

Short copy:

| State | Title | Body |
| --- | --- | --- |
| Health success | `Health Check complete` | `Results are ready.` |
| Benchmark success | `DNS Benchmark complete` | `Results are ready.` |
| Actionable failure | `Check stopped` | `Open DNSPilot to retry.` |

Do not include domains, resolver IPs, profile names, SSIDs, gateway details, health status,
or recommendations in notification content. The OS may expose notifications on a lock
screen, shared desktop, wearable, or mirrored device.

## Architecture

### Shared Boundary

- Core/CLI remains the measurement, recommendation, history, and progress-contract owner.
- OS shells own task lifetime, run receipts, notification permission, local notification,
  activation/deep-link routing, and foreground/background presentation.
- Reuse the existing progress `run_id`, exactly-one-terminal-event rule, cancellation, and
  no-partial-history semantics. Do not add a Core daemon or platform notification API.
- The future Health Check contract must use the same lifecycle invariants without merging
  Health Check and DNS Benchmark scores.

### Local Run Receipt

Each shell persists a small versioned receipt before starting work:

```text
schema_version, run_id, run_kind, status, started_at, updated_at, result_reference?
```

Allowed status flow:

```text
starting -> running -> completed | failed | cancelled
                    -> interrupted
```

On launch, a nonterminal receipt with no live task owner becomes `interrupted`. It is not
resumed. Completed history remains Core-owned; the receipt is coordination metadata, not a
second result store.

### Platform Adapters

| Platform | Recommended adaptation | Honest limitation |
| --- | --- | --- |
| macOS 14+ | Keep the app process active for its user-started run; use UserNotifications for local completion. No login item or helper. | Force Quit or OS termination interrupts the run. |
| Windows | Keep the desktop process active; use Windows App SDK `AppNotificationManager` and activation arguments. No WNS. | App notifications are not supported for elevated apps; Store-safe app remains non-elevated. |
| Linux | Keep the process active; use XDG Notification portal for sandboxed packages and request Background portal access only when required. | Desktop environment may suppress delivery or deny background activity; report best effort. |
| iOS/iPadOS | Use a user-initiated continued-processing capability only when the deployed OS/runtime supports it; otherwise use bounded background time and mark expiration interrupted. | Never promise deferred start or completion; physical-device proof is mandatory. |
| Android | First prove a bounded, user-initiated native foreground execution path with `START_NOT_STICKY`; use the required running disclosure and a separate opt-in completion channel. | If Play policy or a valid foreground-service type does not fit, keep the run foreground-only. No silent WorkManager retry. |

## Failure And Privacy Rules

- Permission denied: the run continues; Settings shows notifications as off and provides
  one OS Settings handoff. Do not repeatedly prompt.
- OS expiration/termination: cancel child work, close resources, preserve no partial
  history, and mark `interrupted` when the shell can observe it.
- App relaunch: never infer success from elapsed time. Only a terminal Core event plus a
  saved result can produce `completed`.
- Notification send failure: keep the result; notification delivery is not part of run
  success.
- Deep-link target missing or deleted: open History with a short `Result unavailable`
  message, never a blank screen.
- No notification payload or run receipt contains raw diagnostic logs or network identity.

## Acceptance Criteria

- Exactly one measurement owns the runner; a second start offers return-to-run or cancel,
  never concurrent network measurement.
- Foreground, background, cancellation, failure, and stale-receipt tests are deterministic.
- No partial history is saved on cancel/interruption.
- No permission prompt appears at install, first launch, or tutorial.
- Completion notification is local, opt-in, generic, deduplicated by run ID, and suppressed
  while DNSPilot is active.
- Notification activation opens the exact saved result in EN and VI and restores keyboard,
  touch, and assistive focus.
- Static release gates reject remote-push credentials/capabilities and background DNS
  mutation introduced by this feature.
- Real OS/device evidence records allowed, denied, Focus/Do Not Disturb, force-quit,
  process-expiration, lock-screen preview, and activation behavior. Unavailable checks are
  `NOT RUN`, never inferred from mocks.

## Delivery Order

1. Core/CLI: confirm existing benchmark lifecycle compatibility; add only the separate
   Health Check lifecycle contract already required by D13.
2. macOS: reference implementation and automated contract tests.
3. Windows and Linux: adapt the same product states to native OS APIs.
4. Mobile: feasibility spikes first, then implementation only on supported target versions.
5. Physical-device/provider evidence and Store review remain final manual gates.

## Official Sources

- Apple notification permission should be requested in context:
  <https://developer.apple.com/documentation/UserNotifications/asking-permission-to-use-notifications>
- Apple background strategy and bounded execution:
  <https://developer.apple.com/documentation/BackgroundTasks/choosing-background-strategies-for-your-app>
- Apple continued processing on iOS/iPadOS:
  <https://developer.apple.com/documentation/BackgroundTasks/performing-long-running-tasks-on-ios-and-ipados>
- Android notification permission:
  <https://developer.android.com/develop/ui/compose/notifications/notification-permission>
- Android background task choices:
  <https://developer.android.com/develop/background-work/background-tasks/persistent>
- Windows local app notifications:
  <https://learn.microsoft.com/en-us/windows/apps/develop/notifications/app-notifications/>
- XDG Background and Notification portals:
  <https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.Background.html>
  and
  <https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.Notification.html>
