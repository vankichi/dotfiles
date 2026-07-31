> **Source of truth:** `claude/ja/skills/dev-loop/references/dev-cycle-state-file.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# dev-cycle state file template

The SoT for the structure of the state file (`<ticket-slug>.md` in the per-project plans dir). dev-cycle writes it out during implementation-plan derivation, and subsequent agents / resumes use it for context bootstrap.

```
# <Phase> / <Ticket ID>: <title> — implementation plan

## Context
Why this change is needed (DoD-based)

## Confirmed decisions
Enumerate the confirmed literals. Reference source on reimplementation; used by subsequent agents for context bootstrap. Put permanent design decisions here.
| Decision item | Adopted literal | Basis (DoD / docs) |

## Scope decisions (intentional limits derived from the DoD)
Scope limits the DoD explicitly states as "stub only is OK" / "implement in a follow-up ticket". Not deviations, so don't flag them in the PR description.
| Scope-limit item | DoD basis | Follow-up ticket |

## Spec deviations (flagged in the PR description, reviewer-check targets)
Only "permanent structural choices" where the implementation diverges from DoD / docs. Keep only the items you want the reviewer to check.
| # | Deviation | Remediation policy (spec update / keep / revisit later) |

## Phase 2+ migration (turned into follow-up tickets)
Provisional implementations slated for future refactor. Recorded as follow-ups, not implemented in this PR.
| Provisional implementation | Target form | Follow-up ticket / link |

## Carryover (existing issues, separate ticket)
Existing issues outside scope that this PR won't touch but are worth keeping in view.
| Existing issue | Impact scope | Handling ticket |

## Documentation updates (Tier classification)
Tier-based organization of the contradictions extracted from the docs cross-check, and how they're handled in this ticket.
| Target doc | Fix content | Tier (1/2/3/4) | Handling (same commit / same PR / separate ticket) |

## Impact scope
The impact-A/B/C classification and the "target symbol → referencing site" mapping table (output of the impact analysis in implementation-plan derivation)

## Current state (updated as you go)
Progress state. So a subsequent agent / resume can context-bootstrap with a single Read.
At the planning stage, write only "not yet performed" — don't write pre-measurement values, commit shas, PR URLs, or review round counts (preventing fabrication under the pressure to fill in the template).
- Stage X done / Y in progress (corresponding to wip commits)
- Latest commit: <hash> / test-fix attempt count: <n>/3
- Pending questions / escalation stop (<stage> / <reason>)

## Design review (api-design-review)
Result summary (detection status across the 6 perspectives / reflected / user-judged / remaining follow-up)

## Key design decisions
| Decision item | Decision | Basis |

## Implementation steps (in execution order)
### Step 1: ...
- New / edited files + content overview

## DoD-to-implementation-step mapping
| DoD item | Corresponding Step | Verification method |

## Anticipated pitfalls

## Verification steps (after implementation)

## Handoff to the next ticket (out of scope)

## References
- ticket URL / docs paths / original path of the repo conventions digest
```
