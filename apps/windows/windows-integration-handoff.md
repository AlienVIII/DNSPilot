# Windows Integration Handoff

Last updated: 2026-07-17. This document is a request for the `main` integration
owner; it does not authorize a merge from this lane.

## Current Windows Truth

- Store-safe milestones 0-4 are automated-complete on `worktree/windows`.
- Milestone 5 automation is complete: manifest prep, release validator, QA,
  evidence template, Partner Center reviewer notes, screenshots, and public-site
  templates are committed.
- Latest Windows commits to integrate after normal branch review:
  `397770d`, `a76730a`, `109794d`, `fed4ab7`, `c3aa69c`, `a8216c0`, `5528226`.
- Current automated validation: 65 Windows core/static tests and
  `bash apps/windows/validate-windows-lane.sh` pass on macOS. The only tolerated
  WinUI failure is Windows App SDK `XamlCompiler.exe` being non-executable on
  macOS.

## Requested Root Updates

- `STATE.md`: replace the obsolete uncommitted Runtime Readiness note with the
  committed M0-M5 automation status; retain Windows-host UI/MSIX/tray/signing/
  Partner Center proof as `NOT RUN` manual gates.
- `TODO.md`: mark Windows milestones 0-4 complete and retain Milestone 5 as
  Windows-host release evidence.
- Any parity matrix: record Windows consumer contract automation as complete;
  record signed MSIX, device accessibility, tray, Settings handoff, and Store
  policy acceptance as manual/not run.

## Boundaries And Risks

- Store package remains `asInvoker`, copy/open-Settings only, with no silent DNS
  mutation, UAC, `netsh`, registry, or adapter API path.
- Power/admin DNS remains a separate future SKU.
- Core locale-neutral message IDs and `runtime-info --json` remain requests in
  `apps/windows/windows-core-cli-request.md`; Windows did not edit Core.
- Do not merge solely from this handoff. Review the commits and rerun validation
  in the integration worktree first.
