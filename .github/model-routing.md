# DNSPilot Model Routing

Last checked: 2026-07-11.

## Default

Use `GPT-5.6` with `reasoning effort: high` when the active Codex/API account exposes
it. DNSPilot work crosses OS lanes, CLI contracts, release trust, and merge state; it
benefits from deliberate planning and adversarial review.

`GPT-5.6` is currently a limited preview. If it is unavailable in the active model
selector, use `GPT-5.3-Codex` with `high` for agentic coding work.

## Effort Routing

| Work | Effort |
| --- | --- |
| Merge, contract change, signing/trust, release review, unexplained test failure | `high` |
| Scoped feature implementation, normal bug fix, OS-lane validation | `medium` |
| Mechanical documentation, status sync, targeted command execution | `low` |
| Architectural deadlock or security/release incident after evidence gathering | `xhigh` |

Do not use `xhigh` as the default. Higher reasoning effort does not authorize skipping
tests, bypassing user consent, or claiming manual release gates are complete.

Source: <https://developers.openai.com/api/docs/models>.
