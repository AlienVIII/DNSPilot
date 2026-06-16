# macOS Risks

## UX Risks
- Users may think DNS Pilot changed DNS automatically.
- Long all-profile benchmarks may feel stuck without clear progress.

## Technical Risks
- System DNS validation can be distorted by caches and browser Secure DNS.
- Current Core CLI `system-benchmark` does not emit progress JSONL or save history, so macOS must keep this mode stateless for now.
- SwiftUI layout can regress on small windows if result tables grow.

## Platform Risks
- App Store review may reject hidden helper-like behavior.
- NetworkExtension DNS settings require careful entitlement and UX review.

## Contract Risks
- CLI JSON schema drift can break result parsing.

## Release Risks
- Debug signing differs from release entitlements.
