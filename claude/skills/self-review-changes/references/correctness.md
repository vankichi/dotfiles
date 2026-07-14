> **Source of truth:** `claude/ja/skills/self-review-changes/references/correctness.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# correctness — Copilot's frequent 11 categories + mechanical checks

Skippable: code diff is 0 (docs / config-only change).

## Copilot's frequent 11 categories (aggregated from analysis of 26 total reviews across PR #26 and PR #30)

**5 categories from PR #26**:

| # | Category | Key point |
|---|---|---|
| 1 | **Documentation accuracy** | When renaming a helper / API, grep all related docs / dropped `_` errors in samples / doc comment behavior matches the implementation |
| 2 | **Input validation** | Check 0 / negative / nil / empty / traversal in public APIs (`WithXxx` / `NewXxx` / handler args); place validation at the end of the constructor |
| 3 | **Edge case** | wire-form parameters present (MIME `mime.ParseMediaType`) / `strings.TrimSpace` empty check / all elements of a batch fail / catch empty output |
| 4 | **Concurrency / cancellation** | Respect `ctx.Deadline` / avoid spawning goroutines / check `ctx.Err()` each time / **propagate ctx to the deepest level** (including the pre-processing loop) |
| 5 | **Error contract** | sentinel semantic contract (transient vs permanent) / no retry on 4xx / port-level wrap of boundary errors |

**6 extended categories from PR #30**:

| # | Category | Key point |
|---|---|---|
| 6 | **Symmetric constructor defense** | After adding a guard to one constructor, whether other constructors in the same PR have the same guard (mechanically checked in "Symmetry audit" below) |
| 7 | **Doc/impl literal drift** | Cross-check comments containing strong claims ("strictly", "preserves", "Returns X") against the impl at the byte level ("Doc last-write-wins" below) |
| 8 | **Sentinel-on-error leakage** | Check the godoc for whether a dependency interface contractually returns 0 / "" / nil / -1 on the error path, and defend on the consumer side ("Interface contract trace" below) |
| 9 | **Exported function type contract** | Exporting `type X func(...) error` with a docstring claiming "all options X" → whether custom implementations satisfy the same contract, or wrap via a factory |
| 10 | **Test assertion trivially passes** | repeated fixture content / loose `Contains` / nil-only check (details in references/test-adversarial.md) |
| 11 | **Slice OOB / panic guard (test)** | a `len >= N` guard right before `slice[len-N:]` in a test, panic when the input is short |

## Rebuttal patterns (identifying false positives)

Patterns judged "not applicable" given project context and resolved:

- **Go 1.22+ loop variable shadow**: if the `go.mod` go directive is 1.22+, shadowing is not an issue
- **Re-proposing internal port boundary defense**: if it was withdrawn during a design discussion, resolve by referencing the PR description
- **Duplicate posting of the same warning**: if the same pattern doesn't apply to a different test, explicitly mark it as a false positive

## Mechanical check 1: Symmetry audit (Symmetric defense)

Check whether symmetric counterparts (enumerate all constructors in the same PR with `grep "^func New" $(git diff --name-only)`, and also grep functions taking `opts ...Option`) to a guard / validation / nil check added in the diff have the same guard, and flag any that are missing.

Example: PR #30 C9 — after adding a nil-opt reject to `ports.NewChunkSpec`, the `opts` of `chunker.New` needed the same guard (a lesson from fixing one spot and missing the other).

## Mechanical check 2: Interface contract trace (Sentinel / Exported type)

Re-read the godoc of external interfaces used in changed files, and confirm that the flow is consistent between the **sentinel cases of the return value** (0 / "" / nil / -1 / a specific error sentinel) and the consumer's branching (`if x <= X`, `errors.Is(...)`). If you are exporting an exported function type, check whether the docstring's "all" / "always" claim also holds for custom implementations, or whether it's normalized via a factory.

Example: PR #30 C10 — `chunking.Tokenizer.CountTokens` returns 0 on an encoding error, so the consumer's `tokens <= MaxTokens` check needs a defense so this 0 isn't mistaken for "fits." C13 — the path where a custom implementation of the exported `ChunkSpecOption` breaks the contract is wrapped via a factory.

## Mechanical check 3: Doc last-write-wins (surfacing missed comment updates)

After an implementation change, re-read every comment in the changed files with suspicion. Grep for strong claims (`grep -nE "(strictly|preserves|guarantees|ensures|always|never|returns|panics)"`), and cross-check each claim against the impl's literal behavior at the byte level (e.g., is "strictly under X" `<` or `<=` / does "preserves Y" hold given that upstream doesn't trim Y). For discrepancies, either align the doc with the impl, or align the impl with the doc based on design intent.

Example: PR #30 C11/C12 — `carryOverlap`'s "kept strictly under overlap" was corrected to "at most overlap" since the impl allows equality; `joinUnits`'s "preserves original surface text" was corrected to "reproduces sentence content but not byte-for-byte identical" since SplitSentences trims whitespace.
