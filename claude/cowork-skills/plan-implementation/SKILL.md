---
name: plan-implementation
description: Turns a settled spec into an implementation plan: layer placement, PR split, junior-followable steps with pitfalls and local verification. Working tree only. 「実装計画にして」「PR 分割して」
---

> **Source of truth:** `claude/ja/cowork-skills/plan-implementation/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# plan-implementation

Turns a settled spec into a plan an implementer can start on without hesitating.

**Doesn't implement.** Doesn't change the spec's design decisions either (on finding a contradiction, report it and stop).

## Trigger

Default-on. If skipping, output the reason.

- Requests like 「実装計画にして」「PR 分割して」「着手手順を出して」
- A spec the human has declared accepted is in the input

If an unsettled spec arrives, don't run this skill — point at `harden-spec` first (the two don't overlap).

## Assumptions

- **Reads the working tree only.** Doesn't depend on `git` / `gh`
- The criteria for layer placement live in the repo's `.claude/rules/layering.md`; the PR size guideline and the doc-colocation convention live in `.claude/rules/review-checklist.md`. **Read those first**
- If they don't exist in the repo: fall back to the generic version in `references/portable-planning.md` and state explicitly that it ran without the repo-specific layer conventions

## Procedure

1. **Layer placement** — assign each change to a layer. For each layer, **name one existing example file and confirm it exists by grep**
2. **Order by dependency** — the referenced side first. If it cycles, change how the split is cut
3. **Split into PRs** — cut by dependency order / the size guideline / the doc-colocation convention. 1 PR = 1 responsibility
4. **Steps per PR** — files to touch, tests to add, pitfalls, local verification commands
5. **Confirm the verification means exist** — grep the repo's task definition files for every task / test command named. **Don't write a command that doesn't exist**

## Output

- The PR list: order / purpose / files touched / expected line count
- Per PR: steps at a granularity a junior can follow / pitfalls / local verification commands
- Spec items that couldn't be turned into a plan, called out as open questions (don't drop them silently)

## Don't

- Implement / commit / push
- Change the spec's design decisions (report contradictions and stop)
- Detect conflicts with in-flight PRs / branches (`/spec-check`'s job on the Claude Code side)
- Put commands or file paths into the plan without confirming they exist
