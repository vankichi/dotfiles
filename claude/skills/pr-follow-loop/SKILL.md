---
name: pr-follow-loop
description: Driver skill run via /loop that shepherds the open PRs I authored. 1 tick = poll my open PRs → advance one PR by one step (triage-and-present bot review findings / watch for human approval / auto-clean up after merge) → notify → ScheduleWakeup to self-pace. Use for 「pr-follow-loop の tick を実行して」("run the pr-follow-loop tick"), 「PR 見届け loop 回して」("run the PR follow loop"), etc. (normally via /loop). Sibling of dev-loop (produces PRs) and review-loop (reviews others' PRs); this skill follows the PRs I produced through the rest of their life.
when_to_use: When shepherding my own open PRs via /loop. 「pr-follow-loop の tick を実行して」「PR 見届け loop 回して」.
disallowed-tools: AskUserQuestion
---

> **Source of truth:** `claude/ja/skills/pr-follow-loop/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# pr-follow-loop

The driver for shepherding PRs (sibling of dev-loop / review-loop). 1 tick = 1 poll + at most one step on one PR. **`~/.claude/skills/dev-loop/references/loop-driver-common.md` is the SoT for the common provisions — getting the time, the 3 notification categories, the wakeup baseline values, the 3-consecutive breaker, and the tick report** — not restated in this body.

The three siblings:
- **dev-loop** = I **produce** PRs (work-intake → dev-cycle → draft PR)
- **review-loop** = I **review others'** PRs (review-requested:@me → neutral comment)
- **pr-follow-loop** (this skill) = I **shepherd my own** PRs (handle bot findings after open → wait for approval → clean up after merge)

## Applicability conditions

- Startup from /loop (dynamic pacing) is assumed (a single manual tick is also fine)
- A local session with the target repo's cwd / `gh` authenticated
- **Do not hardcode configuration**: the bot reviewers to triage (e.g. CodeRabbit) / the required human reviewer(s) that gate merge / the target repo are obtained from the project's reference memory (MEMORY.md). If not registered, state "reference memory not registered", confirm with the user, register it, and continue. Never bake repo names / bot names / member names into the skill

## Procedure (1 tick)

### Step 1: precondition check

- Must be inside a git repo / `gh auth status` must pass

### Step 2: poll (mechanical)

```bash
gh pr list --author @me --state open \
  --json number,headRefOid,title,isDraft,url,createdAt
```

- The target is **open PRs I authored** (drafts included). Stages a / b advance from this list
- Merged PRs do not appear under `--state open`, so the trigger for cleanup (stage c) is held separately: **enumerate local worktrees under `.claude/worktrees/` and cross-check whether each one's branch has a merged PR** via `gh pr list --author @me --state merged` / `gh pr view <branch>` (stateless — no cross-tick state)
- If there are neither open PRs nor merged-but-still-present worktrees, go to Step 4 (idle)

### Step 3: stage detection and one step (idempotency marker `<!-- pr-follow: <head-sha> -->`)

Select one PR from the poll (oldest created first) and, based on its current stage, advance it by **exactly one step**:

#### a. New bot findings (un-triaged bot review on the current head sha)

- Fetch the bot reviewer's reviews / inline comments and **assess each finding against the repo conventions (`.claude/rules/`)**: valid (recommend fix) / false-positive / convention-conflict or YAGNI (recommend decline), each with a severity and a one-line reason
- **Present the triage summary (each finding → verdict + reason + recommended action) and notify the user.** Record the marker to treat this head sha as triaged
- **The loop stops here**: applying fixes (commit+push) / posting decline replies happen **after the user approves, in dialogue** (the loop never fixes / declines on its own). Design judgments / convention conflicts are always surfaced as escalation
- If the assessment needs fresh context at scale, `reviewer` may be spawned as a subagent (but this skill's role ends at presenting the triage — it does not apply anything)

#### b. Awaiting approval (no un-triaged findings; required reviewer has not approved)

- For near-real-time notification, arm a Monitor that watches the PR's review verdict (APPROVED / CHANGES_REQUESTED) (do not double-arm if one already runs — check via TaskList)
- On a detected verdict, notify via `PushNotification` (catch CHANGES_REQUESTED as well as APPROVED — do not sit in silence)

#### c. Merged (a worktree under `.claude/worktrees/` whose PR is MERGED)

- The trigger comes from the Step 2 cross-check: a local worktree that still exists while its corresponding PR is already merged
- **Auto-cleanup** (report after the fact):
  1. Confirm the target worktree's `git status --porcelain` is empty (clean). **If dirty, do not clean up — escalate** (to avoid losing uncommitted changes)
  2. If clean, `git worktree remove <path>` + **delete the merged local branch** (`git branch -d`. `-D` and the `--force` family are left to human execution)
  3. **Do not touch the remote branch or other worktrees** (leave remote deletion to GitHub's auto-delete on merge; deleting the remote is an outward action outside this skill's scope)
- **If a cleanup command is denied by the permission classifier, do not work around it**: compound commands containing `--force`, and `git branch -D`, can be denied. On a deny, abort the remaining cleanup and **present the unexecuted commands to the human as-is and finish**. State "not executed due to deny" in the receipts (never report "cleanup complete" for something whose removal could not be mechanically confirmed)
  - Whether to add the minimum permissions needed for cleanup (`Bash(git worktree remove:*)` / `Bash(git branch -d:*)`, etc.) to settings is **a human decision**. The skill never rewrites settings itself
- Notify the cleanup result (receipts: mechanically confirm the worktree is gone from `git worktree list` and the branch is gone from the branch list)

### Step 4: self-pacing (`ScheduleWakeup`)

- The baseline values come from loop-driver-common (advanced one step → drain / none applicable → idle / error → 900s)
- Skill-specific: moved to awaiting-approval → 1200-1800s (Monitor is the primary signal; the wakeup is the fallback heartbeat)
- The breaker's target = tick errors. It resets on a success

### Step 5: tick report (forced output)

```
## pr-follow-loop tick report
- time: <current local time> — previous tick: <time from previous report / unknown>
- poll: <N> PRs (mine, open)
- action: [none / PR #<n> <stage: bot-triage presented / approve-watch armed / cleanup done>] — receipts: <triage notification / Monitor task id / post-cleanup worktree+branch removal confirmation>
- notification: [sent / skipped (terminal active — normal) / not delivered / n/a]
- error streak: <n>/3
- next wakeup: <seconds> (~<HH:MM> / <reason>)
```

## Iron rules

1. **Approve / request-changes / merge are the human's only** — the loop never operates GitHub's review state
2. **Bot findings go only as far as presenting the triage** — applying fixes / posting decline replies happen after the user approves, in dialogue. The loop never fixes / declines on its own
3. **Cleanup requires a clean check** — a dirty worktree is not cleaned; escalate instead. Cleanup targets are the own worktree + the merged local branch only (remote / other worktrees are left untouched). A denied cleanup command is presented to the human, not worked around
4. **Do not hardcode configuration** — bot names / required reviewers / repo come from the reference memory
5. **Do not loosen the safety devices** — hooks / permission deny / least privilege are never relaxed in the loop
6. **Follow loop-driver-common for the common provisions** (receipts verification / breaker / tick report / stop authority)
