---
name: go-style
description: Reference skill for Go idioms, naming, error handling, context, logging, concurrency, and lint/format conventions. Consulted for questions like 「Go お作法的にどう」「命名規約」「error wrap」 or during code review. Not a procedural skill.
---

> **Source of truth:** `claude/ja/skills/go-style/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# go-style

The house Go conventions, plus detection signals for catching violations mechanically. Consulted as the basis for judgment during implementation / review / refactor candidate generation.

**General Go practice is not restated here** (errors are values / ctx is the first argument / the sender closes the channel / wrap with `fmt.Errorf("%w")`, etc.) — this skill carries only the house's choices and the signals that let you notice via grep when one is broken.

## 1. Package layout

- `cmd/<bin>/main.go` is the binary entry point. One binary = one subdirectory
- Implementation goes under `internal/` by default. `pkg/` is **only for what is meant to be imported externally** (if reuse isn't expected, use `internal/`)
- `apis/` separates the proto / OpenAPI / SDK public surface
- With DDD + Clean Architecture, use `internal/{domain,application,interfaces,adapters}/` (`ddd-clean-architecture` is the SoT for layer boundaries)
- One package = one responsibility. Catch-all packages named `util` / `common` / `helper` are an anti-pattern

**Detect**: multiple responsibilities living in `internal/util/` / business logic inside `cmd/` / `pkg/` in use with no actual external importer

## 2. Naming

- exported vs unexported is decided solely by **whether it needs to be public now** (don't capitalize for "we might publish it later")
- **Acronyms stay fully capitalized**: both 3+ letters (`URL` `ID` `HTTP` `API`) and 2 letters (`AI` `IO` `UI` `OS` `DB`). Trademarks and generalized spellings follow their standard form (`OpenAI` / `OpenAPI` / `gRPC`). **When a trademark leads an unexported identifier, lowercase the trademark portion too** (`openaiKey` / `openapiSpec` — a case mix inside the acronym like `openAIKey` is wrong)
- Receiver names are **the same short name across every method of a type** (`s *Server`). `this` / `self` are forbidden
- Single-method interfaces take the `-er` suffix; multi-method ones are nouns
- Enum values are prefixed with the type name (`type Model string` + `ModelTextEmbedding3Large Model = "..."`)
- **Consolidate constants**: extract magic numbers and repeated literals (string keys / thresholds / timeouts / URL paths) into named consts (excluding trivial `0` / `1` / `""`). Group related constants into one const block rather than scattering them across the file / package

**Detect**: bare numeric literals in expressions / the same string literal appearing 2+ times / constants of the same kind scattered across multiple const declarations / mixed-case acronyms like `Url` `Id` `Http` `Ai` `Io` `Ui` / case mixes like `openAIKey` / a receiver named `this *X` / receiver names for one type varying by file / symbols exported only "in case we publish it later"

## 3. Error handling

- Sentinel errors are package-level `var Err... = errors.New("pkg: human message")`. Prefixing the message with `package:` makes the wrap chain easier to read
- **Separate the sanitized outward-facing message from the internal wrap chain at API boundaries.** Don't leak upstream details to clients; emit internal details via the logger
- panic is only for truly exceptional states (invariant violations at startup). Not in normal flow

**Detect**: `errors.New(fmt.Sprintf(...))` / string comparison of errors (`err.Error() == "..."`) / upstream SDK errors leaking into a handler's or gRPC server's error response / panic or `log.Fatal` outside `cmd/`

## 4. Context

- `ctx.Value` is only for cross-cutting metadata (request_id / trace span / auth principal). Anything that can be passed as an argument is passed as an argument
- Avoid ctx key collisions with a **package-private struct type** (`type requestIDKey struct{}`)

**Detect**: `context.Background()` inside a library / `ctx.Value("string-key")` (a collision-prone string key) / `ctx context.Context` as a struct field / ctx placed last or in the middle of the argument list

## 5. Logging

- Adopt the standard `log/slog`; structured JSON is recommended (`slog.NewJSONHandler`)
- Levels: `Error` (action required) / `Warn` (abnormal but continuing) / `Info` (normal operation) / `Debug` (development only)
- Pass ctx via `LogAttrs(ctx, ...)` so interceptors / middleware can attach span and request_id
- **Log messages are fixed strings; variable values go in attrs** (controls cardinality and stays greppable). **Never log PII or credentials**

**Detect**: operational logs emitted via `fmt.Println` / `log.Print*` / interpolated messages like `slog.Info(fmt.Sprintf(...))` / API keys, passwords, or personal identifiers in a log message

## 6. Concurrency

- **Make explicit what a mutex protects** (a comment right before the struct field, or the protected fields listed right after `mu sync.Mutex`)
- Restrict channel direction in function signatures (`<-chan T` / `chan<- T`)
- Prefer `errgroup.Group` for running multiple IO operations concurrently (context-linked cancellation + capture of the first error)

**Detect**: a goroutine that observes neither `ctx.Done()` nor a channel receive (leak candidate) / a `mu sync.Mutex` with no stated protection target / bidirectional `chan T` in a signature / a panic inside a goroutine with no defer-recover

## 7. Lint / format

- `golangci-lint` **v2** (configured via `.golangci.yaml`). Required in CI
- **Set `goimports`'s local prefix to each repo's module path**
- Recommended linters: `errcheck` / `govet` / `staticcheck` / `ineffassign` / `unused` / `gosimple` / `gofmt` / `goimports`
- `// nolint:` **requires a reason comment** (`// nolint:errcheck // intentional fire-and-forget`)

**Detect**: `// nolint:` with no reason / import order mixing stdlib, third-party, and local / an error return discarded into `_`

## 8. godoc / Comments

- Exported symbols require godoc. The package comment goes in one file per package as `// Package <name> ...`
- **Comments say WHY; the code says WHAT**
- **Doc comments on unexported symbols are not required** — if written, WHY only, 1-3 lines. Don't habitually attach a verbatim restatement of the code below (**don't copy the neighboring code even if it does this** — earlier output may have drifted from the conventions)
- "We want to do X later" goes in a `TODO:`. **Never leave Phase / ticket IDs in comments**
- `Deprecated:` is stated explicitly in the target symbol's godoc

**Detect**: exported symbols without godoc / comments that only restate WHAT / mechanically attached WHAT-explaining doc blocks on unexported methods (4+ lines especially) / timeline or ticket-scope references like `Phase 0`

## 9. Import order

Separate the three groups — stdlib / third-party / local (current module) — with blank lines (automated by `goimports`'s `-local` setting). Alphabetical within each group. **Aliases only when necessary** (collision avoidance only; `pgsql "github.com/lib/pq"` is fine, `f "fmt"` is not).

**Detect**: no group separation / unnecessary aliases (`io2 "io"`)

## 10. Type safety / nil safety

- `interface{}` / `any` only when the type is genuinely undetermined (passthrough is fine)
- Guard against nil pointers by **rejecting nil in the constructor**
- **Never mix pointer and value receivers on one type** (if there is a mutating method, all methods take a pointer receiver)

**Detect**: `any` in business logic / mixed receivers on the same type / map assignment missing a nil check

## Identifying false positives

The following are **not violations** even when a detection signal fires:

- **Generated code**: files containing `Code generated by ... DO NOT EDIT.` at the top. Fix the source schema instead (don't hand-edit generated Go)
- **Language / library idioms**: fixed signatures like `http.Handler`, named returns with defer-recover, etc. These take precedence over this skill's rules
- **Deliberate design exceptions**: decisions whose intent is stated in code or docs (e.g. `context.Background()` inside a library to detach a shutdown context from a signal-aware ctx)
- **Public API compatibility**: exported symbols that can't change for backward compatibility (propose a migration strategy rather than a rename)

When in doubt, don't exclude it — flag it as a "false positive candidate" and seek the user's judgment.

## Output

When called from `code-refactor-advisor`, return a per-section list of violations / improvement opportunities, each with the **detection signal** (which pattern caught it), the **section number** it's based on, and a remediation stance (align with the convention / keep as an exception / discuss separately).
