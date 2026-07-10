---
name: notion-ticket-plan
description: Starting from a Notion / Linear / GitHub Issue ticket URL, explores related docs / ADRs and writes an implementation plan out to a plan file, then obtains plan-mode approval (planning only, does not implement). Use for "ticket に沿って計画して" ("plan according to this ticket"), etc.
model: claude-fable-5
---

> **Source of truth:** `claude/ja/skills/notion-ticket-plan/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# notion-ticket-plan

Starting from a ticket (Notion / Linear / GitHub Issue) URL, this skill explores the repository's docs / ADRs / existing code, and covers everything up through **writing an implementation plan out to a plan file and getting it approved**. It does not implement anything.

## Applicability

- Runs primarily in plan mode (implementation happens in a separate skill / a separate turn)
- Works best when the repository has design documents such as `docs/` or `ADR/` (but works without them too)

## Procedure

### Step 1: Fetch the ticket

Read the content from the ticket URL. Note the `Definition of Done`, the scope, and any references to related ADRs / design docs.

| ticket source | tool |
|---|---|
| Notion | `mcp__claude_ai_Notion__notion-fetch` |
| GitHub Issue / PR | `gh issue view` / `gh pr view` (Bash) |
| Linear | MCP if available, otherwise WebFetch the URL |
| other URL | WebFetch |

Perspectives to extract:
- DoD (acceptance criteria)
- In-scope / out-of-scope
- Related tickets (predecessors / successors)
- Deadline / status

### Step 1.5: Literal cross-check between the DoD and existing docs

Both the DoD and the existing docs may be stale, so **read and compare them in parallel** to extract contradictions.

1. Extract literals from the DoD (type names / method sets / placement paths / design responsibilities / naming)
2. Extract literals from the related docs (`docs/design/*.md`, ADRs)
3. **Exhaustively enumerate points of contradiction**:
   - Naming (e.g., singular `product_id` vs. list `product_ids`)
   - Method sets (e.g., 6 methods vs. 7 methods)
   - Placement paths (e.g., `domain/ports` vs. `application/ports`)
   - Design responsibility layer (e.g., is the ACL assembled in the adapter or in the application layer)
4. **Use AskUserQuestion to have the user settle on which literal to adopt**
   - It's the user's call whether the DoD or the docs is newer / more trustworthy
   - Flag doc-side corrections as a separate task if needed
5. Record the confirmed literals in the "Confirmed decisions" section of the plan file from Step 6
6. **Classify each point of contradiction into Tier 1-4** (to judge the scope of doc / implementation updates)
   - **Tier 1**: pure literal alignment (mechanical alignment of paths / file names / type names, etc.) → in scope for this ticket, fixed in the same commit as the implementation
   - **Tier 2**: following a confirmed design decision (method removal / signature update, etc.) → in scope for this ticket, fixed in the same commit as the implementation
   - **Tier 3**: requires a design decision (e.g., involves a change to the caller's responsibilities)
     - Judgment axis: "does the DoD require implementing this change?"
     - **If required by the DoD, implement it in the same PR** (ask the user for the design decision, but implementation stays in scope)
     - If out of DoD scope, make it a separate ticket, and only flag it in this ticket
   - **Tier 4**: a full rewrite of pseudocode / code examples (cosmetic but large in volume) → separate commit / separate ticket, only flag it in this ticket

**Important**: Don't treat the DoD as the rule. Don't treat the docs as the rule. **Present both in parallel and let the user decide.**

### Step 2: Explore related docs (launch up to 3 Explore subagents in parallel)

Use Explore subagents to search the following in parallel:

- Implementation plan files (e.g., `docs/plan/*.md`) for mentions around the relevant ticket
- ADRs (`docs/adr/*.md`) for related decisions
- Design docs (`docs/design/*.md`)
- README / CLAUDE.md for related information
- Existing code (around the relevant feature)
- Existing `.gitignore` / config files that affect scope

Give each Explore agent "concrete file paths + a list of questions." Have it cite responses by file:line.

### Step 3: Design with a Plan agent

Launch a Plan subagent. Pass the information gathered in the previous steps as background, and have it write an implementation plan. Elements to include in the prompt:

- The ticket's DoD (Step 1)
- Related ADR excerpts (Step 2)
- The state of existing files
- Confirmed premises
- Points you want it to consider (version selection, naming, relaxation rules, etc.)
- Out-of-scope items (to hand off to a later ticket)

For complex tasks, run up to 3 in parallel taking different perspectives (conciseness vs. extensibility vs. maintainability).

### Step 4: Directly read the key files

Based on the Plan agent's response, directly check the files to be modified / related config files with Read. Verify that the plan's premises match the current state.

### Step 5: Hash out open points with AskUserQuestion if needed

If there are undecided points (a version value, a library choice, tone), narrow them to 1-2 questions via AskUserQuestion. Never use AskUserQuestion for "plan approval" itself (that's ExitPlanMode's job).

### Step 5.5: 6-perspective review with the api-design-review skill

**Before** writing out the plan, invoke the `api-design-review` skill to catch gaps across the following 6 perspectives:

1. Separation of client abstraction vs. server-side expansion
2. Both the read and write sides of the ACL
3. Forward-compatibility (can enums / fields / RPCs be added non-breakingly)
4. Enumeration of edge cases ("what happens in this situation?")
5. Consistency with the existing source of truth (grep-first)
6. Compliance with memory conventions

If gaps are detected, get the user's judgment via AskUserQuestion, reflect it in the plan, then proceed to Step 6. This suppresses the "noticing it later" that comes from a reviewer's perspective. Record the skill's result in the plan file as a "## Design review (api-design-review)" section.

Judgment axis for when the skill invocation is unnecessary: simple additions / internal refactors with no impact on existing contracts / bug fixes / minor changes. It's **mandatory** for tickets involving a new service / new RPC / new enum / new ACL model / new ADR / a change to a design responsibility layer.

### Step 6: Write out the plan file

- Write the final plan into the plan file path presented by plan mode
- **Treat the per-project plans dir's `<ticket-slug>.md` (`~/.claude/projects/<encoded>/plans/<ticket-slug>.md`, see "Where to store plan / session state files" in CLAUDE.md) as the canonical session state file for the plan.** Subsequent agents also Read it to pick up the state
- Structure:

```
# <Phase> / <Ticket ID>: <title> — Implementation plan

## Context
Why this change is needed (based on the DoD)

## Confirmed decisions
Enumerate the literals confirmed in Step 1.5. The source of truth on re-implementation, used by later agents for context bootstrapping. Permanent design decisions go here (never change these again; they're the target to update the spec side against).
| Decision item | Adopted literal | Basis (DoD or docs) |

## Scope decisions (intentional limitations coming from the DoD)
Scope explicitly limited by the DoD, e.g., "stub only is fine" / "implement in a later ticket." Not a deviation, so it's not flagged in the PR description.
| Scope limitation item | DoD basis | Follow-up ticket |

## Spec deviations (flagged in the PR description, for reviewer confirmation)
List only the "permanent structural choices" where the DoD / docs and the implementation diverge. Sort Scope decisions / Phase 2+ migration into their own categories; leave here only **the items you want the reviewer to confirm are OK**.
| # | Deviation | Remediation plan (update spec / keep as-is / revisit later) |

## Phase 2+ migration (to become follow-up tickets)
Provisional implementations at the prototype stage that are planned to be refactored at production migration time. Record as a follow-up in a Notion ticket comment, etc.; not implemented in this PR.
| Provisional implementation | Future form | Follow-up ticket / link |

## Carryover (existing issues, separate ticket)
Existing issues out of scope for this ticket that this PR won't touch, but that you want to keep visible.
| Existing issue | Impact scope | Ticket to address it |

## Documentation updates (by Tier)
Organize the contradictions extracted in Step 1.5 by Tier. State explicitly how each is handled in this ticket.
| Target doc | Fix content | Tier (1/2/3/4) | Handling (same commit / same PR / separate ticket) |

## Current state (updated as you go)
Progress state. So that a later agent / your future self can bootstrap context with a single Read.
- Stage X complete / Y in progress
- Latest commit: <hash>
- Pending questions: ...

## Design review (api-design-review)
Summary of the api-design-review skill run from Step 5.5. Keeps the gap-catching auditable.
- Whether each of the 6 perspectives found something
- Items already reflected in fixes
- Items resolved by user judgment
- Items left outstanding (follow-up ticket)

## Key design decisions
| Decision item | Decision | Basis |

## Implementation steps (execution order)
### Step 1: ...
- New / edited files + a summary of the content

## Mapping between DoD and implementation steps
| Notion DoD item | Corresponding step | Verification method |

## Anticipated pitfalls

## Verification procedure (after implementation is complete)

## Handoff to the next ticket (out of scope)

## References
- ticket URL
- paths under docs/...
```

### Step 7: Get approval via ExitPlanMode

Call ExitPlanMode to request plan approval. Write the Bash categories needed for implementation into allowedPrompts (e.g., `[{tool: "Bash", prompt: "run go commands"}]`).

## Iron rules

1. **Strict plan-mode discipline**: the only file edits are to the plan file. Everything else is read-only
2. **Get approval via ExitPlanMode**: don't ask "is this OK?" / "OK to proceed?" in plain prose
3. **Respect past memory feedback**: e.g., omitting prototype-stage premises, terminology conventions (e.g., tenant→company), comment language, etc.
4. **Keep the plan scan-friendly**: make heavy use of tables and bullet lists. Avoid long prose paragraphs
5. **Make out-of-scope items explicit**: always separate out things handled by a different ticket / a later phase
6. **Maintain the state file**: update the plan file every time a key decision is confirmed / a spec deviation is discovered. Keep it in a state where a later agent / your future self can bootstrap context with a single Read
7. **Tier-based handling of doc updates**:
   - Tier 1+2 (mechanical alignment / following a confirmed design): fix in the same commit as the implementation
   - Tier 3 (requires a design decision): implement in the same PR if required by the DoD, otherwise a separate ticket if out of DoD scope
   - Tier 4 (full pseudocode rewrite): separate commit / separate ticket

   Record the target doc / fix content / Tier / handling in the plan file's "Documentation updates" section

## Behavior on completion

Once the user approves via ExitPlanMode, the skill ends. Implementation happens in a separate skill (e.g., `/go-bootstrap`, the `go-feature-tdd` subagent) or in the next turn.
