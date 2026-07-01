# Mobile Risks

## UX Risks
- Users may expect desktop DNS switching that mobile OSes do not allow.

## Technical Risks
- Binding Rust core to mobile needs packaging and lifecycle work.
- Background benchmark can violate platform expectations.
- Expo SDK upgrades can shift generated native projects; rerun Expo doctor plus
  iOS and Android smoke builds after package changes.
- Expo SDK 57 still needs a narrow `expo-modules-jsi@57.0.0` Swift patch for
  Xcode 26 until upstream ships the same compiler compatibility fix.

## Platform Risks
- Play Store VPN policy.
- iOS NetworkExtension entitlement and review.

## Contract Risks
- Core CLI process model may not map directly to mobile.

## Release Risks
- Store metadata must avoid internet speed claims.
