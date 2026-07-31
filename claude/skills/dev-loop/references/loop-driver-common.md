> **Source of truth:** `claude/ja/skills/dev-loop/references/loop-driver-common.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# Common provisions for loop drivers (dev-loop / review-loop / pr-follow-loop)

Provisions shared by the 3 driver skills run via /loop. Each skill references this file and does not restate it in its own body. **The loop's lifecycle is managed by the user's /loop operation; a skill only defines the internals of one tick.**

## Time

- At the head of the tick, run `date '+%Y-%m-%d %H:%M %Z'` to get the current local time (for the tick report). Never guess the time

## The 3 notification categories (always recorded in the tick report)

| Category | Meaning | Handling |
|---|---|---|
| sent | `PushNotification` was issued | normal |
| skipped (terminal active) | the tool deliberately suppressed it because the user is active at the terminal | **normal** (notifications are only delivered when unattended, by design) |
| not delivered | tool unavailable / error | **abnormal** — report it; never stay silent |

Notifications and completion reports happen **only after mechanically confirming that the receipts (PR URL / comment URL / removal confirmation, etc.) actually exist**. Do not forward a subagent's self-report as-is.

## Baseline values for self-pacing (`ScheduleWakeup`)

| Situation | Next wakeup |
|---|---|
| advanced one step (drain — consume the next right away) | 60-120s |
| none applicable (idle) | 1200-1800s |
| retry after an error | 900s |
| waiting for a running external process to finish | 300s |

Skill-specific rows (Notion unreachable, etc.) are written only on the skill's own side.

## The 3-consecutive breaker

If failures (escalation / error) occur **3 consecutive** times, stop `ScheduleWakeup` and terminate **after notifying** "loop stopped (3 consecutive)" (never stop silently). The count resets on a success. Only the user's /loop operation decides a permanent stop.

## tick report

Every tick, **output all items of the report template without omission**. Common fields: time (+ previous tick's time) / poll result / action + receipts / notification category / consecutive count n/3 / next wakeup seconds (~HH:MM, reason).
