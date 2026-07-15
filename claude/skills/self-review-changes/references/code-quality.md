> **Source of truth:** `claude/ja/skills/self-review-changes/references/code-quality.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# code-quality — readability / simplification / convention compliance

Skippable: code diff is 0. Not bug detection but the "better way to write it" perspective (playing the `/simplify` role inside the loop).

- **Duplication / reuse**: grep whether a helper / util equivalent to the added logic already exists in the repo. Whether the same kind of processing is written in 2 or more places
- **Simplification**: unnecessary intermediate variables / deep nesting (flatten with early return) / excessive abstraction (an interface with only one implementation, etc.)
- **Naming**: whether behavior matches the name / consistency with the repo's existing vocabulary (see `go-style`)
- **Altitude**: whether the level of abstraction within a function is uniform (separate mixed low-level operations and high-level judgments)
- **Convention compliance**: for Go, hold it against the criteria of the `go-style` / `go-test` reference skills, and for layer structure, `ddd-clean-architecture` (those are the SoT for details)
- **Comments**: self-evident "what it does" comments / PR-oriented explanatory comments are removal targets. What should be written is only "constraints that can't be written in code"
