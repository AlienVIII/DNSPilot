# Linux Native Specific Support

## Capabilities
- GTK4/libadwaita or Qt are candidates.
- Flatpak can benchmark with network permission.
- Snap network-manager interface is privileged and not auto-connect by default.
- deb/rpm can use NetworkManager D-Bus or systemd-resolved with polkit.
- Current/system resolver validation is capability-gated, not assumed.
- Store/sandbox builds expose guided settings only.
- Native power builds expose real apply only after resolver stack plus polkit checks.

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
