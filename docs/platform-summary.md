# Platform Summary

| Platform | Store-safe path | Power path later | Notes |
|---|---|---|---|
| macOS | SwiftUI, menu bar, guided settings, NetworkExtension for approved DNS settings | helper plus system APIs | UX lead lane |
| iOS/iPadOS | SwiftUI, NetworkExtension DNS settings where approved | not applicable | no plain system DNS switch like desktop |
| Android | Kotlin/Compose or shared mobile shell, settings guidance, cautious VpnService only if disclosed | enterprise/device owner only | Play policy risk around VPN |
| Windows | WinUI 3, guided settings | service/admin path | Store should avoid UAC dependency |
| Linux Flatpak/Snap | GTK/libadwaita or Qt, benchmark-first | distro packages with NetworkManager/polkit | sandbox and tray support vary |

## Cross-platform Rule
Show exact capability per OS. Do not promise full parity.

