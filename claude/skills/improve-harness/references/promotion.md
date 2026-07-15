# Promotion criteria for where to apply (memory → rules → skill → agent)

> **Source of truth:** `claude/ja/skills/improve-harness/references/promotion.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

The decision criteria for improve-harness Step 4. **Consider in ascending order of change cost, and apply to the first target whose condition is met** (the promotion principle in design doc §5).
An insight with an explicit `target` takes precedence over this table and follows it.

| apply to | condition (do not promote if this suffices) | example | means of change |
|---|---|---|---|
| memory | a project-specific fact / environment quirk with no generality worth turning into a procedure. Enough if the next session knows it | "repo X has ja as SoT" / an alternative recipe for a denied command | write directly to the target project's memory (no PR) |
| rules/ | a 1-2 line norm for a cross-repo behavior principle / contract. May be referenced from any skill / agent | the SoT rule for the ready flag / an addition to a verification principle | dotfiles PR (ja only, no mirror) |
| skill | a gap in a specific skill's procedure / checklist / trigger condition. You want to fix reproducibility as a procedure | work-intake's skip idempotency / retrospect's recording-destination rule | dotfiles PR (ja SoT + en mirror) |
| agent | a rule about an agent definition's behavior / model routing / tool constraints | dev-cycle's worktree self-recovery rule | dotfiles PR (ja SoT + en mirror) |

## Rules of thumb for deciding

- **Generality**: limited to 1 project → memory. Cross-repo → rules or above
- **Form**: remembering a fact suffices → memory. A 1-2 line principle → rules. A procedure / checklist is needed → skill / agent
- **Enforcement**: "good enough to just know it" → memory / rules. "must always execute via this procedure" → skill / agent
- When in doubt, fall to the smaller side. Baking into a skill is not too late even after 2 or more insights of the same kind have accumulated

## Anti-patterns

- Baking a one-off event into a skill's permanent procedure (a source of rot)
- Writing content that memory would suffice for into rules/ and bloating every session's context
- Duplicating the same norm across multiple skills (write it in one place in rules/ and reference it)
- Rewriting a proposal on the grounds of the promotion decision (redesigning content is a human's domain)
