# Linux Native Specific Support

## Capabilities
- eframe/egui remains the v1 toolkit; GTK4/libadwaita or Qt requires a proved Linux-host
  accessibility/IME blocker and a new decision.
- Flatpak can benchmark with network permission.
- Snap network-manager interface is privileged and not auto-connect by default.
- deb/rpm can host a future NetworkManager/systemd-resolved D-Bus mechanism with polkit;
  the current command prototype is not release-safe.
- Current/system resolver validation is capability-gated, not assumed.
- Store/sandbox builds expose guided settings only.
- Native Power can expose real apply only after caller authorization, exact snapshot,
  configuration identity, rollback, validation, package, and real-host gates all pass.

## Limitations
- Tray support is not guaranteed, especially GNOME/Wayland.
- Resolver stacks vary by distro.
- Sandbox permissions vary by package format.
- Manual package verification is deferred; automated lane uses mocked platform capabilities.

## Opportunities
- Native package can expose richer power features.
- Capability detection can be a differentiator.
- Copyable debug reports can make later distro QA repeatable.
- CLI runner and plan surfaces can be reused by a future GTK/libadwaita or Qt shell.
