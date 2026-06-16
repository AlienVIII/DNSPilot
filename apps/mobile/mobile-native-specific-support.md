# Mobile Native Specific Support

## iOS/iPadOS
- SwiftUI is preferred.
- NetworkExtension DNS settings may support approved explicit profile enablement.
- No plain DNSJumper-style system DNS switching.

## Android
- Kotlin/Compose preferred if native.
- Private DNS/settings guidance is store-safe.
- VpnService is policy-sensitive and must be clearly disclosed if ever used.

## Limitations
- No menu bar equivalent.
- Background scheduling is constrained.
- Store policy risk is higher for VPN-like behavior.

