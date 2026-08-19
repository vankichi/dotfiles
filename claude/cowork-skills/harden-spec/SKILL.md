---
name: harden-spec
description: Cross-checks a design draft / ticket against the repo to make it implementable: 5 drift classes + data model minimization, open decisions returned with a recommendation. Working tree only. 「spec 詰めて」
---

> **Source of truth:** `claude/ja/cowork-skills/harden-spec/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# harden-spec

Takes a design draft / ticket a human wrote and turns it into an **implementable spec** by cross-checking it against what the repo actually contains.

**Makes no design decisions.** Open decisions go back to the human with options + a recommendation + the rationale. Doesn't produce an implementation plan either (that's `plan-implementation`).

Boundary with `write-spec`: that skill fills the holes in the spec contract (are the required sections present). This skill checks the spec **against the repo's reality** (does what's written hold in the repo).

## Trigger

Default-on. If skipping, output the reason.

- Requests like 「spec を詰めて」「実装可能にして」「設計を repo と突き合わせて」
- A ticket / design draft is in the input and the target repo is open

## Assumptions

- **Reads the working tree only.** Doesn't depend on `git` / `gh` / branches / diffs. Conflict detection against in-flight PRs / branches is out of scope (it lives in `/spec-check` on the Claude Code side)
- The SoT for the perspectives is `.claude/rules/spec-drift.md` in the repo. **Read it first**
- If the spec touches the data model, also read `.claude/rules/data-modeling.md`
- If neither exists in the repo: fall back to the generic version in `references/portable-checklist.md` and state explicitly that it ran without the repo-specific perspectives

## Procedure

1. **List the spec's literals** — identifiers / paths / citations / columns and fields / commands
2. **Resolve them against the repo** — grep each one. Unresolved ones are drift candidates
3. **Judge every drift class** — output found / none + what was checked **for every class** (no silent skips)
4. **Data model minimization** — for any proposed new persisted state, apply derive > tighten an existing column > add a column, in that order
5. **Surface the open decisions** — present options + one recommendation + the rationale, then wait for the human's decision
6. **Write the decisions back** into the spec body. Keep the rejected options and why, so the same discussion doesn't reopen

## Output

- Per drift finding: class / evidence on both sides (repo side as path + symbol or heading, spec side as the section heading + the quoted sentence) / why it is drift / proposed resolution
- The list of open decisions: options, recommendation, rationale
- A final verdict on whether it is implementable. **Don't set the ready flag** (humans only)

## Don't

- Settle design decisions unilaterally, set the ready flag, commit / push
- Detect conflicts with in-flight PRs / branches (`/spec-check`'s job)
- Produce layer placement / PR splits / step-by-step plans (`plan-implementation`'s job)
- Cite by line number (they go stale — point at path + symbol or heading)
