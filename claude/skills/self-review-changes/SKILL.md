---
name: self-review-changes
description: A skill that self-reviews the most recent edit diff (working tree or staged) by perspective. It holds the 10-perspective checklist in this single file, firing mechanically based on diff content (default-on + reasoned skip). In interactive mode it presents a fix plan and Edits only after user approval. In loop-mode the `reviewer` agent reads this checklist and applies it. Used for 「self review して」「review して」「修正箇所ないか確認して」 etc.
---

> **Source of truth:** `claude/ja/skills/self-review-changes/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# self-review-changes

A skill that re-scans the edit diff by perspective and surfaces fix candidates. **This file is the SoT for the perspective checklist** — interactive self-review and the loop-mode `reviewer` agent share the same checklist.

> **Division of labor with plugins**: `/code-review` and `/simplify` specialize in diff bugs / simplification. This skill is a broad review that also covers configuration accuracy / doc consistency / memory-convention alignment / spec alignment.

## Applicability

- Some file edit happened in the immediately preceding turn (before commit or right after the most recent commit)
- The scope of the fix target is visible in `git diff`

## Procedure

1. **Read as an external reviewer**: read as "someone seeing this code for the first time," not through "your own intent." Comments are a binding contract. "I intended it this way," "that doesn't happen with typical input," and "it's fine because it's an internal caller" are forbidden. Adversarially assume wire form / nil / empty / boundary values / mid-cancellation / invalid specs
2. **Grasp the diff**: `git status` / `git diff [--cached]` (after the most recent commit, `git show HEAD`) → Read all changed files (with the Read tool, not `cat` via Bash)
3. **Related information**: read the relevant `MEMORY.md` feedback / project entries in full. Fetch the corresponding spec / work item if one exists
4. **Apply the perspectives**: apply the 10 perspectives below according to their skip conditions
5. **SoT cross-check (mandatory step before reporting a finding)**: for the area you are about to flag, grep-verify (a) the spec's / ticket's prohibitions and Out of Scope, (b) the relevant section of the design doc, (c) invariants declared in DB schema / type-definition comments. **Do not report a finding that the cross-check contradicts.** This is factual verification, not a severity filter
6. **Output the integrated report** → approval → Edit → re-run build / test / lint + re-run related greps (check whether the same problem propagated elsewhere)

## Perspectives (default-on. Skip only when the mechanical condition below is met, with a reason)

### correctness — skip: code diff 0
- **Input validation**: check 0 / negative / nil / empty / traversal at public APIs (`WithXxx` / `NewXxx` / handler arguments). Place validation at the end of the constructor
- **Edge cases**: wire form with parameters (use `mime.ParseMediaType` for MIME) / empty after `strings.TrimSpace` / all batch elements failing / empty output
- **ctx**: respect `ctx.Deadline` / avoid unnecessary goroutine spawns / check `ctx.Err()` each time / **propagate to the deepest level** (including pre-processing loops)
- **Error contract**: the semantic contract of sentinels (transient vs permanent) / no retry on 4xx / port-level wrapping of boundary errors
- **Slice OOB**: a `len >= N` guard immediately before `slice[len-N:]`

### filetype-checks — skip: none
- **Go**: `gofmt` / `goimports` / godoc conventions (`// Package <name>` / `// FuncName ...`) / `fmt.Errorf("...: %w", err)` / ctx as the first argument / unnecessary exports
- **Config (`.golangci.yaml` / Makefile / yaml / json)**: format version (golangci-lint v1 vs v2) / regex globs (`gen` substring match vs `^gen/` root-only) / indentation
- **Markdown**: relative links / code fence language tags / table cell-count consistency / heading hierarchy
- **Shell / Makefile / Dockerfile**: shell injection (quoting `$VAR`) / dangerous commands (`rm -rf`, `curl | sh`)
- **Proto**: package / option / field number / backward compatibility (`buf breaking`)

### conventions — skip: none
- Conformance to memory conventions: terminology / document style / comment language (English for `*.go`, Makefile, proto, shell) / commit message style
- **Transient information leaking in**: `ticket`, `in a later`, `future ticket`, `see (commit|PR) #`, ticket ID formats. Get the literal inspection patterns from the project's `MEMORY.md` — don't hardcode them in the skill
- **Cross-reference existence check**: does the quoted wording of a section reference in a comment match the original
- **Speculative mapping**: are comments filling in correspondences not written in the original

### spec-alignment — skip: no corresponding spec / work item
- **Reverse mapping**: map every change in the diff back to the spec section / DoD item it corresponds to
- **Unsatisfied DoD**: does each DoD item have a corresponding change + means of verification. Enumerate what's unsatisfied
- **Scope creep**: a change that maps to no section = an out-of-instruction change. Changes touching non-goals are **critical** (in loop-mode, escalate rather than auto-fix)
- If the spec doc itself was edited, grep both the literals in the spec (type names / enums / fields) and the same surface on the implementation side, and attach to each divergence a "reason" and a "remediation: (a) match the spec / (b) update the spec / (c) a separate ADR"

### test-adversarial — skip: test file diff 0
- For each assertion, ask "**is there a mutation that inverts the implementation's behavior and still passes?**"
- Be especially careful when the input contains repeated content / identical values / nil / empty. Look for paths where `strings.Contains` / `len(got) > 0` / `errors.Is(...)` pass trivially
- Example: verifying carry-over with `strings.Contains` on an input of the same sentence repeated 80 times → true even if carry-over is broken. The correct form verifies the boundary with a distinct marker + `HasPrefix`

### performance — skip: code diff 0
Don't profile; statically flag suspicious spots (see `~/.claude/rules/performance.md` for the detailed criteria).
- **Complexity**: is an added loop nest O(n²) or worse / does it degrade an existing O(n) path
- **I/O**: can sequential I/O inside a loop (N+1 queries / one-at-a-time API calls) be batched or pre-fetched
- **Hot path allocation**: slice/map creation, string concatenation, `fmt.Sprintf` inside loops / consider `strings.Builder` or pre-sized capacity
- **Synchronization**: too coarse a lock scope / serial execution of independent work that could run in parallel

### observability — skip: no new code path (docs / config / test only)
- Do new error paths and branches have logs that let an operator identify "what happened" (conversely, flag verbose logs on the happy path)
- Does the error message alone convey "with which input / where / what to look at next". Is context (id / key / count) wrapped in
- **PII / secret leaking in**: no PII, tokens, connection strings, or transcribed ticket bodies in logs / error messages / metric labels (**critical**)
- If you added a long-running process / scheduled job / external call, are success, failure, and duration observable (only in repos that have a metrics stack)

### ops-docs-hazard — skip: no changes under `docs/runbook/**` and no shell-command code fences in the added docs lines
Read for "**would an operator following this procedure literally take a wrong or destructive action?**", not "is the prose correct". Since the code perspectives skip at code diff 0, this is the only line of defense on docs-only changes.
- **Stated impact scope**: can the reader tell from the text whether each command is single-target / all-records / irreversible. A command without a stated scope is **critical**
- **Destructive commands**: are irreversible commands explicitly forbidden or guarded. Has a path been created where the reader reaches an irreversible command from another section's wording
- **Sufficiency of preconditions**: can the required permissions / time window / execution order / prior state be satisfied within the procedure. If they live in another doc, is there a link
- **Dead ends**: do the offered alternatives and next steps actually exist (don't write "do this" for a nonexistent command / unimplemented feature)
- **Effectiveness of prohibitions / warnings**: does the prohibited target actually point at the knob that determines the behavior
- **Re-billing / side effects**: if re-running incurs external API re-billing or duplicate processing, is that stated along with how to avoid it
- **Counterexamples to quantifiers**: for each universal claim ("only", "always", "must", "unconditionally"), look for one counterexample path (`~/.claude/rules/verify-before-assert.md`)

### dependency — skip: dependency file (go.mod / go.sum / package.json / lock files / import lines) diff 0
- **New dependency detection**: enumerate additions. **New dependencies require user approval** (CLAUDE.md conduct principles). In loop-mode, detection = immediate escalation
- Is the version bump intentional (flag out-of-instruction lock file churn) / typosquat or install-script-bearing package / bloat in transitive dependencies / licence conflicts

### code-quality — skip: code diff 0
Not bug detection but the "better way to write it" perspective.
- **Duplication / reuse**: grep for an equivalent helper / util already in the repo. Is the same shape of processing written in 2+ places
- **Simplification**: unnecessary intermediate variables / deep nesting (flatten with early returns) / over-abstraction (an interface with a single implementation)
- **Naming / altitude**: does the name match the behavior, consistent with the repo's existing vocabulary. Is the abstraction level uniform within a function
- **Comments**: self-evident "what it does" comments and PR-facing explanatory comments are removal targets. Write only "constraints that can't be expressed in code"
- **Constants**: are magic numbers in expressions / identical literals appearing 2+ times extracted into named consts. Are related constants grouped in a const block
- **Consistency within the PR**: re-grep the diff for the naming / consts / helpers you introduced to catch the "only one side got a named const" kind of omission
- `go-style` / `go-test` / `ddd-clean-architecture` are the SoT for convention details

## Mechanical checks (reinforcing correctness — run these with grep)

1. **Symmetry audit**: for each guard / validation / nil check added in the diff, confirm the symmetric counterparts have the same guard (enumerate all constructors in the PR with `grep "^func New" $(git diff --name-only)`, and also grep functions taking `opts ...Option`). This kills the class of omission where you fix one site and miss the others
2. **Interface contract trace**: re-read the godoc of external interfaces used in changed files, and confirm the sentinel return cases (0 / "" / nil / -1 / a specific error) line up with the consumer's branching (`if x <= X`, `errors.Is(...)`). Example: `CountTokens` returns 0 on encoding error → the consumer's `tokens <= MaxTokens` misjudges it as "fits"
3. **Doc last-write-wins**: after an implementation change, grep the changed files for strong claims (`grep -nE "(strictly|preserves|guarantees|ensures|always|never|returns|panics)"`) and cross-check each claim against the implementation's literal behavior at byte level (is "strictly under X" a `<` or a `<=`, etc.). Resolve divergence by matching the doc to the implementation, or the implementation to the doc based on design intent
4. **Authoritative verification of external constants**: when the diff contains externally-sourced hardcoded constants (LLM pricing / model IDs / API rate limits), **verify the number itself against an authoritative source**. "Byte-identical to where it was ported from" is not evidence of correctness. The `claude-api` skill is the SoT for Anthropic pricing / model IDs

## Identifying false positives

Patterns you may resolve as "not applicable in this project context":
- Go 1.22+ loop variable shadowing (unnecessary if the `go.mod` go directive is 1.22+)
- Re-proposal of an internal port boundary defense already withdrawn as an SD (resolve by referencing the PR description)
- Duplicate posting of the same warning (when the pattern doesn't apply to the other test)

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

1. **Always output the execution status of every perspective as a table**: no silent skipping. Skips require a mechanical condition + a reason
2. **List every finding first, then classify into the 3 tiers — don't pre-filter by severity** (an "only the serious ones" filter reduces the reporting itself)
3. **Read the related memory entries in full**: don't judge from the index line alone
4. **Don't hide anything**: point out problems even in something you created in the immediately preceding turn
