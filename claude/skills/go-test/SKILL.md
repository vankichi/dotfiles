---
name: go-test
description: Reference skill for Go test design and test-code idioms. Covers naming, table-driven tests, t.Parallel, the race detector, fakes/mocks, boundary values, and how to interpret coverage. Consulted for questions like 「test 名どうする」「table-driven にする」「coverage 何 % まで」. Not a procedural skill.
---

> **Source of truth:** `claude/ja/skills/go-test/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# go-test

A reference skill collecting Go test design and test-code idioms. Used as the judgment criteria for implementation, review, and identifying refactor candidates.

## Applicability

- Any context involving Go test code (`*_test.go`)
- Referenced by the code-refactor-advisor agent
- When the user asks things like 「test 何書く / どう書く」

## 1. Naming

- Function names are **intent-based** (`TestX_RejectsEmpty` / `TestX_When_..._Should_...`). Index-based names like `TestX1`, `TestX2` are forbidden.
- Table-driven case names **must convey intent** (`{name: "EmptyProductID", ...}`; simply `{name: "case1"}` is not allowed).
- Don't put spaces / special characters in sub-test names (`t.Run("foo bar")` gets normalized to `foo_bar`, which is hard to grep for).
- Helper naming: use a prefix that **conveys intent** (`new` / `make`), like `newFixture(t)` / `newAdapterWithFake(t, fake)`.

Detection signals:
- An explanatory inline comment inside a test (meaning the test name / variable names fail to convey intent)
- Case names that are index-based, like `case1`, `case2`
- Names like `t.Run("with spaces")`

## 2. Table-driven test

```go
tests := []struct {
    name    string
    input   X
    want    Y
    wantErr error
}{
    {name: "HappyPath", input: ..., want: ...},
    {name: "RejectsEmpty", input: X{}, wantErr: ErrEmpty},
}

for _, tc := range tests {
    t.Run(tc.name, func(t *testing.T) {
        t.Parallel()
        got, err := SUT(tc.input)
        if !errors.Is(err, tc.wantErr) {
            t.Fatalf("err = %v, want %v", err, tc.wantErr)
        }
        if tc.wantErr != nil { return }
        if !reflect.DeepEqual(got, tc.want) {
            t.Fatalf("got = %v, want %v", got, tc.want)
        }
    })
}
```

- Struct fields should be **kept to the minimum necessary**. If a value is the same across all cases, pull it out as a constant outside the struct.
- Put a **sentinel error** (verifiable via `errors.Is`) in `wantErr`. String comparison is forbidden.
- When expecting no error, state `wantErr: nil` explicitly (omitting it still works, but doesn't convey intent).

Detection signals:
- A table-driven test with only one case (a regular test function would suffice)
- More than half the struct fields are empty / the same value (the struct is overengineered)
- String comparison via `wantErr string`

## 3. `t.Parallel()`

- **Enabling it by default is recommended.** It shortens overall test wall time and increases the effectiveness of the race detector.
- Inside table-driven `t.Run(tc.name, func(t *testing.T) { t.Parallel(); ... })`, **be careful about capturing `tc` inside the closure**:
  ```go
  for _, tc := range tests {
      tc := tc  // unnecessary on Go 1.22+, but required on <= 1.21
      t.Run(tc.name, func(t *testing.T) {
          t.Parallel()
          ...
      })
  }
  ```
  From Go 1.22+, for-loop variable scope became per-iteration, which resolved the capture trap, but if CI might run on an older Go version, explicitly localizing the variable is the safe choice.
- Tests that can't run in parallel (touching global state / order-dependent) should not call `t.Parallel()`.
- Tests that call `t.Parallel()` run concurrently with each other; tests that don't call it run sequentially after the parallel tests complete.

Detection signals:
- Not all cases in a table-driven test call `t.Parallel()` (wasting wall time)
- Referencing the outer loop variable without binding `tc` in the closure capture (a bug on older Go)
- Calling `t.Parallel()` while touching global state (race / flaky)

## 4. `t.Helper()`

- **Call `t.Helper()` at the top** of helper functions (assertions / fixture construction). This makes failure line reporting point to the caller, easing debugging.
- Not needed for pure data-generation helpers (if they never actually call `t.Errorf` / `t.Fatal`).

Detection signals:
- A helper that calls `t.Errorf` / `t.Fatal` without calling `t.Helper()`

## 5. Setup / Teardown

- Register resource cleanup **inline via `t.Cleanup()`** (the Go 1.14+ idiom).
- Consolidate common fixtures into a helper constructor (`newFixture(t)`), registering `t.Cleanup` internally.
- When a struct field holds per-case setup for a table test, name it **`beforeFunc` / `afterFunc`** (don't use the words `setup` / `teardown`).
- The struct-field approach itself is discouraged by default (boilerplate / closure-capture pitfalls / poor compatibility with `t.Parallel()`).
- Exception: only add `beforeFunc` as a struct field when each case genuinely needs different setup. `afterFunc` is usually omitted (it's covered by `t.Cleanup` inside `beforeFunc`); include it only when needed.

Example:
```go
tests := []struct {
    name       string
    beforeFunc func(t *testing.T) *Fixture
    want       Result
}{
    {
        name: "EmptyDB",
        beforeFunc: func(t *testing.T) *Fixture {
            return newFixture(t)
        },
        want: Result{...},
    },
}
```

Detection signals:
- Cleanup done solely via `defer cleanup()` (won't run if the whole test fails outright; `t.Cleanup` is safer)
- Struct field names of `setup` / `teardown` (recommendation is `beforeFunc` / `afterFunc`; defer to project convention if one exists)
- The same setup function attached to every case (should be extracted into a common helper)

## 6. Race detector

- **Always on.** Run with `go test -race` (e.g., always-on via including `-race` in `make test`).
- Data races in concurrent code can't be detected via static analysis; running it constantly in CI has high value.
- Cost: ~10x slower + ~5-10x more memory. Not a concern at unit-test scale.
- Benchmarks (`go test -bench`) can't produce meaningful measurements with race enabled → run separately.
- If you exceptionally need to exclude race, use a build tag (`//go:build !race`).

Detection signals:
- CI / Makefile defaulting to plain `go test` (i.e., no race)
- Running `go test -bench` with `-race` (measurement becomes meaningless)

## 7. Test design technique

### Black-box vs White-box

- **Black-box**: verifies the input → output contract without depending on internal implementation. Writing it as `package x_test` (an external test package) lets you test using only the public API, without touching implementation symbols.
- **White-box**: intentionally exercises branches / internal state. Written as `package x` (the same package), touching unexported symbols.
- **When to use which**: use black-box for testing the API contract, white-box to fill in implementation coverage. Both can coexist.

### Boundary value analysis

- Intentionally test off-by-one, upper/lower bounds, 0, empty, nil, max, min.
- Example: for a `top_k` field, test 0 / 1 / the upper bound / upper bound + 1 / negative numbers / large numbers.
- **For string boundaries, make rune count vs. byte count explicit**:
  - Go's `len(string)` is a **byte count**; the character count (rune count) comes from `utf8.RuneCountInString` / `[]rune(s)`.
  - For string APIs with an upper bound, the spec should decide which unit applies, and tests should match that.
  - Multi-byte characters (Japanese / emoji) are roughly 1 rune ≈ 3-4 bytes. For a byte-based upper bound, **a boundary test using only multi-byte characters is mandatory** (a boundary test using only ASCII leaves a verification gap).
  - Strings containing combining characters / variation selectors have rune count ≠ grapheme cluster count. APIs that operate at the grapheme level should separately use something like `golang.org/x/text/unicode/norm`.

### Equivalence partitioning

- One representative test per equivalence class. Trade off completeness for representative values rather than aiming for full coverage.
- Example: for a `query` string — "ASCII," "multi-byte," "emoji / combining characters," "empty string / whitespace only," "max character count / +1."

### Negative test

- Cover **rejection paths**, not just the happy path:
  - validation failures (boundary violations for each field)
  - upstream dependency errors (provider unavailable / timeout)
  - context cancellation
  - permission / ACL violations

### Property-based test

- Use `testing/quick` (standard library) / `pgregory.net/rapid` (third-party) for property-based tests.
- Applicability is limited: effective for pure functions, decoder-encoder roundtrips, order preservation, etc.
- For business logic, value-based tests are more readable.

Detection signals:
- Only the happy path is tested; rejection / boundary cases are untested
- A numeric field like `top_k` missing tests for 0 / the upper bound / upper bound + 1
- No test for multi-byte string input (a latent bug that would fail on a Japanese query)

## 8. Choosing between Fake / Mock / Stub

- **Fake**: a working lightweight implementation (in-memory DB / in-memory adapter). Can reproduce behavior even for complex logic.
- **Stub**: just returns a fixed response. Input is ignored.
- **Mock**: validates input + asserts expected call counts (xUnit style).

Recommended approach (defer to project convention if one exists):
- **Hand-written fakes are recommended** (don't use generation tools like testify / gomock).
- Rationale: minimal dependencies / the fake's behavior is fully contained in source code / avoids over-mocking.
- Cut narrow interfaces (the port pattern), and implement them for tests with a concise struct.

Example (recommended pattern):
```go
type fakeVectorStore struct {
    searchCalls []vectorSearchCall
    respBy      map[string][]ports.VectorSearchResult
    err         error
}

func (f *fakeVectorStore) Search(_ context.Context, c string, req ports.VectorSearchRequest) ([]ports.VectorSearchResult, error) {
    f.searchCalls = append(f.searchCalls, vectorSearchCall{c, req})
    if f.err != nil { return nil, f.err }
    if r, ok := f.respBy[c]; ok { return r, nil }
    return nil, nil
}
```

Detection signals:
- A mock framework such as testify / gomock / mockery being newly introduced
- A mock's expectations only verifying "number of times called," leaving input/output unchecked

## 9. Test fixture / golden file / testdata

- Place large inputs / expected outputs in the `testdata/` directory (a Go idiom; excluded from the build).
- Golden file pattern: save expected output to something like `testdata/golden/<name>.json`, and diff it within the test.
  - Use an update flag (a custom flag like `-update`) to bulk-update when the implementation changes.
- Share fixtures under `testdata/fixtures/`, loaded via a test helper.

Detection signals:
- A huge expected-value string inline in test code (should be extracted into testdata)
- testdata not tagged with a build tag, or not excluded from the Go build (the directory name `testdata` is automatically excluded by Go)

## 10. Test categories / build tags

- **Unit test**: within the same package, no external IO, on the order of milliseconds. Runs always via `*_test.go`.
- **Integration test**: connects to external dependencies (DB / API), run as a separate stage in CI. Separated via a build tag:
  ```go
  //go:build integration

  package x_test
  ```
  Run with: `go test -tags=integration ./...`
- **E2E test**: full system startup + black-box. An outer directory like `tests/e2e/` + a build tag.

Detection signals:
- A test that connects directly over the network to Pinecone / OpenAI running as a unit test (`go test ./...`) (flaky / external dependency)
- A test doing external IO without a separate build tag

## 11. HTTP / gRPC test pattern

### HTTP

- Start an in-process server with `httptest.NewServer`, and point the SDK's base URL at it.
- Verify requests by asserting `r.URL` / `r.Body` inside the handler.
- Canned responses via `w.WriteHeader` + `w.Write([]byte(...))`.

### gRPC

- Use `bufconn.Listen` for an in-memory listener, and wire up the client with `grpc.NewClient(... grpc.WithContextDialer(bufDialer))`.
- If starting up the whole service is too heavy, calling the handler method directly is also fine (use bufconn if you also want to test interceptors).

Detection signals:
- An HTTP test binding an actual TCP port (flaky / conflicts with parallel tests)
- A gRPC test starting a real network listener

## 12. Time / Context determinism

- Don't call `time.Now()` directly; inject `now func() time.Time` as a struct field / parameter.
- In tests, fix it with `now: func() time.Time { return time.Date(2026, 5, 1, 0, 0, 0, 0, time.UTC) }`.
- Within tests, control ctx deadlines via `context.Background()` (entry point) or `context.WithTimeout`.
- Also inject the random seed / localize `math/rand/v2` to keep things deterministic.

Detection signals:
- Production code calling `time.Now()` directly (can't be fixed in tests)
- Random / UUID generation coming from global state (can't be made deterministic)

## 13. Interpreting coverage

- Line coverage is a guide rail — **don't treat it as gospel**.
- Emphasize branch coverage / boundary coverage / important paths.
- Aiming for 100% produces artificial tests (pointless tests just to eliminate `if false { ... }`).
- DoD-based: write tests that satisfy the functional contract (acceptance criteria); don't aim for 100% internal coverage.
- Rule of thumb: business logic / handlers / adapters should be 80%+; generated code / `main` are excluded from coverage targets.

Detection signals:
- A test with no assertions, existing only to bump coverage
- Coverage padded out by only the handler/service's happy path, while rejection paths are untested

## 14. Avoiding flakiness

Main causes of flakiness:
- **time-based**: waiting via `time.Sleep`, implicit dependence on `time.Now()` → fix via injection
- **ordering**: dependence on map iteration order → convert to a sorted slice before asserting
- **net IO**: binding an actual port → use httptest / bufconn
- **goroutine race**: wait for all goroutines to finish via `t.Cleanup`, sync via channel close
- **shared state**: mutating a global / package var under `t.Parallel()` → switch to local state within the test

Detection signals:
- `time.Sleep` inside a test
- Comparing map iteration results as ordered (`reflect.DeepEqual([]Map, expectedSlice)` has no order guarantee)
- A goroutine still alive after the test ends

---

## False positive criteria

Even if a detection signal from this skill fires, do **not** treat it as a violation when any of the following apply:

- **Originates from generated code**: symbols/files generated by protoc / buf / openapi-generator / `go generate`, etc. (typically identified by a `Code generated by ... DO NOT EDIT.` line at the top of the file). Improvements belong on the source schema side; don't hand-edit generated Go code.
- **Language/library idiomatic patterns**: things like `func(...) (resp any, err error)` with named returns + defer-recover, fixed signatures like `http.Handler`, or the convention of taking `context.Context` as the first argument take priority over this skill's rules.
- **Intentional design exceptions**: design decisions whose intent is explicitly documented in code/docs (e.g., using `context.Background()` inside a library to detach a shutdown context from a signal-aware ctx).
- **Public API compatibility**: exported symbols that can't be changed for backward compatibility (prefer proposing a migration strategy over a rename).

When in doubt, don't exclude it — flag it in the output as a "false positive candidate" and defer to the user's judgment.

## What this skill should output

When invoked by the code-refactor-advisor agent:
- A **list of violations / improvement opportunities, organized by section**, for the target test code
- Each finding's **detection signal** + **supporting section number**
- A remediation approach (convert to table-driven / switch to fakes / adopt golden files / add boundary cases / etc.)

## References

- Go testing package doc: https://pkg.go.dev/testing
- Go Code Review Comments (Tests section): https://go.dev/wiki/CodeReviewComments
- Effective Go (Test section): https://go.dev/doc/effective_go
- Subtests and sub-benchmarks: https://go.dev/blog/subtests
