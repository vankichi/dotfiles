---
name: improve-harness
description: The apply side of the knowledge loop — aggregates unprocessed insights across all projects, then reconciles against current state → decides where to apply (memory → rules → skill → agent) → implements the improvement → all the way to a draft improvement PR against dotfiles. Use for "improve-harness して" ("run improve-harness"), "harness 改善して" ("improve the harness"), "insights 集約して" ("aggregate the insights"), etc. Makes no design decisions (undecided items go back to a human as a decisions-needed list). The collection side is retrospect (its paired skill).
---

> **Source of truth:** `claude/ja/skills/improve-harness/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# improve-harness

The apply side of the knowledge loop. Aggregates the insights retrospect accumulated and ships improvements to the harness (skills / agents / rules / CLAUDE.md) as a draft PR. **Makes no design decisions** — proposals that list multiple options or are undecided are returned to a human rather than implemented.

The target harness repo is dotfiles (work against dotfiles even when cwd is elsewhere). Manual invocation only.

## Procedure

### Step 0: Inspect the live harness for drift

The live harness (`~/.claude/{skills,agents,rules}`) is a symlink into the dotfiles working tree, so **the checked-out branch is the harness**. After `git -C <dotfiles> fetch origin`, run the following and **report to a human before proposing improvements** if there is drift (processing insights while drifted re-discovers and re-applies problems already solved on master):

```bash
git rev-list --left-right --count origin/master...HEAD
git diff --stat origin/master HEAD -- claude/
```

### Step 1: Collect

Enumerate `~/.claude/projects/*/insights/*.md` across all projects. Files whose frontmatter has `status:` are already processed and excluded (unprocessed = no `status`). If there are 0 unprocessed, state "none applicable" and end normally.

### Step 2: Routing (mechanical decision)

Route by the frontmatter's `target`:

| target | Handling |
|---|---|
| Inside the harness (under `claude/` / `CLAUDE.md` / `rules/`) | An improvement target → Step 3 |
| Outside the harness (files in other repos / Claude Code's own behavior / design docs, plans) | Not included in the PR. Those that memory alone covers (facts / environment quirks / alternative recipes) go through the Step 3 reconciliation to the Step 4 memory application. The rest go to the "out-of-scope report" with a one-line suggestion for the target project, marked `status: deferred` (reason: out-of-scope) |

### Step 3: Reconcile against current state

Read the **current** content of each insight's target file and judge whether the proposal is already reflected (manual pre-application happens). If it is, add `status: applied` and exclude it. **Never skip this reconciliation and produce a diff anyway** (it prevents duplicate application and reversal of existing wording).

### Step 4: Clustering + deciding where to apply

Group related insights into one improvement unit (cluster). Decide the destination by the criteria in `references/promotion.md`, following the **promotion order memory → rules → skill → agent** and favoring the cheaper-to-change side (an insight with an explicit `target` follows that).

**Memory application needs no PR**: write directly to the target project's memory and just report it. Insights completed this way get `status: applied` (noting the memory it went to).

**`~/.claude/rules/memory.md` ("Rules for the writing side") is the SoT for how to write** — leave provenance (the record date, the filename of the insight it came from), write only measured values, and never place secrets there. **This is an unreviewed write path, so what was applied must always appear in the report.**

### Step 5: Implement the improvement

- **Work in a worktree** (`git worktree add -b <branch> <path> <base>`). **Never switch the main checkout's branch** — the live harness is a symlink into the main checkout's working tree, so switching changes the behavior of every running session. After merge, `git pull` in the main checkout to catch up
- Edit the ja SoT (`claude/ja/...`) → delegate translating the en mirror (`claude/...`) to an opus subagent. Files with no mirror (`rules/` / `CLAUDE.md`) are edited once
- Proposals that are undecided or need user judgment (multiple options, intervention in the status scheme, external accounts, permission expansion) are not implemented — mark `status: deferred` with a reason and put them on the decisions-needed list

### Step 6: Ship (draft PR)

Call `commit-push-branch` with **loop-mode explicitly stated** (create branch + commit per cluster + push + draft PR). The PR body is an "insight (filename) ↔ change" mapping table plus the decisions-needed list. Basis: the exception in CLAUDE.md's "loop-mode".

### Step 7: Update state + report

Insights included in the PR get `status: proposed` + `pr: <URL>`. **Add the status immediately after the cluster's commit, without waiting for the PR** (`pr:` is filled in afterwards) — so that on interruption "how far did it get applied" is traceable independently of the commits.

**Force-output a disposition table for every insight** (no silent skipping):

```
## improve-harness results

| insight | Disposition | Destination / reason |
|---|---|---|
| 20260714-work-intake-skip-idempotency.md | proposed | work-intake references (PR #NN) |
| 20260713-ready-flag-dual-representation.md | applied | confirmed already reflected (rules/spec-contract.md) |
| 20260714-atlas-migrate-lint-pro-gated.md | deferred | out of scope (another repo). Suggested ticketing it in that project |

## Decisions needed (for a human)
- <summary of the undecided proposal + what needs deciding>
```

## status lifecycle (insight frontmatter)

| status | Meaning |
|---|---|
| (none) | Unprocessed |
| `applied` | Confirmed already reflected, or completed via memory application (noting the destination for memory) |
| `proposed` | Included in an improvement draft PR (with `pr:`) |
| `deferred` | Needs a decision / out of scope / assigned elsewhere (with `reason:`) |

## Resuming from an interruption

Don't start over — identify the incomplete step and continue. Use only these two progress signals:

1. **The commit list from `git log origin/<default-branch>..HEAD`** = applied clusters. **Don't measure against the local default branch** — when stale it picks up already-merged commits and overstates progress (always count against `origin/` after a `git fetch`)
2. **The `status` in insight frontmatter** = whether processed marks exist. If none carry one, Step 7 never ran

Reuse the working branch (and worktree) if they survive, identify the unapplied insights from the two signals above, and continue from Step 5. Never squash or rewrite pushed commits — stack on top (force push is forbidden). If a draft PR already exists, amend its body instead of creating a new one.

## On failure

If dotfiles has unrelated uncommitted changes, leave them alone and keep them out of the improvement commit (explicit add). If push / draft PR creation is denied, preserve the work through the local commit, report the branch name, and stop. If a memory write is denied, mark that insight `status: deferred` (reason: write denied) and move it to the decisions-needed list.

Aggregating session JSONL (perspective-skip tendencies / token consumption) happens only on the user's explicit request (using the `claude-session-jsonl` recipes). The default input is insights only.

## Iron rules

1. **Force-output every insight's disposition as a table** — no silent skipping
2. **Stop at the draft PR** — no merge / promotion / direct push to master
3. **Make no design decisions** — multiple options and undecided items are deferred to a human
4. **Never write internal information into a PUBLIC repo's PR** — don't transcribe internal URLs / ticket bodies; reference insights by filename
5. **Never rewrite the body of an insight** — only append status to its frontmatter
6. **Never skip the reconciliation** — don't produce a diff from an already-reflected insight
