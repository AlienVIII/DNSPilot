# Release Checklist

## Product
- Benchmark modes are clear and scoped.
- Failure states show step, reason, elapsed time, and logs.
- Apply guidance is store-safe and does not imply silent DNS mutation.
- Protected network safeguards are visible.

## Engineering
- Rust workspace tests pass.
- macOS Swift tests pass.
- Bundle verification passes.
- No debug-only entitlements in release signing.
- App Store copy avoids unsupported claims.

## Platform
- Capability matrix reviewed per OS.
- Store policy risks documented.
- Power-edition features excluded from store builds.

## Docs
- Platform coordination files updated.
- Core CLI backlog current.
- Release notes include limitations.

