---
name: go-style
description: Reference skill for Go idioms, naming, error handling, context, logging, concurrency, and lint/format conventions. Consulted for questions like 「Go お作法的にどう」「命名規約」「error wrap」 or during code review. Not a procedural skill.
---

> **Source of truth:** `claude/ja/skills/go-style/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# go-style

The house Go conventions. Each section is two blocks: **Do (the house's choice)** and **Don't (prohibitions, which double as detection signals)**.

**General Go practice is not restated** (errors are values / ctx is the first argument / the sender closes the channel / wrap with `fmt.Errorf("%w")`). This skill carries only the house's choices and the signals that surface a violation via grep.

## 1. Package layout

**Do**
- `cmd/<bin>/main.go` is the binary entry point. One binary = one subdirectory
- Implementation goes under `internal/` by default
- `pkg/` is only for what is meant to be imported externally
- `apis/` separates the proto / OpenAPI / SDK public surface
- With DDD, use `internal/{domain,application,interfaces,adapters}/` (`ddd-clean-architecture` is the SoT for layer boundaries)

**Don't**
- Catch-all packages named `util` / `common` / `helper` (one package = one responsibility)
- Multiple responsibilities living in `internal/util/`
- Business logic inside `cmd/`
- Using `pkg/` with no actual external importer

## 2. Naming

**Do**
- Decide exported vs unexported solely by **whether it needs to be public now**
- Use the same short receiver name across every method of a type (`s *Server`)
- Single-method interfaces take the `-er` suffix; multi-method ones are nouns
- Prefix enum values with the type name (`type Model string` + `ModelTextEmbedding3Large Model = "..."`)
- Extract magic numbers and repeated literals (string keys, thresholds, timeouts, URL paths) into named consts (trivial `0` / `1` / `""` excluded)
- Group related constants into one const block

**Acronyms stay fully capitalized**

| Case | Correct | Wrong |
|---|---|---|
| 3+ letters | `URL` `ID` `HTTP` `API` | `Url` `Id` `Http` |
| 2 letters | `AI` `IO` `UI` `OS` `DB` | `Ai` `Io` `Ui` |
| Trademarks / generalized spellings | `OpenAI` `OpenAPI` `gRPC` | — |
| Trademark leading an unexported name | `openaiKey` `openapiSpec` | `openAIKey` |

Note the last row — when a trademark leads an unexported identifier, lowercase the trademark portion too.

**Don't**
- A receiver named `this *X` / `self *X`
- Receiver names for one type varying by file
- Symbols exported only "in case we publish it later"
- Mixed-case acronyms like `Url` `Id` `Http` `Ai` `Io` `Ui`, or case mixes like `openAIKey`
- Bare numeric literals in expressions / the same string literal appearing 2+ times
- Constants of the same kind scattered across multiple const declarations

## 3. Error handling

**Do**
- Define sentinel errors as package-level `var Err... = errors.New("pkg: human message")` (the `package:` prefix keeps the wrap chain readable)
- Separate the sanitized outward-facing message from the internal wrap chain at API boundaries; emit internal details via the logger
- Reserve panic for truly exceptional states (invariant violations at startup)

**Don't**
- `errors.New(fmt.Sprintf(...))`
- String comparison of errors (`err.Error() == "..."`)
- Leaking upstream SDK errors into a handler's or gRPC server's error response
- panic or `log.Fatal` outside `cmd/`

## 4. Context

**Do**
- Use `ctx.Value` only for cross-cutting metadata (request_id / trace span / auth principal)
- Avoid ctx key collisions with a package-private struct type (`type requestIDKey struct{}`)

**Don't**
- `context.Background()` inside a library
- `ctx.Value("string-key")` — a collision-prone string key
- `ctx context.Context` as a struct field
- ctx placed last or in the middle of the argument list

## 5. Logging

**Do**
- Adopt the standard `log/slog`; structured JSON (`slog.NewJSONHandler`) recommended
- Levels: `Error` (action required) / `Warn` (abnormal but continuing) / `Info` (normal operation) / `Debug` (development only)
- Pass ctx via `LogAttrs(ctx, ...)` so interceptors can attach span and request_id
- Keep log messages as fixed strings with variable values in attrs (cardinality control + greppability)

**Don't**
- **Logging PII or credentials**
- Operational logs emitted via `fmt.Println` / `log.Print*`
- Interpolated messages like `slog.Info(fmt.Sprintf(...))`

## 6. Concurrency

**Do**
- Make explicit what a mutex protects (a comment right before the struct field, or the protected fields listed right after `mu sync.Mutex`)
- Restrict channel direction in function signatures (`<-chan T` / `chan<- T`)
- Use `errgroup.Group` for concurrent IO (context-linked cancellation + capture of the first error)

**Don't**
- A goroutine observing neither `ctx.Done()` nor a channel receive — leak candidate
- A `mu sync.Mutex` with no stated protection target
- Bidirectional `chan T` in a signature
- A panic inside a goroutine with no defer-recover

## 7. Lint / format

**Do**
- `golangci-lint` **v2** (configured via `.golangci.yaml`). Required in CI
- Set `goimports`'s local prefix to each repo's module path
- Recommended linters: `errcheck` / `govet` / `staticcheck` / `ineffassign` / `unused` / `gosimple` / `gofmt` / `goimports`

**Don't**
- `// nolint:` without a reason comment (correct: `// nolint:errcheck // intentional fire-and-forget`)
- Import order mixing stdlib, third-party, and local
- Discarding an error return into `_`

## 8. godoc / Comments

**Do**
- Give every exported symbol godoc. The package comment goes in one file per package as `// Package <name> ...`
- **Write WHY in comments; the code says WHAT**
- Doc comments on unexported symbols are optional (if written, WHY only, 1-3 lines)
- Put "we want to do X later" in a `TODO:`
- State `Deprecated:` explicitly in the target symbol's godoc

**Don't**
- **Leaving Phase / ticket IDs in comments** (timeline or ticket-scope references like `Phase 0`)
- Verbatim restatements of the code below — **don't copy the neighboring code even if it does this** (earlier output may have drifted from the conventions)
- Exported symbols without godoc
- Comments that only restate WHAT
- Mechanically attached WHAT-explaining blocks on unexported methods (4+ lines especially)

## 9. Import order

**Do**
- Separate the three groups — stdlib / third-party / local — with blank lines (automated by `goimports`'s `-local` setting)
- Sort alphabetically within each group
- Use aliases only for collision avoidance (`pgsql "github.com/lib/pq"` is fine)

**Don't**
- No group separation
- Unnecessary aliases (`f "fmt"` / `io2 "io"`)

## 10. Type safety / nil safety

**Do**
- Use `interface{}` / `any` only when the type is genuinely undetermined (passthrough is fine)
- Guard against nil pointers by rejecting nil in the constructor

**Don't**
- `any` in business logic
- Mixing pointer and value receivers on one type (if there is a mutating method, all methods take a pointer receiver)
- Map assignment missing a nil check

## Identifying false positives

Even when a Don't matches, the following are not violations.

| Category | Judgment |
|---|---|
| Generated code | Files containing `Code generated by ... DO NOT EDIT.` at the top. Fix the source schema instead |
| Language / library idioms | Fixed signatures like `http.Handler`. These take precedence over this skill's rules |
| Deliberate design exceptions | Decisions whose intent is stated in code or docs (e.g. `context.Background()` inside a library to detach a shutdown context from a signal-aware ctx) |
| Public API compatibility | Exported symbols that can't change for backward compatibility. Propose a migration strategy, not a rename |

Excluding on suspicion alone is **forbidden**. Flag it as a "false positive candidate" and seek the user's judgment.

## Output

When called from `code-refactor-advisor`, return a per-section list of violations / improvement opportunities, each carrying:

- **Which Don't it matches** (with the section number)
- **A remediation stance** — align with the convention / keep as an exception / discuss separately
