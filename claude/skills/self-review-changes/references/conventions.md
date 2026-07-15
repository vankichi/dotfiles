> **Source of truth:** `claude/ja/skills/self-review-changes/references/conventions.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# conventions — memory convention alignment + forbidden tokens

Skippable: none (always performed).

## memory convention alignment

Check whether the edit diff violates any related memory identified in Phase 1:

- Terminology conventions (follow the terminology conventions in memory)
- Document style (don't set up prerequisite sections; relax during the prototype period)
- Comment language (English for `*.go` / Makefile / proto / shell)
- Mixing Phase / ticket ID notation into comments
- Commit message style (short, content only)

## cross-reference / forbidden tokens grep

Grep across all changed files:

- **Leaking transient info**: `ticket`, `in a later`, `future ticket`, `see (commit|PR) #`, ticket ID formats (`#?\d+`, `[A-Z]+-\d+`). Get the literal check patterns from the project's `MEMORY.md` feedback; don't hardcode them in the skill
- **Cross-reference existence check**: whether section references in comments (`§[0-9]+\.[0-9]+`, etc.) use vocabulary that matches the source text
- **Speculative mapping**: whether a comment fills in a correspondence not actually stated in the source text (stay within the literal source text)
