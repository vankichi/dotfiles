---
name: dev-loop
description: Driver skill for the dev loop run via /loop. 1 tick = work-intake poll → (if there is a work item) run dev-cycle serially → completion with verified receipts / escalation notification → ScheduleWakeup to self-pace the next tick. Use for 「dev-loop の tick を実行して」("run the dev-loop tick"), 「dev loop 回して」("run the dev loop"), etc. (normally via /loop). The cycle's internals are the dev-cycle SoT — this skill only drives.
disallowed-tools: AskUserQuestion
---

> **Source of truth:** `claude/ja/skills/dev-loop/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# dev-loop

The dev loop's driver. 1 tick = 1 poll + at most 1 cycle. **`references/loop-driver-common.md` is the SoT for the common provisions — getting the time, the 3 notification categories, the wakeup baseline values, the 3-consecutive breaker, and the tick report** — not restated in this body.

## Applicability conditions

- Startup from /loop (dynamic pacing) is assumed (a single manual tick is also fine)
- A local session where the target repo's cwd / Notion MCP is available (headless is not possible due to interactive auth)

## Procedure (1 tick)

### Step 1: Precondition check

- Must be inside a git repo
- **Serial guard**: check the state files in the per-project plans dir, and ensure no active cycle exists (a state file whose Current state does not indicate all-stages-complete / escalation stop). If one exists, this tick does not start a cycle and goes to Step 5 (300s wakeup — waiting for the running cycle to finish)
- Leave Notion reachability to work-intake (if unreachable, Step 2 terminates abnormally → notify "Notion unreachable" and 1800s wakeup)

### Step 2: poll (`work-intake`)

- Start the `work-intake` skill
- None applicable (0 work items) → Step 5 (idle interval)
- If a work item is returned, go to Step 3

### Step 3: cycle (run `dev-cycle` serially)

- **Spawn `dev-cycle` with the normal Agent tool — do not use teams** (under a flat roster, nested spawn is not possible, so the two-level nesting `dev-cycle` → `reviewer` → `independent-reviewer` cannot form)
- **Synchronous startup (`run_in_background: false`)** — wait until completion. At most 1 cycle per tick; do not start in parallel
- Pass the full work item text in the prompt (dev-cycle judges it as loop-mode)
- **Check your own cwd after the cycle completes**: when the dev-cycle subagent calls `EnterWorktree`, the caller's (this skill's) shell cwd is also moved under the worktree and pinned there (`cd`-ing back gets reverted with `Shell cwd was reset to ...`). If cwd is under the worktree, return via `ExitWorktree(action: keep)` — **the worktree stays, so this is a cwd return, not cleanup**. This keeps subsequent polls / notifications from resolving paths (the per-project plans dir, etc.) on the worktree side

### Step 4: Notification (after verifying the receipts actually exist)

Take the receipts from dev-cycle's report, and **notify via `PushNotification` only after mechanically confirming they actually exist**:

| Result | Verification | Notification |
|---|---|---|
| Completed | Confirm the PR URL with `gh pr view` | 「<ticket-id>: draft PR <URL>」 |
| escalation | Confirm the ticket comment / WIP branch (`git ls-remote`) | 「<ticket-id>: escalation (<one-line stop reason>)」 |
| receipts do not actually exist | — | 「<ticket-id>: detected a divergence between report and reality」 + counted as escalation |

### Step 5: self-pacing (`ScheduleWakeup`)

- The baseline values come from loop-driver-common (completed → drain / empty queue → idle / serial guard hit → 300s)
- Skill-specific: escalation → 1200-1800s (the target ticket is InProgress and won't be re-picked) / Notion unreachable → 1800s (waiting for recovery)
- The breaker's target = escalation (including divergence detection). It resets on a cycle completion

### Step 6: tick report (forced output)

```
## dev-loop tick report
- time: <current local time> — previous tick: <time from previous report / unknown>
- poll: [none applicable / selected <ticket-id>]
- cycle: [not run / completed (PR <URL>) / escalation (<reason>)] — receipts: <verified list>
- escalation streak: <n>/3
- notification: [sent / skipped (terminal active — normal) / not delivered / n/a]
- next wakeup: <seconds> (~<HH:MM> / <reason>)
```

## Iron rules

1. **Do not start parallel cycles** — do not skip the serial guard
2. **Do not stop the loop on escalation** — the only exception is the 3-consecutive breaker
3. **Follow loop-driver-common for the common provisions** (receipts verification / breaker / tick report / stop authority)
