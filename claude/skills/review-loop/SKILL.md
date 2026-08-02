---
name: review-loop
description: Driver skill for PR review run via /loop. 1 tick = poll open PRs where I'm assigned as reviewer → select one un-reviewed head sha → integrating review via reviewer → post findings as a neutral comment (does not approve / merge) → notify → ScheduleWakeup to self-pace. Use for 「review-loop の tick を実行して」("run the review-loop tick"), 「review loop 回して」("run the review loop"), etc. (normally via /loop). The review's substance is the reviewer's SoT — this skill only drives.
when_to_use: When working through PRs where I am assigned as reviewer, via /loop. 「review-loop の tick を実行して」「review loop 回して」.
disallowed-tools: AskUserQuestion
---

> **Source of truth:** `claude/ja/skills/review-loop/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# review-loop

The driver for PR review (dev-loop's sibling). 1 tick = 1 poll + at most 1 review. **`~/.claude/skills/dev-loop/references/loop-driver-common.md` is the SoT for the common provisions — getting the time, the 3 notification categories, the wakeup baseline values, the 3-consecutive breaker, and the tick report** — not restated in this body.

## Applicability conditions

- Startup from /loop (dynamic pacing) is assumed (a single manual tick is also fine)
- A local session with the target repo's cwd / `gh` authenticated

## Procedure (1 tick)

### Step 1: Precondition check

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

### Step 4: integrating review (`reviewer`)

- **Spawn `reviewer` synchronously with the normal Agent tool** (do not use teams)
- What to pass: the PR's diff range (base..head) / spec = **PR body + the ticket it references in the body (if any)** / the path list of repo conventions / design docs (glob CLAUDE.md / rules / lint configs / design documents under docs) / a simple impact classification (classify from `gh pr diff <n> --stat` plus the diff body, following the "simplified judgment" in `~/.claude/rules/impact-scope.md`. For impact-C, mark correctness / test-adversarial as priorities)
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

- **Notify on every review completion**: `PushNotification` "PR #<n> review complete: <verdict>"
- The wakeup follows loop-driver-common's baseline values (review completed → drain / none applicable → idle / error → 900s). The breaker's target = review failures, resetting on a success

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
3. **Do not transcribe the PR body / code verbatim into the comment**
4. **Follow loop-driver-common for the common provisions** (receipts verification / breaker / tick report / stop authority)
