---
name: improve-harness
description: The apply side of the knowledge loop — aggregates unprocessed insights across all projects, then reconciles against current state → decides where to apply (memory → rules → skill → agent) → implements the improvement → all the way to a draft improvement PR against dotfiles. Use for "improve-harness して" ("run improve-harness"), "harness 改善して" ("improve the harness"), "insights 集約して" ("aggregate the insights"), etc. Makes no design decisions (undecided items go back to a human as a decisions-needed list). The collection side is retrospect (its paired skill).
---

> **Source of truth:** `claude/ja/skills/improve-harness/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# improve-harness

The apply side of the knowledge loop. Aggregates the insights retrospect has accumulated and ships harness (skills / agents / rules / CLAUDE.md) improvements as a draft PR.
**Makes no design decisions** — proposals that list multiple options or are undecided are not implemented; they go back to a human.

## Applicability

- Manual launch (scheduling comes in SP4 and later)
- Target harness repo = dotfiles. If cwd is not dotfiles, work against dotfiles as the target

## Procedure

### Step 1: Collect

- Enumerate `~/.claude/projects/*/insights/*.md` across all projects
- Files whose frontmatter has `status:` are already processed and excluded (unprocessed = no `status`)
- If there are 0 unprocessed, state "none applicable" explicitly and exit normally

### Step 2: Routing (mechanical decision)

Sort by the `target` in the frontmatter:

| target | handling |
|---|---|
| inside the harness (`claude/` subtree / `CLAUDE.md` / `rules/`) | improvement target → proceed to Step 3 |
| outside the harness (files in other repos / Claude Code's own behavior / design docs / plans) | not included in the PR. Items sufficiently handled as memory (facts / environment quirks / alternative recipes) are routed through Step 3's reconciliation (check the current state of the target project's memory; if already registered, exclude with `status: applied`) before Step 4's memory application. Everything else is routed to the "out-of-scope report", with a one-line proposal for handling it on the target project's side attached, and set to `status: deferred` (reason: out-of-scope) |

### Step 3: Reconcile against current state

- Read the **current state** of each insight's target file and decide whether the proposal is already applied (manual pre-application is possible)
- Already applied → add `status: applied` to the frontmatter and exclude it
- Do not skip this reconciliation and produce a diff anyway (prevents duplicate application and regressions against existing text)

### Step 4: Clustering + deciding where to apply

- Group related insights into a single improvement unit (cluster)
- Decide where to apply using the criteria in `references/promotion.md`. Following the **promotion order memory → rules → skill → agent**, fall to the side with the smaller change cost
- An insight with an explicit `target` follows it (promotion decision applies only when the target is unclear or the pattern is cross-cutting)
- **Applying to memory needs no PR**: write directly to the target project's memory and just report it. An insight fully resolved by memory application gets `status: applied` (note the target memory alongside)

### Step 5: Implement the improvement

- Edit the ja SoT (`claude/ja/...`) → delegate the en mirror (`claude/...`) translation to an opus subagent (docs = opus convention). Files with no mirror (`rules/` / `CLAUDE.md`) are edited in a single place
- If the proposal is undecided / requires user judgment (multiple options listed / intervention in the status scheme / external accounts / privilege escalation, etc.) → do not implement; set `status: deferred` (with reason) and add it to the "decisions-needed list"

### Step 6: Ship (draft PR)

- Call the `commit-push-branch` skill **with loop-mode explicitly set**: create the branch + one commit per cluster + push + create a draft PR
- PR body: a mapping table of insight (file name) ↔ change + the decisions-needed list
- Basis: the exception clause in CLAUDE.md "loop-mode" (improve-harness's harness-improvement draft PR)

### Step 7: Update state + report

- Insights included in the PR: add `status: proposed` + `pr: <URL>` to the frontmatter
- **Force-output a disposition table for every insight** (no silent skips):

```
## improve-harness results

| insight | disposition | applied to / reason |
|---|---|---|
| 20260714-work-intake-skip-idempotency.md | proposed | work-intake references (PR #NN) |
| 20260713-ready-flag-dual-representation.md | applied | confirmed already applied (rules/spec-contract.md) |
| 20260714-atlas-migrate-lint-pro-gated.md | deferred | out-of-scope (other repo). Proposed ticketing it on the target project's side |

## Decisions needed (for a human)
- <summary of the undecided proposal + the point you want decided>
```

## status lifecycle (insight frontmatter)

| status | meaning |
|---|---|
| (none) | unprocessed |
| `applied` | confirmed already applied by reconciliation, or fully resolved by memory application (no PR; for memory, note the target memory alongside) |
| `proposed` | included in an improvement draft PR (`pr:` alongside) |
| `deferred` | decision-needed / out-of-scope / assigned to separate work (`reason:` alongside) |

## Auxiliary input (optional)

Session JSONL aggregation (perspective-skip tendencies / token consumption, etc.) is done only when the user explicitly requests it (use the recipe in the `claude-session-jsonl` skill). The default input is insights only.

## On failure

- If dotfiles has unrelated uncommitted changes: leave them untouched and do not include them in the improvement commit (explicit add — commit-push-branch's convention)
- If push / draft PR creation is denied: preserve up to the local commit, report the branch name, and stop
- If a memory write is denied: set that insight to `status: deferred` (reason: write denied) and route it to the decisions-needed list

## Iron rules

1. **Force-output the disposition of every insight in a table** — no silent skips
2. **Only up to a draft PR** — do not merge / promote out of draft / push directly to master
3. **Make no design decisions** — multiple options / undecided go to a human as deferred
4. **Do not write internal information into the PR of a PUBLIC repo** — do not transcribe internal URLs / ticket bodies. Reference insights by file name
5. **Do not rewrite the body of the original insights** — only append status to the frontmatter (the body is retrospect's artifact)
6. **Do not skip reconciliation against current state** — do not produce a diff from an already-applied insight
