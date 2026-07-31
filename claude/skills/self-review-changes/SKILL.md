---
name: self-review-changes
description: A skill that self-reviews the most recent edit diff (working tree or staged) by perspective. Perspectives are split into references/ and fire mechanically based on diff content (default-on + reasoned skip). In interactive mode it presents a fix plan and Edits only after user approval. In loop-mode this skill is not invoked directly; the review-orchestrator agent reads this skill's perspective system (references/) and orchestrates the perspective review (a scale gate switches between fanning out to review-lens and applying them inline itself). Used for 「self review して」(self-review this)「review して」(review this)「修正箇所ないか確認して」(check whether there's anything to fix) etc.
---

> **Source of truth:** `claude/ja/skills/self-review-changes/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# self-review-changes

A skill that re-scans the most recent edit diff by perspective, surfaces fix candidates, and fixes them. **4 phases**: Mindset → Observation → Perspective execution → Action.
The perspective content is split into `references/` at one perspective per file (the skill-granularity principle).

> **Division of labor with plugins**: the `/code-review` and `/simplify` plugins specialize in diff bugs / simplification. This skill is a broad self-review that also covers configuration accuracy / doc consistency / memory feedback alignment / spec alignment. Use `/code-review` for bugs in the code alone, and this skill to review the whole change including conventions.

## Applicability

- Some file edit happened in the immediately preceding turn (before commit or right after the most recent commit)
- The scope of the fix target is clear (visible in `git diff`)

## Phase 0: Mindset shift (implementer → external reviewer)

The biggest bias in self-review is that "you can see your own intent but not the actual gap." Before moving on to Phase 1, internally declare that you will read the code as **"an external reviewer seeing this code for the first time."** Treat comments as a binding contract; phrases like "I intended it this way," "that doesn't happen with typical input," or "it's fine because it's an internal caller" are forbidden. Adversarially assume wire form / nil / empty / boundary values / mid-cancellation / invalid specs, and so on.

## Phase 1: Observation (grasp the diff + gather related information)

1. Grasp the diff: `git status` / `git diff --stat` / `git diff [--cached]` (after the most recent commit, `git show HEAD`)
2. Read all changed files in parallel with the Read tool (not `cat` via Bash)
3. Read the `MEMORY.md` index and read the feedback / project entries related to the edit in full
4. If there is a corresponding spec / work item, fetch it (input for the spec-alignment perspective)
5. **SoT cross-check (mandatory step before reporting a finding)**: for the area you are about to flag, grep-verify (a) the spec's / ticket's prohibitions and Out of Scope, (b) the relevant section of the design doc, (c) invariants declared in DB schema / type-definition comments. **Do not report a finding that the cross-check contradicts** — it burns both the retraction cost and the user's decision cost. Verify before presenting options to the user, too

## Phase 2: Perspective execution (default-on + mechanical skip judgment)

All perspectives are default-on. **You may skip only when the mechanical condition in the table below is met**, and skips require a reason:

| Perspective (references/) | Condition allowing skip (mechanical judgment) |
|---|---|
| correctness.md | code diff is 0 (docs / config-only change) |
| filetype-checks.md | none (always performed) |
| conventions.md | none (always performed) |
| spec-alignment.md | no corresponding spec / work item exists |
| test-adversarial.md | the test file diff is 0 |
| performance.md | code diff is 0 |
| observability.md | no new code path (docs / config / test only) |
| ops-docs-hazard.md | the diff of operational-procedure docs is 0 (no changes under `docs/runbook/**`, and no shell-command code fence in the added docs lines) |
| dependency.md | the diff of dependency files (go.mod / go.sum / lock / import lines) is 0 |
| code-quality.md | code diff is 0 |

- Read the references for the perspectives you will perform, and apply the checklist to the diff
- **loop-mode**: this skill is not invoked directly; the `review-orchestrator` agent Reads this SKILL.md and references/ and orchestrates the perspective review. If the scale gate says fan-out, it passes the perspective reference path + diff range + spec to `review-lens`, launched in parallel and **synchronously**; if inline, the reviewer applies the perspective references itself, sequentially (review-orchestrator steps 3-4 are the SoT for the gate). In interactive mode, perform them inline in order
- If the dependency perspective detects a new dependency, escalate immediately in loop-mode (a CLAUDE.md wall)

## Phase 3: Action (integrated report → approval → fix → re-verify)

### 3.1 Integrated report (mandatory output)

**Always output the execution status of every perspective as a table** (no silent skipping):

```
## Self-review result

| Perspective | Performed/skipped (reason) | Findings |
|---|---|---|
| correctness | performed | 2 |
| dependency | skipped (dependency file diff 0) | - |
...

| # | file:line | Problem | Fix approach | Severity |
|---|---|---|---|---|
| 1 | cmd/x/main.go:1 | Comment in Japanese | Rewrite in English | critical (memory feedback violation) |

## No problems
- <targets checked but found clean>
```

Severity has 3 tiers: **critical / desirable / nit**.

### 3.2 Approval

- **Interactive mode**: wait for "go ahead" (selective approval OK)
- **loop-mode**: review-orchestrator's verdict (fix instructions) is applied by dev-cycle and confirmed resolved through iterative re-review. When 0 critical findings remain and only desirable ones do, the verdict is `approve-with-notes` (whether to push them to notes or fix them + re-review is dev-cycle's choice); nits are noted in the draft PR

### 3.3 Fix via Edit (parallel) → 3.4 Re-verification

Apply approved candidates in parallel with Edit → re-run `make test` / `make lint` + re-run related greps (check whether the same problem propagated to another location).

## Iron rules

1. **Don't skip the Phase 0 mindset shift**: judge based on "code and comments alone, as an external reviewer," not "your own intent"
2. **Always output the perspective execution-status table**: no silent skipping. Skips require a mechanical condition + a reason
3. **Distinguish critical / desirable / nit**: so the user can pick and choose. **List every finding first, then classify into the 3 tiers — don't pre-filter by severity** (a "only the serious ones" filter reduces the reporting itself. The SoT cross-check in Phase 1 step 5 is factual verification, not a severity filter — keep it)
4. **Read memory feedback related entries in full**: don't judge from the index line alone
5. **Explicitly state, get approval for, and record spec deviations**: don't use "it's a prototype" as an implicit justification (CLAUDE.md's "conduct for changes")
6. **Verify side effects**: re-run build / test / lint after fixing
7. **Don't hide anything**: point out problems even in something you created in the immediately preceding turn
