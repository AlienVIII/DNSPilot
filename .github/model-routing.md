# DNSPilot Model Routing

Last checked: 2026-07-13.

## Default

Use the latest GPT-5.6 role variant exposed by the active Codex environment:

- `GPT-5.6 Sol`, `high`: architecture, product review, cross-lane integration,
  contract/security/release decisions, and unexplained regressions.
- `GPT-5.6 Terra`, `high` for risky work or `medium` for bounded work: engineer
  implementation, TDD, refactors, and platform validation.
- `GPT-5.6 Luna`, `low` or `medium`: mechanical docs, status checks, and narrow
  deterministic tasks after the decision is fixed.

Fallback when a GPT-5.6 variant is unavailable: `GPT-5.5` at the same effort.

## Effort Routing

| Work | Effort |
| --- | --- |
| Merge, contract change, signing/trust, release review, unexplained test failure | `Sol high` |
| Scoped feature implementation, normal bug fix, OS-lane validation | `Terra medium` |
| Behavior-risk implementation, persistence, privileged adapter | `Terra high` |
| Mechanical documentation, status sync, targeted command execution | `Luna low` |
| Architectural deadlock or security/release incident after evidence gathering | `Sol xhigh` |

Do not use `xhigh` as the default. Higher reasoning effort does not authorize skipping
tests, bypassing user consent, or claiming manual release gates are complete.

Source: <https://developers.openai.com/api/docs/models>.
