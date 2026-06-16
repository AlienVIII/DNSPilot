# Linux Native Specific Support

## Capabilities
- GTK4/libadwaita or Qt are candidates.
- Flatpak can benchmark with network permission.
- Snap network-manager interface is privileged and not auto-connect by default.
- deb/rpm can use NetworkManager D-Bus or systemd-resolved with polkit.

## Limitations
- Tray support is not guaranteed, especially GNOME/Wayland.
- Resolver stacks vary by distro.
- Sandbox permissions vary by package format.

## Opportunities
- Native package can expose richer power features.
- Capability detection can be a differentiator.

