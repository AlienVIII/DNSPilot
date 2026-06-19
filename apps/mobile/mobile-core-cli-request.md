# Mobile Core CLI Requests

## Current Bridge
- Expo test shell uses `server/dev-server.mjs` to call whitelisted
  `dnspilot-cli` commands locally.
- This is sufficient for full local feature testing but not for release builds.

## Required APIs
- Mobile-friendly benchmark payloads with compact progress events.
- Apply-policy payloads for iOS/iPadOS and Android.
- Explicit unsupported/apply-via-settings dispositions.

## Required Contracts
- No background benchmark assumptions.
- No plain system DNS switch contract for consumer mobile.

## Required Logging
- User-copyable issue report with benchmark mode, stage, failure reason, and platform capability.

## Remaining Native Binding Needs
- Direct Rust binding or approved native adapter for release builds.
- Streaming benchmark progress before process exit if mobile foreground runs
  need live resolver status.
