---
name: go-style
description: Reference skill for Go idioms, naming, error handling, context, logging, concurrency, and lint/format conventions. Consulted for questions like 「Go お作法的にどう」「命名規約」「error wrap」 or during code review. Not a procedural skill.
---

> **Source of truth:** `claude/ja/skills/go-style/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# go-style

A reference skill collecting Go idioms and conventions. Used as the judgment criteria for implementation, review, and identifying refactor candidates.

## Applicability

- Any context involving Go code (`*.go` / `Makefile` / Go code generated from `*.proto`)
- Referenced by the code-refactor-advisor agent
- When the user asks things like 「Go 的にどう書く」「命名どうする」

## 1. Package layout

- Binary entry points live at `cmd/<bin>/main.go`. One binary = one subdirectory.
- Code under `internal/` cannot be imported from other repositories. Implementation generally lives here.
- `pkg/` is only for code intended to be imported externally. If there's no expected reuse, put it under `internal/`.
- When adopting DDD + Clean Architecture: `internal/{domain,application,interfaces,adapters}/` (see the `ddd-clean-architecture` skill for layer boundary details)
- Separate the proto / OpenAPI / SDK public surface into `apis/` (recommended convention)
- One package = one responsibility. Catch-all packages like `util` / `common` / `helper` are an anti-pattern.

Detection signals:
- Functions with multiple, unrelated responsibilities coexisting under `internal/util/`
- Business logic living inside `cmd/`
- `pkg/` is used but there is no actual external import

## 2. Naming

- Decide exported (starts with an uppercase letter) vs. unexported (starts with a lowercase letter) based solely on **whether it needs to be public**. Don't capitalize just because "it might be made public someday."
- Acronyms are **kept fully uppercase**:
  - 3+ letters: `URL` `ID` `HTTP` `API` (`Url` / `Id` / `Http` are not allowed)
  - 2 letters: `AI` / `IO` / `UI` / `OS` / `DB` are also fully uppercase (`Ai` / `Io` / `Ui` are not allowed)
  - Brand names / conventionalized spellings containing multiple acronyms: follow the standard spelling, e.g. `OpenAI` / `OpenAPI` / `gRPC`
  - When a brand name appears at the start of an unexported identifier: lowercase the brand-name part too, to stay consistent with the acronym rule (`openaiKey` / `openapiSpec`). Mixed case inside an acronym, like `openAIKey`, is not allowed.
- Receiver names: **use the same short name across all methods for the same type** (`s *Server` / `c *Client`). `this` / `self` are forbidden.
- Interface names: use an `-er` suffix for single-method interfaces (`Reader` / `Writer`). Use a noun for multi-method interfaces (`FileSystem`).
- Error types/variables get an `Err` / `err` prefix (`var ErrNotFound = ...` / `func ... (err error)`)
- Enum values get the type name as a prefix (`type Model string` + `ModelTextEmbedding3Large Model = "..."`)
- Test names should be intent-based, like `TestX_When_..._Should_...` or `TestX_RejectsEmpty` (see the `go-test` skill for details)
- **Consolidate constants**: extract magic numbers / repeatedly appearing literals (string keys / thresholds / timeouts / URL paths, etc.) into named consts (excluding self-evident zero values `0` / `1` / `""`). Declare related constants together in a single const block instead of scattering them across the file / package. Align value sets with typed const blocks (the enum rule above)

Detection signals:
- A bare numeric literal in an expression (timeout / limit / size, etc.) / the same string literal appearing 2 or more times / constants of the same kind scattered across multiple const declarations
- Mixed-case acronyms such as `Url` / `Id` / `Http` / `Ai` / `Io` / `Ui`
- Case mixing between a brand-name acronym and other characters, like `openAIKey` (when using a brand name at the start of an unexported identifier, lowercase it to something like `openaiKey`)
- Receiver is `this *X` / `self *X`
- Receiver names varying by file for a single type, e.g. `s`, `srv`, `server`
- A symbol made exported solely because "it might be made public someday"

## 3. Error handling

- An error is a **value**. It's the last return value; don't omit `if err != nil { return ..., err }`.
- Use `fmt.Errorf("context: %w", err)` for wrapping. Keep errors matchable via `errors.Is` / `errors.As` for sentinel/typed checks.
- Sentinel errors are package-level `var Err... = errors.New("pkg: human message")`. Prefixing the message with `package:` makes the wrap chain easier to read.
- Don't distinguish errors by string comparison (`err.Error() == "..."` is forbidden).
- Use panic **only for truly exceptional states** (e.g., invariant violations at program startup). Don't use it in normal flow.
- Error messages **start lowercase, with no trailing period** (`io: short read`, not "Io: short read.")
- For wrapped chains, **separate the "sanitized outward-facing message" at API boundaries from the "internal wrap chain."** Don't leak upstream details to clients (emit internal details via the logger instead).

Detection signals:
- `errors.New(fmt.Sprintf(...))` (should use `fmt.Errorf` instead)
- String comparison of errors
- Upstream SDK errors leaking into a handler's / gRPC server's error response
- panic / `log.Fatal` present in library code (outside `cmd/`)

## 4. Context

- `context.Context` is **the first function argument**. Use the unified name `ctx context.Context`.
- Don't store ctx in a struct field (this mixes request scope with struct lifetime).
- Propagate ctx explicitly (pass it through function calls; no implicit globals).
- `context.Background()` is only for entry points (main / test / signal handler). Inside libraries, use the caller's ctx.
- `ctx.Value` is only for cross-cutting metadata (request_id / trace span / auth principal). Pass anything that can be passed as an argument as an argument.
- Avoid collisions on ctx keys by using a **package-private struct type** (`type requestIDKey struct{}`).
- For cancellation/deadlines, have the library side observe `<-ctx.Done()`, and unblock long IO with `select`.

Detection signals:
- `context.Background()` called inside a library
- `ctx.Value("string-key")` (a string key with collision risk)
- `ctx context.Context` as a struct field
- ctx placed last or in the middle of the argument list

## 5. Logging

- Adopt the standard `log/slog`. Structured JSON is recommended (`slog.NewJSONHandler`).
- Level usage: `Error` (action required) / `Warn` (abnormal but processing continues) / `Info` (normal operation) / `Debug` (development only)
- Structure with key-value pairs: `slog.String("key", "value")` / `slog.Int(...)` / `slog.Duration(...)`
- Pass ctx via `LogAttrs(ctx, ...)` so interceptors/middleware can attach span / request_id.
- **Don't log PII / credentials** (API key / password / token / personal identifier).
- Log messages should be fixed strings; pass variable values as attrs (controls cardinality and keeps things greppable).
- In error logs, also emit the root cause of the wrap chain as an attr (`slog.String("error", err.Error())`).

Detection signals:
- Operational logs emitted via `fmt.Println` / `log.Print*` (standard `log` or `fmt`)
- Interpolated messages like `slog.Info(fmt.Sprintf("user %s logged in", userID))`
- API key / password / personal identifiers mixed into a log message

## 6. Concurrency

- A goroutine **must always have a guaranteed exit path** (cancellation / done channel / WaitGroup / errgroup).
- Typical causes of goroutine leaks: a blocked send/recv on an unbuffered channel, forgetting to observe ctx, forgetting `g.Wait()` on an errgroup.
- **Make explicit what a mutex protects** (a comment right before the struct field, or list the protected fields right after `mu sync.Mutex`).
- **The sender closes the channel.** The receiver closing it is forbidden (panic / race risk).
- Restrict channel direction in function signatures (`<-chan T` / `chan<- T`).
- `errgroup.Group` provides context-linked cancellation, captures the first error, and syncs via `g.Wait()`. Recommended for running multiple IO operations concurrently.
- `sync.Once` is for initialization use. For state needed multiple times, use a different pattern (mutex / atomic).
- Minimize shared mutable state; where possible, use immutable copies + channel passing.

Detection signals:
- A goroutine that observes neither `ctx.Done()` nor a channel receive (a leak candidate)
- A mutex whose protected target is unclear (just `mu sync.Mutex` with nothing else)
- Channel direction written as bidirectional (`chan T`) in a signature
- A panic inside a goroutine not recovered via defer (crashes the entire parent goroutine)

## 7. Lint / format

- Enforce `gofmt` / `goimports` (set `goimports`'s local prefix to match each repository's module path).
- Use `golangci-lint` v2 (configured via `.golangci.yaml`). Required in CI.
- Recommended linters: `errcheck` / `govet` / `staticcheck` / `ineffassign` / `unused` / `gosimple` / `gofmt` / `goimports`
- Suppressions (`// nolint:`) **require a reason comment** (`// nolint:errcheck // intentional fire-and-forget`).
- Auto-fixable issues should be fixed locally before CI (`gofmt -w` / `goimports -w` / `golangci-lint run --fix`).

Detection signals:
- `// nolint:` with no reason
- Import order mixing stdlib / third-party / local
- Ignored `errcheck` warnings (discarding an error return value into `_`; add `// intentional` if needed)

## 8. godoc / Comments

- Exported symbols require godoc (a sentence starting with the symbol name, `// FuncName ...`).
- Package comments go in one file per package as `// Package <name> ...` (usually `doc.go` or the main file).
- Comments should **explain WHY**. The WHAT is told by the code itself (assuming well-named identifiers).
- A doc comment on an unexported symbol is not required — if you write one, keep it to 1-3 lines of WHY only. Don't habitually attach a block that transliterates the code right below it (don't imitate adjacent code that does this — a past generated artifact may have drifted from the conventions).
- "Want to do X in the future" goes in a `TODO:`. Don't leave phase names or ticket IDs in comments.
- Mark `Deprecated:` explicitly in the target symbol's godoc (`// Deprecated: use NewX instead.`)
- Prefer line comments (`//`) over multi-line block comments.

Detection signals:
- An exported func / type / var with no godoc
- A comment that only states the WHAT (merely translating the code)
- A doc block of WHAT explanations mechanically attached to an unexported method (be especially suspicious of blocks of 4 or more lines)
- A comment referencing timeline/ticket scope, such as `Phase 0` or a release-cycle-named ticket

## 9. Import order

```go
import (
    // Group 1: standard library
    "context"
    "fmt"

    // Group 2: third-party
    "github.com/spf13/cobra"

    // Group 3: local (current module)
    "github.com/<org>/<module>/internal/foo"
)
```

- Separate the three groups with blank lines (automatic via goimports's `-local` setting).
- Alphabetical sort within each group.
- Aliases should be **kept to the minimum necessary** (only for collision avoidance / abbreviation purposes). `pgsql "github.com/lib/pq"` is fine, `f "fmt"` is not.

Detection signals:
- No group separation (everything mixed into a single import block)
- Unnecessary aliases (e.g., `io2 "io"`)

## 10. Type safety / nil safety

- Use `interface{}` / `any` only when the type is genuinely indeterminate. If the type is known, use an explicit type.
- Guard against nil pointer dereferences by **rejecting nil in the constructor** (`func NewX(...) (*X, error) { if ... == nil { return nil, ErrNil }`).
- Assigning to a nil map panics; appending to a nil slice is fine (don't confuse the two).
- Pointer receivers and value receivers **must not be mixed** (be consistent for a given type; if any method mutates, all methods should use pointer receivers).

Detection signals:
- `any` / `interface{}` used in business logic (fine if it's a passthrough)
- Pointer receiver and value receiver mixed for the same type
- A map assignment missing a nil check

---

## False positive criteria

Even if a detection signal from this skill fires, do **not** treat it as a violation when any of the following apply:

- **Originates from generated code**: symbols/files generated by protoc / buf / openapi-generator / `go generate`, etc. (typically identified by a `Code generated by ... DO NOT EDIT.` line at the top of the file). Improvements belong on the source schema side; don't hand-edit generated Go code.
- **Language/library idiomatic patterns**: things like `func(...) (resp any, err error)` with named returns + defer-recover, fixed signatures like `http.Handler`, or the convention of taking `context.Context` as the first argument take priority over this skill's rules.
- **Intentional design exceptions**: design decisions whose intent is explicitly documented in code/docs (e.g., using `context.Background()` inside a library to detach a shutdown context from a signal-aware ctx).
- **Public API compatibility**: exported symbols that can't be changed for backward compatibility (prefer proposing a migration strategy over a rename).

When in doubt, don't exclude it — flag it in the output as a "false positive candidate" and defer to the user's judgment.

## What this skill should output

When invoked by the code-refactor-advisor agent, this skill is expected to provide:
- A **list of violations / improvement opportunities, organized by section**, for the target code
- For each finding, the **detection signal** (which pattern triggered it) and the **supporting section** (the section number within this skill)
- A remediation approach (align with convention / leave as an intentional exception / discuss separately)

## References

- Go Code Review Comments: https://go.dev/wiki/CodeReviewComments
- Effective Go: https://go.dev/doc/effective_go
- Go Proverbs: https://go-proverbs.github.io/
- Uber Go Style Guide: https://github.com/uber-go/guide/blob/master/style.md
