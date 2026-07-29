# Generic checklist (fallback when the repo has no perspective files)

Use this only when the repo has no `.claude/rules/spec-drift.md` / `.claude/rules/data-modeling.md`. It contains no repo-specific paths or identifiers. When using it, state in the output that the run went without the repo-specific perspectives.

## The 5 drift classes

| # | Class | How to detect |
|---|---|---|
| D1 | Contradiction inside the spec | Per entity (column / field / endpoint / ordering / failure mode), collect the normative statements and compare them pairwise. They cluster around entities that appear in more than one section |
| D2 | spec ↔ implementation | Grep every identifier the spec names (type / function / column / field / env var / task). For each miss, decide and state whether it is genuinely new or a wrong name |
| D3 | spec ↔ SoT doc | Read the certainty markers of the docs in the change area at both the whole-doc and section level. A spec that depends on an unsettled section must name that dependency and get it confirmed |
| D4 | Citation that doesn't resolve in the repo | Resolve every citation to a path plus heading. An unresolvable citation is not evidence — replace it with the repo's literal or drop it |
| D5 | The thing already exists | Before accepting any "add X", grep the existing surface: schema / API definitions / error definitions / config files |

Recurring D1 shapes: "behavior unchanged / existing tests stay green" coexisting with a newly specified internal behavior on the same code path; a DoD example table whose expected values the design body's algorithm can't produce; a DoD item requiring something the non-goals exclude.

When docs contradict each other, don't rank them by doc type — find the SoT declaration inside the docs themselves and follow it. If there is none, escalate to a human.

## Data model minimization

Order of preference: **derive > tighten an existing column > add a column**.

- Suspect the new column first. Can it be derived from existing state (a timestamp, the presence of a row, an existing enum)?
- Tighten an existing column to a single meaning instead of adding a second overlapping column
- Reduce the design to one invariant and derive per-case behavior from it
- Treat "we can't drop existing data" as a question, not a settled constraint. Running a destructive migration is a human's call and needs dry-run / blast radius / rollback
- Record the rejected shape and the reason
