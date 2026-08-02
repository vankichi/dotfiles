---
name: retrospect
description: Lightweight skill for recording one insight at the end of a dev cycle / work session — a sticking point, a redo, or a newly discovered convention or environment quirk. Use for "retrospect して" ("do a retrospective"), "振り返り記録して" ("record a retrospective"), etc. Does not analyze, aggregate, or turn findings into improvement PRs (that's improve-harness's responsibility).
when_to_use: At the end of a cycle or work session, when there were sticking points, redos, or newly discovered conventions. 「retrospect して」「振り返り記録して」. Write nothing when there is nothing to record.
---

> **Source of truth:** `claude/ja/skills/retrospect/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# retrospect

Lightweight recording at the end of a cycle. **Keep it to a granularity you can write in one minute.** Analysis, aggregation, and turning findings into improvement PRs are improve-harness's responsibility; this skill only records.

## Procedure

### Step 1: Gather key points

Identify the following from the preceding cycle / work (if none apply, it's fine to finish without recording anything):

- Sticking points / things that had to be redone
- Corrections or feedback from the user
- Newly discovered conventions or environment quirks
- Deficiencies or gaps in skills / agents / rules

### Step 2: Determine the category

| category | meaning |
|---|---|
| skill-gap | a gap or defect in a skill's procedure or perspectives |
| rule-gap | a gap or ambiguity in CLAUDE.md / rules/ |
| env-quirk | an environment / tool quirk (reproducible behavior) |
| spec-gap | a deficiency in the spec contract or spec content |

Before categorizing something as skill-gap / rule-gap, **check the file in question on the master side** (`git -C <dotfiles> diff origin/master -- <file>`). Because the live harness is a symlink into the dotfiles working tree, rule out the possibility that the live copy had drifted from master (i.e. the convention already existed on master) before categorizing it as a skill / rule defect.

### Step 3: Record it in an insights file

Write **one insight per file** in the per-project dir for the target project. **"Target project" = the project the feedback's target file belongs to** (not necessarily the repo the cycle ran in; feedback about the harness goes to the dotfiles side):

- path: `~/.claude/projects/<encoded>/insights/<YYYYMMDD>-<slug>.md`
- `<encoded>` = the target project's absolute path with `/` and `.` replaced by `-` (same convention as "Where to store plan / session state files" in CLAUDE.md)

```markdown
---
date: <YYYY-MM-DD>
category: skill-gap | rule-gap | env-quirk | spec-gap
ticket: <ticket URL / id / none>
target: <the relevant skill / agent / rules file, if any>
---

## What happened

<1-3 lines describing what happened>

## Proposal

<1-3 lines on how it should be fixed (write "undecided" if unclear)>
```

## Iron rules

1. Recording only. Do not analyze, fix, or turn it into a PR
2. One insight = one file. Do not batch multiple into one write
3. Do not transcribe secrets or the full ticket body (reference by id / URL only)
4. Do not force a write when a cycle has nothing to report (don't accumulate noise)
