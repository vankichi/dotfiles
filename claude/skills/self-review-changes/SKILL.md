---
name: self-review-changes
description: Use when you want the most recent edit diff inspected — 「self review して」「review して」「修正箇所ないか確認して」. Holds a 10-perspective checklist (correctness / spec alignment / tests / dependencies / ops docs, etc.) in this single file, firing mechanically on diff content (default-on + reasoned skip). In interactive mode it presents a fix plan and Edits only after user approval. In loop-mode the `reviewer` agent preloads and applies it.
---

> **Source of truth:** `claude/ja/skills/self-review-changes/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# self-review-changes

A skill that re-scans the edit diff by perspective and surfaces fix candidates. **This file is the SoT for the perspective checklist** — interactive self-review and the loop-mode `reviewer` share the same checklist.

> **Division of labor with plugins**: `/code-review` and `/simplify` specialize in diff bugs / simplification. This skill is a broad review covering configuration accuracy / doc consistency / memory-convention alignment / spec alignment.

## Applicability

A file edit happened in the immediately preceding turn (before commit or right after the most recent commit), and the scope is visible in `git diff`.

## Procedure

1. **Read as an external reviewer** — through the eyes of someone seeing this code for the first time, not your own intent. Comments are a binding contract
2. **Grasp the diff** — `git status` / `git diff [--cached]` (after the most recent commit, `git show HEAD`) → Read all changed files (with the Read tool, not `cat` via Bash)
3. **Gather related information** — read the relevant `MEMORY.md` entries in full. Fetch the corresponding spec / work item if one exists
4. **Apply the perspectives** — the 10 below, per their skip conditions
5. **SoT cross-check** (mandatory before reporting a finding) — grep-verify (a) the spec's / ticket's prohibitions and Out of Scope, (b) the relevant design doc section, (c) invariants in DB schema / type-definition comments
6. **Output the integrated report** → approval → Edit → re-run build / test / lint + re-run related greps

**Don't**
- Cut the judgment short with "I intended it this way" / "that doesn't happen with typical input" / "it's fine because it's an internal caller"
- **Report a finding the SoT cross-check contradicts** (it burns both the retraction cost and the user's decision cost; this is factual verification, not a severity filter)
- Skip adversarial assumptions: wire form / nil / empty / boundary values / mid-cancellation / invalid specs

## Perspectives (all default-on; skip only on the mechanical condition, with a reason)

### correctness — skip: code diff 0

- **Input validation** — check 0 / negative / nil / empty / traversal at public APIs (`WithXxx` / `NewXxx` / handler arguments). Validation goes at the end of the constructor
- **Edge cases** — wire form with parameters (use `mime.ParseMediaType` for MIME) / empty after `strings.TrimSpace` / all batch elements failing / empty output
- **ctx** — respect `ctx.Deadline` / avoid unnecessary goroutine spawns / check `ctx.Err()` each time / **propagate to the deepest level** (including pre-processing loops)
- **Error contract** — the semantic contract of sentinels (transient vs permanent) / no retry on 4xx / port-level wrapping of boundary errors
- **Slice OOB** — a `len >= N` guard immediately before `slice[len-N:]`

### filetype-checks — skip: none

- **Go** — `gofmt` / `goimports` / godoc conventions / `fmt.Errorf("...: %w", err)` / ctx as the first argument / unnecessary exports
- **Config** (`.golangci.yaml` / Makefile / yaml / json) — format version (golangci-lint v1 vs v2) / regex globs (`gen` substring vs `^gen/` root-only) / indentation
- **Markdown** — relative links / code fence language tags / table cell-count consistency / heading hierarchy
- **Shell / Makefile / Dockerfile** — shell injection (quoting `$VAR`) / dangerous commands (`rm -rf`, `curl | sh`)
- **Proto** — package / option / field number / backward compatibility (`buf breaking`)

### conventions — skip: none

- Conformance to memory conventions — terminology / document style / comment language (English for `*.go`, Makefile, proto, shell) / commit message style
- **Transient information leaking in** — `ticket`, `in a later`, `future ticket`, `see (commit|PR) #`, ticket ID formats. Get the literal patterns from the project's `MEMORY.md` (hardcoding them in the skill is forbidden)
- **Cross-reference existence** — does the quoted wording of a section reference match the original
- **Speculative mapping** — comments filling in correspondences not written in the original

### spec-alignment — skip: no corresponding spec / work item

- **Reverse mapping** — map every change back to the spec section / DoD item it corresponds to
- **Unsatisfied DoD** — does each DoD item have a corresponding change + means of verification. Enumerate what's unsatisfied
- **Scope creep** — a change mapping to nothing = an out-of-instruction change. **Changes touching non-goals are critical** (escalate in loop-mode rather than auto-fixing)
- If the spec doc itself was edited — grep both the spec's literals (type names / enums / fields) and the same surface in the implementation, attaching to each divergence a "reason" and a "remediation: (a) match the spec / (b) update the spec / (c) a separate ADR"

### test-adversarial — skip: test file diff 0

- Ask of each assertion: "**is there a mutation that inverts the implementation's behavior and still passes?**"
- Be especially careful when input contains repeated content / identical values / nil / empty. Look for paths where `strings.Contains` / `len(got) > 0` / `errors.Is(...)` pass trivially
- Example: verifying carry-over with `strings.Contains` on the same sentence repeated 80 times → true even when carry-over is broken. The correct form verifies the boundary with a distinct marker + `HasPrefix`

### performance — skip: code diff 0

Statically flag suspicious spots only (no profiling; see `~/.claude/rules/performance.md` for detail).

- **Complexity** — an added loop nest at O(n²) or worse / degradation of an existing O(n) path
- **I/O** — batching or pre-fetching sequential I/O inside a loop (N+1 queries / one-at-a-time API calls)
- **Hot path allocation** — slice/map creation, string concatenation, `fmt.Sprintf` inside loops / consider `strings.Builder` or pre-sized capacity
- **Synchronization** — too coarse a lock scope / serial execution of independent work

### observability — skip: no new code path (docs / config / test only)

- Do new error paths and branches have logs that let an operator identify what happened (**conversely, flag verbose happy-path logs**)
- Does the error message alone convey "with which input / where / what to look at next"
- **PII / secrets leaking in is critical** — no PII, tokens, connection strings, or transcribed ticket bodies in logs / error messages / metric labels
- When adding a long-running process / scheduled job / external call, are success, failure, and duration observable (only in repos with a metrics stack)

### ops-docs-hazard — skip: no changes under `docs/runbook/**` and no shell-command code fences in the added docs lines

**How to read**: not "is the prose correct" but "**would an operator following this literally take a wrong or destructive action?**" Since the code perspectives skip at code diff 0, this is the only line of defense on docs-only changes.

- **Stated impact scope** — can the reader tell whether each command is single-target / all-records / irreversible. **A command without a stated scope is critical**
- **Destructive commands** — are irreversible commands explicitly forbidden or guarded. Has a path been created where the reader reaches one from another section's wording
- **Sufficiency of preconditions** — can the required permissions / time window / execution order / prior state be satisfied within the procedure. If they live in another doc, is there a link
- **Dead ends** — do the offered alternatives and next steps actually exist (no "do this" for a nonexistent command / unimplemented feature)
- **Effectiveness of prohibitions** — does the prohibited target actually point at the knob that determines the behavior
- **Re-billing / side effects** — if re-running incurs external API re-billing or duplicate processing, is that stated with how to avoid it
- **Counterexamples to quantifiers** — for each universal claim ("only", "always", "must"), look for one counterexample path (`~/.claude/rules/verify-before-assert.md`)

### dependency — skip: dependency file (go.mod / go.sum / package.json / lock files / import lines) diff 0

- **New dependency detection** — enumerate additions. **New dependencies require user approval** (CLAUDE.md conduct principles). In loop-mode, detection = immediate escalation
- Is the version bump intentional (flag out-of-instruction lock churn) / typosquat or install-script-bearing package / transitive dependency bloat / licence conflicts

### code-quality — skip: code diff 0

Not bug detection but the "better way to write it" perspective.

- **Duplication / reuse** — grep for an equivalent helper / util already in the repo. Is the same shape of processing written in 2+ places
- **Simplification** — unnecessary intermediate variables / deep nesting (flatten with early returns) / over-abstraction (an interface with a single implementation)
- **Naming / altitude** — does the name match the behavior, consistent with the repo's vocabulary. Is the abstraction level uniform within a function
- **Comments** — self-evident "what it does" comments and PR-facing explanations are removal targets. Write only "constraints that can't be expressed in code"
- **Constants** — are magic numbers / literals appearing 2+ times extracted into named consts. Are related constants grouped in a const block
- **Consistency within the PR** — re-grep the diff for the naming / consts / helpers you introduced to catch "only one side got a named const"
- `go-style` / `go-test` / `ddd-clean-architecture` are the SoT for convention detail

## Mechanical checks (reinforcing correctness — run with grep)

1. **Symmetry audit** — for each guard / validation / nil check added, confirm the symmetric counterparts carry the same guard (`grep "^func New" $(git diff --name-only)` for all constructors in the PR; also grep functions taking `opts ...Option`). Kills the class of omission where you fix one site and miss the rest
2. **Interface contract trace** — re-read the godoc of external interfaces used in changed files and confirm the sentinel return cases (0 / "" / nil / -1 / a specific error) line up with the consumer's branching (`if x <= X`, `errors.Is(...)`). Example: `CountTokens` returns 0 on encoding error → the consumer's `tokens <= MaxTokens` misjudges it as "fits"
3. **Doc last-write-wins** — after an implementation change, grep the changed files for strong claims (`grep -nE "(strictly|preserves|guarantees|ensures|always|never|returns|panics)"`) and cross-check each against the implementation's literal behavior at byte level (is "strictly under X" a `<` or a `<=`)
4. **Authoritative verification of external constants** — when the diff contains externally-sourced hardcoded constants (LLM pricing / model IDs / API rate limits), **verify the number itself against an authoritative source**. "Byte-identical to where it was ported from" is not evidence. The `claude-api` skill is the SoT for Anthropic pricing / model IDs

## Identifying false positives

Patterns you may resolve as "not applicable in this project context".

| Pattern | Basis |
|---|---|
| Go 1.22+ loop variable shadowing | Unnecessary if the `go.mod` go directive is 1.22+ |
| Re-proposal of an internal port boundary defense already withdrawn as an SD | Resolve by referencing the PR description |
| Duplicate posting of the same warning | When the pattern doesn't apply to the other test |

## Output format

```
## Self-review result

| Perspective | Performed/skipped (reason) | Findings |
|---|---|---|
| correctness | performed | 2 |
| dependency | skipped (dependency file diff 0) | - |
...

| # | file:line | Problem | Fix approach | Severity |
|---|---|---|---|---|
| 1 | cmd/x/main.go:1 | Comment in Japanese | Rewrite in English | critical (memory convention violation) |

## No problems
- <targets checked but found clean>
```

Severity has 3 tiers: **critical / desirable / nit**.

## Iron rules

1. **Always output every perspective's execution status as a table** — silent skipping is forbidden. Skips require a mechanical condition + a reason
2. **Don't pre-filter by severity** — list every finding, then classify into the 3 tiers (an "only the serious ones" filter reduces the reporting itself)
3. **Read the related memory entries in full** — judging from the index line alone is forbidden
4. **Don't hide anything** — point out problems even in something you created in the immediately preceding turn
