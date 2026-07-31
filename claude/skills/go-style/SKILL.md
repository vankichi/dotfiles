---
name: go-style
description: Reference skill for Go idioms, naming, error handling, context, logging, concurrency, and lint/format conventions. Consulted for questions like 「Go お作法的にどう」「命名規約」「error wrap」 or during code review. Not a procedural skill.
---

> **Source of truth:** `claude/ja/skills/go-style/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# go-style

The house Go conventions, plus detection signals for catching violations mechanically. The basis for judgment during implementation / review / refactor candidate generation.

**General Go practice is not restated** (errors are values / ctx is the first argument / the sender closes the channel / wrap with `fmt.Errorf("%w")`). This skill carries only the house's choices and the signals that surface a violation via grep.

## 1. Package layout

- `cmd/<bin>/main.go` is the binary entry point. One binary = one subdirectory
- Implementation goes under `internal/` by default
- `pkg/` is **only for what is meant to be imported externally**. No expected reuse → `internal/`
- `apis/` separates the proto / OpenAPI / SDK public surface
- With DDD, use `internal/{domain,application,interfaces,adapters}/` (`ddd-clean-architecture` is the SoT for layer boundaries)
- One package = one responsibility. Catch-all packages named `util` / `common` / `helper` are **forbidden**

**Detect**
- Multiple responsibilities living in `internal/util/`
- Business logic inside `cmd/`
- `pkg/` in use with no actual external importer

## 2. Naming

- exported vs unexported is decided solely by **whether it needs to be public now**. Capitalizing for "we might publish it later" is **forbidden**
- Receiver names are **the same short name across every method of a type** (`s *Server`). `this` / `self` are **forbidden**
- Single-method interfaces take the `-er` suffix; multi-method ones are nouns
- Enum values are prefixed with the type name (`type Model string` + `ModelTextEmbedding3Large Model = "..."`)

### Acronyms stay fully capitalized

| Case | Correct | Wrong |
|---|---|---|
| 3+ letters | `URL` `ID` `HTTP` `API` | `Url` `Id` `Http` |
| 2 letters | `AI` `IO` `UI` `OS` `DB` | `Ai` `Io` `Ui` |
| Trademarks / generalized spellings | `OpenAI` `OpenAPI` `gRPC` | — |
| Trademark leading an unexported name | `openaiKey` `openapiSpec` | `openAIKey` |

Note the last row — **when a trademark leads an unexported identifier, lowercase the trademark portion too**. A case mix inside the acronym is not acceptable.

### Consolidating constants

- Extract magic numbers and repeated literals (string keys, thresholds, timeouts, URL paths) into named consts. Trivial `0` / `1` / `""` are out of scope
- Group related constants into one const block. Scattering them across the file / package is **forbidden**

**Detect**
- Bare numeric literals in expressions
- The same string literal appearing 2+ times
- Constants of the same kind scattered across multiple const declarations
- Mixed-case acronyms like `Url` `Id` `Http` `Ai` `Io` `Ui`, or case mixes like `openAIKey`
- A receiver named `this *X`, or receiver names for one type varying by file
- Symbols exported only "in case we publish it later"

## 3. Error handling

- Sentinel errors are package-level `var Err... = errors.New("pkg: human message")`. The `package:` prefix keeps the wrap chain readable
- **Separate the sanitized outward-facing message from the internal wrap chain at API boundaries.** Leaking upstream details to clients is **forbidden** — emit internal details via the logger
- panic is only for truly exceptional states (invariant violations at startup). Use in normal flow is **forbidden**

**Detect**
- `errors.New(fmt.Sprintf(...))`
- String comparison of errors (`err.Error() == "..."`)
- Upstream SDK errors leaking into a handler's or gRPC server's error response
- panic or `log.Fatal` outside `cmd/`

## 4. Context

- `ctx.Value` is only for cross-cutting metadata (request_id / trace span / auth principal). Anything passable as an argument goes as an argument
- Avoid ctx key collisions with a **package-private struct type** (`type requestIDKey struct{}`)

**Detect**
- `context.Background()` inside a library
- `ctx.Value("string-key")` — a collision-prone string key
- `ctx context.Context` as a struct field
- ctx placed last or in the middle of the argument list

## 5. Logging

- Adopt the standard `log/slog`. Structured JSON (`slog.NewJSONHandler`) recommended
- Levels: `Error` (action required) / `Warn` (abnormal but continuing) / `Info` (normal operation) / `Debug` (development only)
- Pass ctx via `LogAttrs(ctx, ...)` so interceptors / middleware can attach span and request_id
- **Log messages are fixed strings; variable values go in attrs** — for cardinality control and greppability
- **Logging PII or credentials is forbidden**

**Detect**
- Operational logs emitted via `fmt.Println` / `log.Print*`
- Interpolated messages like `slog.Info(fmt.Sprintf(...))`
- API keys, passwords, or personal identifiers in a log message

## 6. Concurrency

- **Make explicit what a mutex protects** — a comment right before the struct field, or the protected fields listed right after `mu sync.Mutex`
- Restrict channel direction in function signatures (`<-chan T` / `chan<- T`)
- Prefer `errgroup.Group` for concurrent IO (context-linked cancellation + capture of the first error)

**Detect**
- A goroutine observing neither `ctx.Done()` nor a channel receive — leak candidate
- A `mu sync.Mutex` with no stated protection target
- Bidirectional `chan T` in a signature
- A panic inside a goroutine with no defer-recover

## 7. Lint / format

- `golangci-lint` **v2** (configured via `.golangci.yaml`). Required in CI
- **Set `goimports`'s local prefix to each repo's module path**
- Recommended linters: `errcheck` / `govet` / `staticcheck` / `ineffassign` / `unused` / `gosimple` / `gofmt` / `goimports`
- `// nolint:` **requires a reason comment** (`// nolint:errcheck // intentional fire-and-forget`)

**Detect**
- `// nolint:` with no reason
- Import order mixing stdlib, third-party, and local
- An error return discarded into `_`

## 8. godoc / Comments

- Exported symbols require godoc. The package comment goes in one file per package as `// Package <name> ...`
- **Comments say WHY; the code says WHAT**
- Doc comments on unexported symbols are optional. If written, WHY only, 1-3 lines
- **Verbatim restatements of the code below are forbidden.** Don't copy the neighboring code even if it does this — earlier output may have drifted from the conventions
- "We want to do X later" goes in a `TODO:`. **Leaving Phase / ticket IDs in comments is forbidden**
- `Deprecated:` is stated explicitly in the target symbol's godoc

**Detect**
- Exported symbols without godoc
- Comments that only restate WHAT
- Mechanically attached WHAT-explaining doc blocks on unexported methods (4+ lines especially)
- Timeline or ticket-scope references like `Phase 0`

## 9. Import order

Separate the three groups — stdlib / third-party / local — with blank lines (automated by `goimports`'s `-local` setting). Alphabetical within each group.

**Aliases only when necessary** — collision avoidance only. `pgsql "github.com/lib/pq"` is acceptable; `f "fmt"` is not.

**Detect**: no group separation / unnecessary aliases (`io2 "io"`)

## 10. Type safety / nil safety

- `interface{}` / `any` only when the type is genuinely undetermined (passthrough is fine)
- Guard against nil pointers by **rejecting nil in the constructor**
- **Mixing pointer and value receivers on one type is forbidden.** If there is a mutating method, all methods take a pointer receiver

**Detect**: `any` in business logic / mixed receivers on the same type / map assignment missing a nil check

## Identifying false positives

Even when a detection signal fires, the following are **not violations**.

| Category | Judgment |
|---|---|
| Generated code | Files containing `Code generated by ... DO NOT EDIT.` at the top. Fix the source schema instead |
| Language / library idioms | Fixed signatures like `http.Handler`. These take precedence over this skill's rules |
| Deliberate design exceptions | Decisions whose intent is stated in code or docs (e.g. `context.Background()` inside a library to detach a shutdown context from a signal-aware ctx) |
| Public API compatibility | Exported symbols that can't change for backward compatibility. Propose a migration strategy, not a rename |

Excluding on suspicion alone is **forbidden**. Flag it as a "false positive candidate" and seek the user's judgment.

## Output

When called from `code-refactor-advisor`, return a per-section list of violations / improvement opportunities, each carrying:

- **The detection signal** — which pattern caught it
- **The section number** it's based on
- **A remediation stance** — align with the convention / keep as an exception / discuss separately
