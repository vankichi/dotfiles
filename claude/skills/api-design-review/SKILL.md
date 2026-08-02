---
name: api-design-review
description: A read-only review skill that surfaces overlooked considerations in API / upstream design (ADR / Design Doc / API contracts / domain models / ACL) across 6 axes. Invoke it at the logical design stage, before it's committed to a wire representation — before ExitPlanMode / when drafting an ADR / when a Design Doc draft is complete. Used for things like 「設計 review して」「考慮漏れチェック」.
when_to_use: Before drafting an ADR / Design Doc or when a draft is complete; before committing a new API contract to wire; when designing domain models / ACL. Triggers: 「設計 review して」「考慮漏れチェック」. Not for bug fixes, typos, or internal refactors.
model: fable
---

> **Source of truth:** `claude/ja/skills/api-design-review/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# api-design-review

A systematic review skill for **preventing piecemeal discovery across turns** in upstream design. Read-only (no Edit / Write; Bash for grep only). **Conducted from a principal engineer's standpoint**: not whether the expression is valid, but whether the design decision itself is right — right for future extension, for operations, for the maintainer.

Overlooked considerations originate not in the wire representation (proto / OpenAPI) but in the domain design / use case analysis / ACL model that precedes it, so this is most effective **before you start writing proto**.

## Applicability

**Do run it**: before drafting a new ADR / when creating a Design Doc or adding chapters / for the logical design of a new API contract (before committing to wire) / for new or revised domain models, Aggregates, Bounded Contexts / for use case analysis involving verbs beyond CRUD / for ACL, authorization, multi-tenant separation design. It also serves as a downstream supplement before structural changes to existing messages / enums and when reworking an SDK surface.

**Don't run it**: bug fixes / typos / format / lint / internal refactors that don't affect existing contracts / minor docs updates. Minor changes are covered by CLAUDE.md's everyday checks (this skill is for heavy analysis only).

## Approach (one pass ≈ 20-40 minutes)

Read the design target (ADR draft / Design Doc / proto / related docs), then **write out each of the 6 perspectives below one at a time**. State "not applicable" explicitly where it applies (**a blank = not considered = an omission**).

### 1. Separating client abstraction from server-side expansion

Enumerate the concepts / fields / enum values / RPC parameters involved and determine: (a) is it a value the client can directly know or derive (its own id / user input / its own configuration), (b) is it a value the server derives from context (another tenant's id / auth information / internal resource ids / roles / cross-tenant fan-out targets), and (c) **is anything from (b) placed on the wire / contract / public surface**. If (c) exists, take it off the wire and move it to a server-side concept. Check SDK examples too.

- **Ask**: "how would the client know this concept?" / "are we exposing information the client must not have in the contract?"
- **Case**: a proposal to put `repeated string product_ids` in the proto → clients don't know other product_ids (information leak + ACL bypass) → moved to a server-side concept

### 2. Both the read and write sides of ACL

When ACL / visibility / access control is involved (state "not applicable" if not):

- The **read** side (search filter / fetch / row-level / collection ACL): its representation and server-side behavior
- The **write** side (visibility / permitted principals per scope / write authorization / role-based gating): its representation and server-side behavior
- Cases where the same visibility has different permitted roles for internal vs external submission, or admin vs regular
- Behavior on authorization failure (403 vs 404 / information leak risk)

Write permission belongs in the **ACL domain layer (ReBAC / ABAC), not a wire field** (baking it into a proto field makes it spoofable). Splitting endpoints (`/v1/upsert` vs `/v1/admin/upsert`) is one way to surface the permission boundary on the wire.

- **Ask**: "**who can write** this visibility / scope?" / "what's the risk of an individual caller writing a broad visibility?"

### 3. Systematic forward-compat check

List 3-5 foreseeable future extensions (cross-tenant / admin / batch / streaming / roles / scope groups / pre-signed URLs / async workers / multi-region, etc.) and write 1-3 lines on whether each can be handled **non-breaking**. Enum value additions / field additions / new RPCs / new messages are non-breaking in proto3 and OpenAPI. Cases that require breaking changes should be completed within the Phase.

- **Case**: a design baking a transient label (an org name) into an enum rotted on reorganization → renamed to org-free names (CURATED / BOOK, etc.)

### 4. Enumerating edge cases

From the axes below, **write out 5-10 domain questions and answer each one**. Any area whose answer is "not considered" or "later" is exactly what this phase must settle:

Re-submission of the same ID / duplication / idempotency (overwrite vs `AlreadyExists` vs version vs soft delete) / handling of empty, null, zero values (reject vs defaulting) / set operations (cross-tenant / wildcards / subsets) / boundary values (max payload / array length / pagination / rate limit / timeout / retry) / timezone, locale, encoding (UTF-8 / multi-byte / Japanese-specific concerns) / partial failure (compensation for mid-batch failure) / ordering and concurrency / behavior on authorization failure / format conversion and inference (what happens when inference fails) / behavior when a dependency is down (degraded / circuit breaker) / **operational re-execution of state transitions** (what happens when an operator redrives something that landed in this state)

- **Case**: "what if the organization disappears?" and "how do we separate internal vs external FAQ?" for source_type surfaced at turn 4 → led to narrowing the classification axis to format

### 5. Consistency with the existing SoT (grep-first)

**Before** introducing new naming / structure, grep the entire existing SoT. Check whether old field names / method names / enum values / ADR numbers / terminology remain in docs / metadata literals / SDK examples / proto / code / notes, targeting the **whole repo** (narrowing by directory misses root instruction files):

```bash
git grep -nE "<old-name-pattern>"
```

Root instruction files (`CLAUDE.md` / `.github/copilot-instructions.md` / `.claude/rules/`) are loaded by the agent every time and are therefore a path by which a stale contract propagates into later implementation — always include them. Conversely, revision history / changelog lines are immutable; don't touch them even on a hit.

**Grepping names is necessary but not sufficient.** When the design target describes a process flow (producer / worker, etc.), also read the **flow / lifecycle description** of the related Accepted ADRs and design docs (which row is created by whom and when / the dedup method / the observation boundary on failure) and confirm the design doesn't contradict them.

Also check **whether a newly introduced state breaks the transitions an existing runbook assumes**: enumerate the states you'll newly write → confirm each has an exit in the state machine → grep for operational procedures ("redrive to reprocess") that assume a terminal state with no exit. A structure that contradicts existing procedures the moment you add a writer of a terminal state can only be caught cheaply at this pre-implementation stage.

- **Ask**: "what condition makes grepping the old name return 0 hits?" / "does the flow description of the related Accepted ADR match the design's flow?"
- **Case (naming)**: the old `accessScopes` surface remained in an SDK example in the docs and surfaced at turn 4
- **Case (flow)**: a ticket's producer/worker flow (create PENDING before enqueue / explicit dedup) was the exact inverse of the related Accepted ADR's core decision (worker INSERTs on receipt / content-based dedup). Grepping the field name caught the naming overlap but missed the prose flow contradiction; it surfaced only at the review iteration cap → escalation

### 6. Compliance with memory conventions

Do one pass for convention violations (CLAUDE.md and the individual skills are the SoT). Commonly violated:

Phase / ticket / PR references left in comments / code comments in Japanese / inline comments inside tests / a preamble section at the top of docs / per-ticket plans committed to the repo / speculative mapping in comments beyond the original's literal / skipping plan-first on a multi-file change / spec deviations missing from the plan / auto-creating PRs / misnaming product terminology / vocabulary that contradicts architectural premises. Mechanical issues like unused imports are also covered here.

## Output

For each perspective, write "detected (or not applicable)" and "proposed action (or fine as is)", then close with a summary (OK to proceed / N items need fixing / M items need user judgment). Perspective 4 takes the form of 5-10 questions with answers; perspective 5 includes the grep hit list.

When called from dev-cycle, the result summary is recorded in the state file's "Design review" section (the recording rule lives on the dev-cycle side).

## What this skill does not do

No implementation / Edit / Write / git mutation / PR creation. It also does not call `AskUserQuestion` itself (it returns results to the caller, and the caller seeks the user's judgment).
