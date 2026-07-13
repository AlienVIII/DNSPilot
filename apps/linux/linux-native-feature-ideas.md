# Linux Native Feature Ideas

Implementation source: `linux-completion-plan.md` and `linux-implementation-plan.md`.

## Adopted For Store-Safe Completion

- No-tray Check DNS, Profiles, and History UX for GNOME/Wayland.
- Live progress, cancellation, structured recommendation, guided apply, and retest.
- Core-backed profile/suite/history storage and Default/Vietnam targets.
- System/English/Vietnamese preferences, keyboard/accessibility semantics, and redacted
  copyable diagnostics.

## Gated Native Power

- NetworkManager D-Bus first, systemd-resolved D-Bus fallback.
- Caller-bound polkit authorization, exact rollback, stale-configuration rejection,
  validation, and explicit Restore.

## Deferred

- Tray integration.
- Background benchmarking.
- Encrypted DNS apply.
- Toolkit rewrite without a proved eframe release blocker.
