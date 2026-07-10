---
name: self-review-changes
description: Self-review of the most recent diff (working tree or staged), checking accuracy, consistency, best practices, and alignment with memory feedback. Presents a fix plan and only Edits after user approval. Used for 「self review して」「review して」「修正箇所ないか確認して」 etc.
---

> **Source of truth:** `claude/ja/skills/self-review-changes/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# self-review-changes

Re-scans the most recent diff, surfaces fix candidates, and only applies fixes after approval. **4 phases**: Mindset → Observation → Analysis → Action.

> **Division of labor with plugins**: the `/code-review` and `/simplify` plugins specialize in diff bugs / simplification. This skill additionally covers a broader self-review including **configuration accuracy, doc consistency, memory feedback alignment, and the Copilot 11-category checklist**. Use `/code-review` for bugs in the code alone, and this skill for reviewing the whole change against conventions.

## Applicability

- Some file edit happened in the immediately preceding turn (before committing or right after the most recent commit)
- The scope of the fix target is clear (visible in `git diff`)

---

## Phase 0: Mindset shift (implementer → external reviewer)

The biggest bias in self-review is that "you can see your own intent but not the actual gap." Before moving on to Phase 1, internally declare that you will read the code as **"an external reviewer seeing this code for the first time."** Treat comments as a binding contract; phrases like "I meant it this way," "that doesn't happen with typical input," or "it's fine because it's an internal caller" are forbidden. Adversarially assume wire-format input, nil / empty / boundary values, malformed tokenizer output, mid-cancellation state, and invalid specs. Maintain this mindset through Phase 2, especially 2.6-2.9.

---

## Phase 1: Observation (grasp the diff + gather related information)

### 1.1 Grasp the diff

```bash
git status
git diff --stat
git diff [--cached]
git show HEAD --stat && git show HEAD  # 直近 commit 後
```

### 1.2 Read all changed files in parallel

Read each changed file in parallel with the Read tool (not `cat` via Bash).

### 1.3 Read related memory

- Read the `MEMORY.md` index, decide which feedback / project entries relate to the edit, and read those entries in full
- **Always required every time**:
  - Mechanically check this skill's Phase 2.1 / 2.1.1 (Copilot's frequent 11 categories + rebuttal patterns) and Phase 2.6-2.9
  - CLAUDE.md's "conduct for changes" (flagging out-of-scope changes) (Phase 2.3)
  - No speculative mapping (only literal correspondences from the source text / Phase 2.5)

---

## Phase 2: Analysis (check by perspective)

### 2.1 Design perspective — Copilot's frequent 11 categories (most important)

The 11 categories that come up frequently in Copilot review (aggregated from analysis of 26 total reviews across PR #26 and PR #30). Expanded below.

**5 categories from PR #26**:

| # | Category | Key point |
|---|---|---|
| 1 | **Documentation accuracy** | When renaming a helper / API, grep all related docs / check for dropped `_` errors in samples / verify doc comment behavior matches the implementation |
| 2 | **Input validation** | Check 0 / negative / nil / empty / traversal in public APIs (`WithXxx` / `NewXxx` / handler args); place validation at the end of the constructor |
| 3 | **Edge cases** | Wire-form parameters present (MIME `mime.ParseMediaType`) / empty check via `strings.TrimSpace` / all-elements-fail in a batch / catch empty output |
| 4 | **Concurrency / cancellation** | Respect `ctx.Deadline` / avoid spawning goroutines / check `ctx.Err()` at each step / **propagate ctx all the way down** (including pre-processing loops) |
| 5 | **Error contract** | Sentinel semantic contract (transient vs. permanent) / no retry on 4xx / wrap boundary errors at the port level |

**6 extended categories from PR #30**:

| # | Category | Key point |
|---|---|---|
| 6 | **Symmetric constructor defense** | When adding a guard to one constructor, `grep "^func New"` to check whether other constructors in the same PR have the same guard (mechanically checked in Phase 2.6) |
| 7 | **Doc/impl literal drift** | Cross-check comments containing strong claims ("strictly", "preserves", "Returns X") against the implementation byte-for-byte (mechanically checked in Phase 2.9) |
| 8 | **Sentinel-on-error leakage** | Check the godoc of dependency interfaces for whether 0 / "" / nil / -1 is a contractual return on the error path, and whether the consumer defends against it (mechanically checked in Phase 2.7) |
| 9 | **Exported function type contract** | If exporting `type X func(...) error` with a docstring claiming "all options X," check whether custom implementations satisfy the same contract, or wrap via a factory (mechanically checked in Phase 2.7) |
| 10 | **Test assertion trivially passes** | Scenarios where repeated fixture content / a loose `Contains` / a nil-only check would "pass even if the implementation is broken" (mechanically checked in Phase 2.8) |
| 11 | **Slice OOB / panic guard (test)** | Whether a `slice[len-N:]` in a test has a `len >= N` guard immediately before it, guarding against panics when the input is short |

### 2.1.1 Rebuttal patterns (identifying false positives)

The following are rebuttal patterns that, given project context, are judged "not applicable" and resolved via reply:

- **Go 1.22+ loop variable shadowing**: if the `go.mod` go directive is 1.22+, shadowing is not an issue
- **Re-proposing internal port boundary defense**: if it was withdrawn during a design discussion, resolve by referencing the PR description
- **Duplicate posting of the same warning**: if the same pattern doesn't actually apply to a different test, explicitly note it as a false positive

### 2.2 Mechanical checks by file type

- **Go (`*.go`)**: `gofmt` / `goimports` / godoc conventions (`// Package <name>` / `// FuncName ...`) / `fmt.Errorf("...: %w", err)` / context arg first / unnecessary exports
- **Config (`.golangci.yaml` / `Makefile` / `*.yaml` / `*.json`)**: schema version (e.g., golangci-lint v1 vs v2) / regex glob (substring match for `gen` vs. root-anchored `^gen/`) / indentation
- **Markdown / Docs**: relative links / code block language tags / consistent table cell counts / heading hierarchy
- **Shell / Makefile / Dockerfile**: shell injection (quoting `$VAR`) / dangerous commands (`rm -rf`, `curl | sh`)
- **Proto (`.proto`)**: package / option / field number / backward compatibility (`buf breaking`)

### 2.3 Spec literal consistency (only for work touching a spec doc)

When working with a spec (`docs/adr/*.md`, `docs/design/*.md`, OpenAPI, Proto):

1. Grep to enumerate literals (type names / enums / fields / file names) in the spec
2. Grep to enumerate the same surface on the implementation side
3. Write out **deviations** explicitly, and for each present the user with a "reason" and a remediation approach ((a) align with the spec / (b) update the spec / (c) separate ADR)

Don't use "it's fine, it's a prototype" as an implicit justification. Use the three-point set of explicit statement, approval, and record (CLAUDE.md's "conduct for changes" — flag out-of-scope changes).

### 2.4 Consistency with memory conventions

Check whether the diff violates any related memory identified in Phase 1.3:

- Terminology conventions (follow the terminology conventions in memory)
- Document style (don't add prerequisite-knowledge preambles; relax during the prototype period)
- Comment language (English for `*.go` / Makefile / proto / shell)
- Mixing Phase / ticket ID notation into comments
- Commit message style (short, content-only)

### 2.5 Cross-reference / forbidden-token grep

Grep across all changed files for:

- **Leaking transient info**: `ticket`, `in a later`, `future ticket`, `see (commit|PR) #`, ticket ID formats (`#?\d+`, `[A-Z]+-\d+`). Get the literal check patterns from the project's `MEMORY.md` feedback rather than hardcoding them in the skill
- **Cross-reference existence check**: whether section references in comments (`§[0-9]+\.[0-9]+`, etc.) use vocabulary that matches the source text
- **Speculative mapping**: whether a comment fills in a correspondence that isn't actually stated in the source text

### 2.6 Symmetry audit (symmetric defense check)

Check whether symmetric counterparts (enumerate all constructors in the same PR with `grep "^func New" $(git diff --name-only)`, and also grep functions taking `opts ...Option`) to a guard / validation / nil check added in the diff have the same guard, and flag any that are missing.

Example: PR #30 C9 — after adding a nil-opt reject to `ports.NewChunkSpec`, the `opts` of `chunker.New` needed the same guard (a lesson from fixing one spot and missing the other).

### 2.7 Interface contract trace (sentinel / exported type)

Re-read the godoc of any external interface used in changed files, and confirm that **sentinel return cases** (0 / "" / nil / -1 / a specific error sentinel) and the consumer's branching (`if x <= X`, `errors.Is(...)`) are consistent. If an exported function type is being exported, check whether the docstring's "all" / "always" claim also holds for custom implementations, or whether it's normalized via a factory.

Example: PR #30 C10 — `chunking.Tokenizer.CountTokens` returns 0 on an encoding error, so the consumer's `tokens <= MaxTokens` check needs a defense so this 0 isn't mistaken for "fits." C13 — a custom implementation of the exported `ChunkSpecOption` could break the contract, so it's wrapped via a factory.

### 2.8 Adversarial test review (surfacing trivial passes)

For each test's assertions, ask: "**is there a mutation that inverts the implementation's behavior but still passes?**" Pay special attention when the input contains repeated content / identical values / nil / empty, and look for paths where assertions like `strings.Contains` / `len(got) > 0` / `errors.Is(...)` trivially pass.

Example: PR #30 C7 — checking carry-over overlap with `strings.Contains` against 80 repeats of the same sentence → trivially true even if carry-over is broken. The fix was to insert a distinct marker (`[文NNN]`) and verify the boundary with `HasPrefix`.

### 2.9 Doc last-write-wins (surfacing stale comment updates)

After an implementation change, re-read every comment in the changed files with suspicion. Grep for strong claims (`grep -nE "(strictly|preserves|guarantees|ensures|always|never|returns|panics)"`), and cross-check each claim against the implementation's literal behavior byte-for-byte (e.g., is "strictly under X" `<` or `<=`? does "preserves Y" hold given that upstream trims Y? what does "returns Z on W" actually return?). Resolve discrepancies by either aligning the doc with the implementation, or aligning the implementation with the doc based on design intent.

Example: PR #30 C11/C12 — `carryOverlap`'s "kept strictly under overlap" was corrected to "at most overlap" since the implementation allows equality; `joinUnits`'s "preserves original surface text" was corrected to "reproduces sentence content but not byte-for-byte identical" since `SplitSentences` trims whitespace.

---

## Phase 3: Action (fix plan → approval → fix → re-verify)

### 3.1 Organize fix candidates (present as a table)

```
## Self-review 結果

| # | file:line | 問題 | 修正方針 | 重要度 |
|---|---|---|---|---|
| 1 | .golangci.yaml:14 | paths 値が部分一致 regex で過剰マッチ | `^gen/` に変更 | 望ましい |
| 2 | cmd/x/main.go:1 | コメント日本語 | 英語に書き換え | 致命的 (memory feedback 違反) |

## 問題なし
- go.mod (module path / go directive 正しい)
- Makefile (ターゲット動作確認済み)
```

Distinguish severity into 3 tiers: **critical / recommended / nit**.

### 3.2 User approval

Wait for "go ahead." Also accept selective approval (approving only some candidates).

### 3.3 Fix via Edit (parallel)

Apply approved candidates in parallel with the Edit tool.

### 3.4 Re-verification

Check for side effects after the fix:
- Re-run `make test`, `make lint`
- Re-run related greps (check whether the fix introduced the same problem elsewhere)

---

## Iron rules

1. **Don't skip the Phase 0 mindset shift**: consciously set aside implementer bias. Judge based on "code and comments alone, as an external reviewer," not "your own intent"
2. **Present the fix plan first**: don't Edit silently
3. **Distinguish critical / recommended / nit**: so the user can pick and choose
4. **Read memory feedback entries in full**: don't judge from the index line alone
5. **Check the Copilot 11 frequent categories every time** (Phase 2.1): docs accuracy / validation / edge cases / cancellation / error contract / symmetry / doc drift / sentinel leakage / exported func type contract / test trivial pass / slice OOB
6. **Don't skip the 4 mechanical checks — symmetry / interface contract / adversarial test / doc last-write-wins** (Phase 2.6-2.9): this is where the real blind spots concentrate
7. **Explicitly state, get approval for, and record spec deviations**: don't use "it's a prototype" as an implicit justification (CLAUDE.md's "conduct for changes" — flag out-of-scope changes)
8. **No speculative mapping**: cross-references / terminology correspondence in comments should stay within what the source text literally states
9. **Verify side effects**: re-run build / test / lint after fixing
10. **Don't hide anything**: point out problems even in something you created in the immediately preceding turn. Don't skip a check just because "it doesn't happen with typical input" or "it's fine, it's an internal caller"
