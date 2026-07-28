---
name: review-loop
description: Driver skill for PR review run via /loop. 1 tick = poll open PRs where I'm assigned as reviewer → select one un-reviewed head sha → integrating review via review-orchestrator → post findings as a neutral comment (does not approve / merge) → notify → ScheduleWakeup to self-pace. Use for 「review-loop の tick を実行して」("run the review-loop tick"), 「review loop 回して」("run the review loop"), etc. (normally via /loop). The review's substance is the review-orchestrator's SoT — this skill only drives.
---

> **Source of truth:** `claude/ja/skills/review-loop/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# review-loop

The driver for PR review (dev-loop's sibling). **The loop's lifecycle is managed by the user's /loop operation; this skill defines the internals of one tick.** 1 tick = 1 poll + at most 1 review.

## Applicability conditions

- Startup from /loop (dynamic pacing) is assumed (a single manual tick is also fine)
- A local session with the target repo's cwd / `gh` authenticated

## Procedure (1 tick)

### Step 1: Precondition check

- Run `date '+%Y-%m-%d %H:%M %Z'` to get the current local time — for the tick report; never guess the time
- Must be inside a git repo / `gh auth status` must pass

### Step 2: poll (mechanical)

```bash
gh pr list --state open --search "review-requested:@me" \
  --json number,headRefOid,title,isDraft,url,createdAt
```

- The target is **open PRs where a review request has come to me** (drafts included). If 0, go to Step 6 (idle)

### Step 3: idempotency filter (mechanical)

- Check each PR's comments and look for this skill's marker **`<!-- review-loop: <head-sha> -->`**
- **Skip any PR whose current head sha (`headRefOid`) matches the marker** — re-review only when a new push changes the sha
- Select **one** PR from the un-reviewed ones (oldest created first). If all are skipped, go to Step 6 (idle)

### Step 4: integrating review (`review-orchestrator`)

- **Spawn `review-orchestrator` synchronously with the normal Agent tool** (do not use teams — under a flat roster the fan-out degrades)
- What to pass: the PR's diff range (base..head) / spec = **PR body + the ticket it references in the body (if any)** / the path list of repo conventions / design docs (glob CLAUDE.md / rules / lint configs / design documents under docs) / a simple impact classification (from `gh pr diff <n> --stat`: new files only = impact-A, changes to existing files = treated as impact-C, so mark correctness / test-adversarial as priorities)
- Do not pass anything equivalent to a state file (standalone review — do not give it implementation context)

### Step 5: comment posting (through receipts verification)

- Format the verdict + findings table + perspective completion status into a single comment, and post it with the **marker at the top**:

```bash
gh pr comment <number> --body '<!-- review-loop: <head-sha> -->
## Integrating review (review-loop)
verdict: <approve / approve-with-notes / fix-required / escalation>
<findings table / perspective completion status / overall assessment>'
```

- After posting, fetch the comment URL and **confirm it actually exists as a receipt**
- **Do not use approve / request-changes / merge / GitHub's review state** — neutral comment only (the merge decision is the human's)
- Do not include secrets / internal URLs / verbatim transcription of code in the comment (findings are file:line references)

### Step 6: notification + self-pacing

- **Notify on every review completion**: `PushNotification` "PR #<n> review complete: <verdict>". The outcome is recorded in the tick report in 3 categories — sent / **skipped (terminal active — normal, delivered only when unattended)** / not delivered (abnormal)

| Immediately preceding result | Next wakeup (`ScheduleWakeup`) | Reason |
|---|---|---|
| review completed | 60-120s | drain — consume the next un-reviewed PR right away |
| none applicable (0 or all skipped) | 1200-1800s | idle (20-30 min) |
| review error | 900s | retry interval |

- **Consecutive error breaker**: if a review fails **3 consecutive** times, stop the wakeup, notify "loop stopped (3 consecutive review failures)", and terminate. Resets on a success

### Step 7: tick report (forced output)

```
## review-loop tick report
- time: <current local time> — previous tick: <time from previous report / unknown>
- poll: <N> targets (of which <M> skipped as already reviewed)
- review: [none / PR #<n> <verdict>] — receipts: <comment URL>
- notification: [sent / skipped (terminal active — normal) / not delivered / n/a]
- error streak: <n>/3
- next wakeup: <seconds> (~<HH:MM> / <reason>)
```

## Iron rules

1. **Do not approve / request-changes / merge** — neutral comment only
2. **Do not re-comment on the same head sha** — do not skip the marker check (Step 3)
3. **Notify / report only after verifying the receipts (comment URL) actually exist** — do not claim "posted" on self-report
4. **Do not transcribe the PR body / code verbatim into the comment**
5. **Do not omit the tick report** — output all items every tick
