# macOS Native Specific Support

## Capabilities
- SwiftUI desktop shell.
- MenuBarExtra quick actions.
- Network Settings handoff.
- App Sandbox outbound networking.
- NetworkExtension DNS settings may support approved encrypted DNS profile flows later.

## Limitations
- Store-safe app must not silently mutate plain system DNS.
- Privileged helper is not suitable for Mac App Store v1.
- Browser Secure DNS, VPN, MDM, captive portals, and app caches can bypass system DNS validation.

## Opportunities
- AppKit interop for reliable text input and advanced window behavior.
- Native notifications after long benchmark completion.
- Better settings deep links if stable on target macOS versions.

