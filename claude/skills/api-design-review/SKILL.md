---
name: api-design-review
description: A read-only review skill that surfaces overlooked considerations in API / upstream design (ADR / Design Doc / API contracts / domain models / ACL) across 6 axes. Invoke it at the logical design stage, before it's committed to a wire representation — before ExitPlanMode / when drafting an ADR / when a Design Doc draft is complete. Used for things like 「設計 review して」「考慮漏れチェック」.
model: claude-fable-5
---

> **Source of truth:** `claude/ja/skills/api-design-review/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# api-design-review

A systematic review skill for API / upstream system design that **prevents issues from surfacing piecemeal across turns**. Read-only (no Edit / Write; only grep via Bash is allowed).

The source of overlooked considerations isn't the wire representation (proto / OpenAPI) but the **domain design / use-case analysis / ACL model / API experience design that precedes it** — so running this **before** starting to write proto is most effective. Reviewing after proto work has already begun is only supplementary.

## Applicability

Invoke in any of the following cases:

### During upstream design (primary use)
- **Before** drafting a new ADR, or when the draft is complete (MADR v3, `docs/adr/`)
- When newly creating a Design Doc / System Design (arc42 / C4) or adding a section (`docs/design/`)
- During the logical design of a new API contract (proto / OpenAPI / GraphQL schema), before committing it to wire form
- When newly creating or revising a domain model / Aggregate / Bounded Context
- During use-case / user-story analysis, especially when verbs other than CRUD are involved
- When designing an ACL / authorization / multi-tenant isolation model

### Downstream supplement (after starting to touch proto / OpenAPI)
- Before a structural change to an existing message / enum (extracting a sub-message / renaming a field / adding an enum value)
- When revising the SDK surface (TypeScript / Go, etc.)
- When applying plan-first to a multi-file refactor, before ExitPlanMode

### When not to invoke
- Bug fixes / typos / formatting / lint fixes
- Internal refactors with no impact on an existing contract
- Minor documentation-only updates

For minor changes, the everyday checks in CLAUDE.md's 「判断と質問の作法」section suffice (this skill is **reserved for heavyweight analysis**).

## Approach (one pass ≈ 20-40 minutes; allow more time the further upstream you are)

After reviewing the design target (Read the ADR draft / Design Doc / proto / related docs), **work through the following 6 perspectives one at a time, writing each down**. For each perspective, explicitly state "not applicable" where relevant (a blank = not considered = an oversight).

### 1. Separating client abstraction from server-side expansion

Enumerate the concepts / fields / enum values / RPC parameters that appear in the design target, and for each:

- (a) Is it **a value the client / caller / external user can directly know or derive** (their own id, user input, in-house configuration values)?
- (b) Is it **a value the server / platform derives from context** (other tenants' ids, authentication info, internal resource ids, role / claims, cross-tenant fan-out targets)?
- (c) Are there any places where (b) has been placed on the wire / contract / public surface?

If (c) is found, remove it from the wire and move it to a server-side concept. Also check the SDK examples.

**Check phrasing**: "How would the client come to know this concept?" / "Does the contract expose information the client shouldn't know?"

**Past case**: a proposal to put `repeated string product_ids` in the proto → the client doesn't know other product_ids (information leak + ACL bypass); it was removed from the wire and moved to a server-side concept (collection-level config / access_group, etc.)

### 2. Both the read and write sides of ACL

When ACL / visibility / access control is involved (state "not applicable" explicitly when it isn't):

- (a) The representation and server-side behavior of **reads** (search filter / fetch / row-level / collection ACL)
- (b) The representation and server-side behavior of **writes** (who's authorized per visibility / scope / write authorization / role-based gating)
- (c) Consider cases where, even for the same visibility, the authorized role differs between internal vs external submission, or admin vs regular
- (d) Behavior on authorization failure (403 vs 404 / information leak risk)

Write authorization should be determined by the ACL domain layer (ReBAC / ABAC, etc.), not a wire field (baking it into a proto field makes it spoofable). Splitting endpoints (`/v1/upsert` vs `/v1/admin/upsert`) is an option for exposing the authorization boundary on the wire surface.

**Check phrasing**: "**Who can write** this visibility / scope?" / "What's the risk of an individual caller writing a broad visibility?"

**Past case**: the risk of an individual product client being able to write PRODUCT_WIDE went undiscussed → it was decided to handle the write side of ACL in a separate ADR (ReBAC/ABAC)

### 3. Systematic forward-compat check

How the design target might be extended in the future, and whether it can be handled non-breaking:

- Adding an enum value (non-breaking in proto3; appending is fine in OpenAPI too)
- Adding a field (a new field number / property; non-breaking in proto3 / OpenAPI)
- Adding a new RPC / new endpoint / new service
- Adding a new message / new schema
- Compatibility when an ADR is revised / withdrawn

List 3-5 foreseeable future extensions (cross-tenant / admin / batch / streaming / role / scope group / pre-signed URL / async worker / VLM / multi-region, etc.) and check whether each can be handled with a non-breaking extension. Cases that require a breaking change should be completed within the current Phase.

**Check phrasing**: for each extension case, write 1-3 lines answering "When X arrives in the future, how would the contract be extended?"

**Past case**: a design that baked a transient label (e.g. an organization name like "academy") into an enum / field rotted when the organization changed; it was changed to organization-name-free naming (CURATED / BOOK, etc.)

### 4. Enumerating edge cases ("what happens when...?")

**Write out 5-10** of the following domain questions against the design target **and answer each one**:

- **Resubmitting the same ID / duplicates / idempotency** (Upsert: overwrite / `AlreadyExists` / version / soft delete / version vector)
- **empty / unspecified / null / zero value** (how each field handles it — reject via validation, or default it)
- **Set operations** (cross-tenant / cross-company / global wildcard `*` / subset / select-all)
- **Boundary values** (max payload / max array length / pagination / rate limit / timeout / retry policy)
- **timezone / locale / encoding** (UTF-8 / multi-byte / collation / Japanese-specific concerns)
- **Partial failure** (a batch operation failing partway through; idempotency / compensating transactions)
- **Ordering / duplication / idempotency / concurrency**
- **Authentication / authorization failure behavior** (403 vs 404 / information leak risk)
- **Format conversion / inference** (mime_type auto-inference / explicit / fallback / when inference fails)
- **Behavior when a dependent service fails** (degraded / circuit breaker / fallback)

**Check phrasing**: from a domain angle, come up with 5-10 instances of "what happens with X in this situation?" If the answer comes out as "not considered" or "to be considered later," that's an area where the design phase should produce an answer

**Past case**: for source_type, the questions "what happens if the organization is deleted?" and "how do we separate internal FAQ vs external FAQ?" surfaced at turn 4 → led to the decision to narrow the classification axis to format

### 5. Consistency with the existing source of truth (grep-first)

**Before** introducing new naming / new structures, grep the entire existing source of truth:

- Whether old field names / old method names / old enum values / old ADR numbers / old design-doc terminology still remain in docs / api.md / metadata literals / SDK examples / proto / Go code / Markdown notes
- Grasp the scope of changes **across all files at once** (to prevent issues from surfacing piecemeal across turns)
- When design is complete, prepare 5-10 grep verification conditions (the literal `grep -nE "..."` command, recorded in the PR description / commit description / ADR appendix)

Via Bash:
```bash
grep -rnE "<old-name-pattern>" docs/ apis/ internal/ cmd/ cli/
```

Include the resulting hit list in the design output to finalize the scope of changes.

**Name grep is necessary but not sufficient** — when the design target describes a **process flow** (producer / worker, etc.), also read through the related Accepted ADR / design doc's **flow / lifecycle prose** (which row is created by whom and when, the dedup method, the failure-time observation boundary) and check that the design doesn't contradict it. Grepping field / enum names catches naming overlap but can't detect contradictions between the ADR's prose flow (e.g. "the worker INSERTs on receive", "content-based dedup") and the design. When a related ADR is Accepted, compare its core decisions against the design's flow one by one and check they aren't inverted.

**Check phrasing**: "What condition makes grepping for the old name return 0 hits?" / "How many places will the new name be added to?" / "Does the design's flow match the related Accepted ADR's flow / lifecycle description (who creates what and when · dedup · observation boundary)?"

**Past case (naming)**: the old `accessScopes` surface was left behind in the docs §11.2 SDK example, discovered at turn 4 → should have grepped during design to grasp every location up front

**Past case (flow)**: a ticket's producer/worker flow (create status=PENDING before enqueue / explicit dedup / an idempotency key in the message) was the exact opposite of the related Accepted ADR's core decisions (the worker INSERTs on receive / content-based dedup / an enqueue failure is observed outside the DB); the `idempotency_key` field-name grep caught the naming overlap but the prose-flow contradiction was missed and only surfaced at the review-iteration cap → escalation; name matching alone wasn't enough — the ADR's flow prose should have been cross-checked too

### 6. Compliance with memory conventions (check every time)

Do one review pass to check the design target doesn't violate any of the following conventions (the source of truth is CLAUDE.md / each skill):

| Convention | Common places it's violated |
|---|---|
| Don't leave Phase / ticket references in comments | Phase / ticket / PR references in proto / Go comments |
| Commit titles are concise (1 line) | Commit title is a long sentence |
| Code comments are in English | *.go / proto / Makefile / shell comments in Japanese |
| Push only after explicit user instruction (CLAUDE.md) | A push proposal without user confirmation |
| No inline comments inside tests | Inline comments inside a test |
| Don't open docs with a preamble/assumptions section | A scope/preamble section at the top of docs |
| Don't put individual ticket plans in the repo | An individual ticket plan under docs/plan/ |
| Comments stay within the literal scope of the source text (no speculative mapping) | A comment with speculative mapping that goes beyond the literal scope of the source text |
| Multi-file changes are plan-first (CLAUDE.md) | Skipping the plan despite a multi-file change |
| Deviations from spec are stated explicitly, approved, and recorded (CLAUDE.md) | A literal deviation from spec not written into the plan |
| Substantive edits go through a subagent | The primary agent directly makes a substantive Edit |
| PRs are not auto-created (CLAUDE.md) | Auto-creating a PR |
| Subagent briefs reference a state file | Repeating context inline in a subagent brief |
| Adherence to the design-phase checklist | Failing to comply with this very checklist |
| Accuracy of product terminology | Misnaming a product or term |
| Adherence to architectural assumptions | Terminology creeping in that contradicts architectural assumptions |

Also check for things like unused imports / mechanical consistency gaps under this perspective.

## Output format

When the skill completes, present the following to the user as the deliverable:

```markdown
# api-design-review results

## Design target
<path or name of the target ADR / Design Doc / proto / API spec / domain model>

## Review by perspective

### 1. Client abstraction vs server-side expansion
- Findings: <content, or "not applicable">
- Proposed fix: <proposal, or "fine as-is">

### 2. Both sides of ACL read/write
- Findings: ...

### 3. forward-compat
- Findings: ...

### 4. Edge case enumeration
5-10 items in question form, each with an answer

### 5. Consistency with the existing source of truth (grep results)
- `grep -rnE "..."` → hit list

### 6. Compliance with memory conventions
- Potential violations: <content, or "clear">

## Summary
- OK to proceed with the design (nothing found): ◯
- Fixes needed (specific locations): X items → ...
- Requires user judgment (trade-offs presented): Y items → ...
```

When handing off to the main agent / dev-cycle / Plan agent / tech-docs-writer, writing the above out to a state file keeps the brief lightweight when a subagent restarts (a state-file-referencing brief).

## What this skill does not do

- Does not implement / Edit / Write (read-only review)
- Does not perform git mutations / push / create PRs
- Does not call AskUserQuestion within the skill (returns results to the main agent, which defers to the user's judgment)

## Related artifacts

- Everyday check (lightweight version): CLAUDE.md's 「判断と質問の作法」section
- Related skills / agents: `tech-docs-writer` (passes through this skill internally when drafting an ADR / Design Doc), `dev-cycle` (passes through this skill in its design-review stage), `ddd-clean-architecture` (layer boundaries / dependency direction, related to this skill's perspective 1), `code-refactor-advisor` (implementation-facing refactor candidates, the implementation-pass version of this skill)
- Handoff to the main agent: a state-file-referencing brief
- Built into the agent side: the `dev-cycle` agent's design-review stage passes through this skill (already integrated)
