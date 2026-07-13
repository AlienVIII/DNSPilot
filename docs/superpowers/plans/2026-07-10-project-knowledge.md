# Project Knowledge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create compact root-level project knowledge that makes the current product state and next release gates discoverable without reading the historical progress log.

**Architecture:** `STATE.md` is the concise current-state contract. `TODO.md` is the ordered, actionable release queue. Existing `README.md`, `apps/macos/macos-progress.md`, and `apps/macos/PUBLISHING.md` remain the detailed source documents and are linked rather than duplicated.

**Tech Stack:** Markdown, Git, existing shell validation.

---

### Task 1: Add compact project state and release queue

**Files:**
- Create: `STATE.md`
- Create: `TODO.md`
- Modify: `README.md`

- [x] **Step 1: Create `STATE.md` with the current product contract**

Include these sections and facts:

```markdown
# DNSPilot State

## Product

DNSPilot finds and recommends DNS configurations for a current network, then
uses a platform-capability-specific apply flow.

## Current Delivery State

- Shared Rust core and CLI: implemented and tested.
- macOS 14+ SwiftUI shell: feature-complete for v1 core goals.
- App Store edition: guided apply/flush only; no silent DNS mutation.
- Power edition: direct-install only; explicit opt-in plus per-action macOS
  administrator approval for plain DNS Apply/Flush.

## Current Validation

- `./script/ci_macos.sh`
- `./script/preflight_macos_release.sh --include-power`

## Release Gates

- Apple signing identity and provisioning.
- Signed distribution bundle validation.
- Power Apply/Flush QA on a disposable network.
- App Store metadata, screenshots, hosted support and privacy URLs, and upload.

## Detailed Sources

- Product/runbook: `README.md`
- macOS scope and evidence: `apps/macos/macos-progress.md`
- Publishing steps: `apps/macos/PUBLISHING.md`
- Historical implementation log: `progress.md`
```

- [x] **Step 2: Create `TODO.md` with the ordered delivery queue**

Use the following order, which keeps non-mutating verification before external
account work and reserves real DNS mutation for an isolated network:

```markdown
# DNSPilot TODO

## P0: macOS Release Gates

- [ ] Acquire Apple signing identity and provisioning for `com.dnspilot.mac`.
- [ ] Package a certificate-signed Store-safe app and run distribution validation.
- [ ] Complete App Store Connect metadata, screenshots, support URL, privacy URL,
  privacy answers, and review notes.
- [ ] Perform Store-safe manual review smoke, then upload for review.

## P1: Power Edition Release Gate

- [ ] On a disposable network, enable Direct Admin Actions, apply a known-safe
  resolver, validate System DNS, restore the original DNS, and validate again.
- [ ] Package and sign Power edition separately from the App Store app.

## P2: Next Product Decision

- [ ] Decide whether Windows/Linux/mobile receive benchmark-first shells before
  any platform-specific direct-DNS adapter is implemented.

## References

- `STATE.md`
- `apps/macos/PUBLISHING.md`
```

- [x] **Step 3: Link the compact source-of-truth documents from `README.md`**

Insert this block after the opening product summary:

```markdown
## Project Knowledge

- Current state and release gates: `STATE.md`
- Ordered release queue: `TODO.md`
- Detailed macOS publish steps: `apps/macos/PUBLISHING.md`
```

- [x] **Step 4: Validate the documentation contract**

Run:

```bash
test -s STATE.md
test -s TODO.md
rg -n "STATE\.md|TODO\.md" README.md TODO.md
git diff --check
```

Expected: all commands exit `0`; README links both compact documents; no
whitespace errors.

- [x] **Step 5: Commit**

Run:

```bash
git add STATE.md TODO.md README.md docs/superpowers/plans/2026-07-10-project-knowledge.md
git commit -m "[docs] add compact project state"
```
