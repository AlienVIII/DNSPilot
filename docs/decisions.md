# Decisions

## D001: Store-safe edition first
- Decision: prioritize App Store and store-safe distribution paths.
- Reasoning: broad distribution requires approved platform behavior.
- Consequence: no silent DNS mutation in store builds.

## D002: Shared core plus native shells
- Decision: Core CLI owns benchmark contracts, scoring, policies, and JSON schemas.
- Reasoning: platform UI can vary while product behavior stays consistent.
- Consequence: platform lanes must request contract changes instead of duplicating logic.

## D003: macOS as UX lead lane
- Decision: macOS drives desktop UX patterns first.
- Reasoning: current implementation is most complete there.
- Consequence: other platform lanes reuse patterns but adapt to native constraints.

## D004: Flush only for system DNS validation
- Decision: direct resolver benchmarks do not require OS cache flush.
- Reasoning: direct UDP queries bypass OS resolver cache.
- Consequence: flush guidance belongs to post-apply validation, not every speed test.

## D005: Gaming research is evidence-first
- Decision: document gaming connectivity separately before implementing.
- Reasoning: DNS latency does not directly predict game latency.
- Consequence: game-oriented features need additional measurements and platform feasibility review.

