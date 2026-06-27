# Mobile Risks

## UX Risks
- Users may expect desktop DNS switching that mobile OSes do not allow.

## Technical Risks
- Binding Rust core to mobile needs packaging and lifecycle work.
- Background benchmark can violate platform expectations.
- Expo SDK 56 currently needs a local `expo-modules-jsi@56.0.10` patch for
  Xcode 26 Swift compilation; remove it after an upstream release covers the
  same fix.

## Platform Risks
- Play Store VPN policy.
- iOS NetworkExtension entitlement and review.

## Contract Risks
- Core CLI process model may not map directly to mobile.

## Release Risks
- Store metadata must avoid internet speed claims.
