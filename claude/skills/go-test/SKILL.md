---
name: go-test
description: The house conventions for Go tests. Covers naming, table-driven tests, t.Parallel, the race detector, fakes/mocks, boundary values, and how to interpret coverage. A reference, not a procedural skill.
when_to_use: When a question like 「test 名どうする」「table-driven にする」「coverage 何 % まで」 comes up. When reviewing test code or designing additional tests. Referenced from `code-refactor-advisor` / `go-feature-tdd`.
---

> **Source of truth:** `claude/ja/skills/go-test/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# go-test

The house conventions for Go tests, plus detection signals. Consulted as the basis for judgment during implementation / review / refactor candidate generation.

**General knowledge is not restated here** (the difference between black-box and white-box, what equivalence partitioning is, etc.) — this skill carries only the house's choices and the signals that let you notice via grep.

## 1. Naming

- Function names are **intent-based** (`TestX_RejectsEmpty` / `TestX_When_..._Should_...`). Index-based names like `TestX1` are forbidden
- Table-driven case names carry intent too (`{name: "EmptyProductID"}`; `case1` is not acceptable)
- **No spaces or special characters in sub-test names** (`t.Run("foo bar")` normalizes to `foo_bar` and becomes hard to grep)
- Helpers take an intent-revealing prefix (`newFixture(t)` / `newAdapterWithFake(t, fake)`)

**Detect**: **explanatory inline comments inside a test** (= the intent isn't carried by the test / variable names) / index-based case names / `t.Run` names containing spaces

## 2. Table-driven test

The house's standard shape:

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

- Keep struct fields to the minimum (if a value is the same in every case, put it in a constant outside the struct)
- `wantErr` holds a **sentinel error** verifiable with `errors.Is`. **String comparison is forbidden**
- State `wantErr: nil` explicitly when expecting no error (it works when omitted, but the intent doesn't carry)

**Detect**: a table-driven test with only one case (a plain test func suffices) / half or more of the struct fields empty or identical (over-structured) / `wantErr string` compared as a string

## 3. `t.Parallel()`

- **Enable it by default** (shorter wall time + more effective race detection)
- Go 1.22+ scopes the loop variable per iteration, resolving the capture trap, but **if CI may run an older Go, binding a local `tc := tc` is safer**
- Don't call it in tests that touch global state or depend on ordering

**Detect**: a table-driven test where not every case calls `t.Parallel()` / referencing the outer loop variable without binding / calling `t.Parallel()` while touching global state (flaky)

## 4. `t.Helper()`

Always call it at the top of a helper that calls `t.Errorf` / `t.Fatal` (failure line reporting then points at the caller). Not needed for pure data-construction helpers.

**Detect**: a helper calling `t.Errorf` / `t.Fatal` without `t.Helper()`

## 5. Setup / Teardown

- Register resource cleanup **inline with `t.Cleanup()`**
- Consolidate shared fixtures into a helper constructor (`newFixture(t)`) that registers `t.Cleanup` internally
- **When per-case setup lives in a struct field, name it `beforeFunc` / `afterFunc`** (don't use the words `setup` / `teardown`)
- **The struct-field approach itself is not the default** (boilerplate / closure capture traps / poor fit with `t.Parallel()`). Add `beforeFunc` only when cases genuinely need different setup (`afterFunc` is usually unnecessary — `t.Cleanup` inside `beforeFunc` covers it)

**Detect**: cleanup done only with `defer cleanup()` (it doesn't run when the whole test fails) / struct fields named `setup` / `teardown` / every case carrying the same setup function (should be extracted to a shared helper)

## 6. Race detector

- **Always on** (include `-race` in `make test`). Data races in concurrent code can't be found statically, so running it continuously in CI is worth a lot
- The cost is ~10x slower and 5-10x more memory, which is not a concern at unit-test scale
- **Benchmarks can't be measured meaningfully with race on** → run them separately. To opt out exceptionally, use a build tag (`//go:build !race`)

**Detect**: CI / Makefile defaulting to plain `go test` (no race) / running `go test -bench` with `-race`

## 7. Test design

- **black-box** (`package x_test`) verifies the API contract; **white-box** (`package x`) supplements implementation coverage. Both can coexist
- **Boundary values**: deliberately cover off-by-one / upper and lower bounds / 0 / empty / nil / max / min (for `top_k`: 0 / 1 / the limit / limit+1 / negative)
- **Distinguish rune count from byte count explicitly for string boundaries**:
  - Go's `len(string)` is a **byte count**. Character count is `utf8.RuneCountInString` / `[]rune(s)`
  - A string API with a limit must decide which unit in the spec, and the tests must match
  - **Multi-byte characters (Japanese / emoji) are ~3-4 bytes per rune. With a byte limit, a boundary test using only multi-byte input is mandatory** (an ASCII-only boundary test misses it)
  - Strings with combining characters / variation selectors have rune count ≠ grapheme cluster count
- **One representative per equivalence class** suffices (for `query`: ASCII / multi-byte / emoji and combining characters / empty or whitespace-only / at the limit and limit+1)
- **Cover the rejection paths**: validation failure (boundary violations per field) / upstream dependency errors / context cancellation / permission and ACL violations
- Property-based testing (`testing/quick` / `rapid`) applies narrowly — pure functions / encoder-decoder roundtrips / order preservation. Value-based tests read better for business logic

**Detect**: only a HappyPath, with no rejection or boundary cases / a numeric field missing 0, the limit, and limit+1 / **no multi-byte string input test** (a latent bug that fails on Japanese queries)

## 8. Fake / Mock / Stub

**Prefer hand-written fakes. Don't use generation tools like testify / gomock / mockery** (minimal dependencies / the fake's behavior stays visible in source / avoids over-mocking). Keep interfaces narrow (the port pattern) and implement them with a small struct for tests.

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

**Detect**: a mock framework newly introduced / mock expectations that assert only call counts, leaving inputs and outputs unchecked

## 9. testdata / golden files

Put large inputs / expected outputs in `testdata/` (Go excludes it from builds automatically). Store golden files as `testdata/golden/<name>.json` and diff them in the test, refreshing them in bulk via a custom `-update` flag when the implementation changes.

**Detect**: a huge expected-value string inlined in test code

## 10. Test tiers / build tags

- **unit**: same package, no external IO, millisecond scale. Always run
- **integration**: connects to external dependencies. Separated by build tag (`//go:build integration`), run with `go test -tags=integration ./...`
- **E2E**: full startup + black-box. An outer directory such as `tests/e2e/` + a build tag

**Detect**: a test that connects to an external service over the network running under `go test ./...` (flaky / externally dependent) / a test doing external IO with no build tag

## 11. HTTP / gRPC test patterns

- **HTTP**: start an in-process server with `httptest.NewServer` and point the SDK's base URL at it. Assert on `r.URL` / `r.Body` inside the handler
- **gRPC**: stand up an in-memory listener with `bufconn.Listen` and wire the client via `grpc.WithContextDialer(bufDialer)` (when you also want to test interceptors; otherwise calling the handler method directly is fine)

**Detect**: an HTTP test binding a real TCP port (flaky / collides with parallel tests) / a gRPC test starting a real network listener

## 12. Time / Context determinism

Don't call `time.Now()` directly — inject `now func() time.Time` as a struct field or parameter and return a fixed value in tests. Inject the random seed as well, or localize `math/rand/v2`.

**Detect**: production code calling `time.Now()` directly / random or UUID generation coming from global state

## 13. Interpreting coverage

Line coverage is a guide rail — **don't worship it**. Weight branch / boundary / important paths, and judge **against the DoD** (write tests that satisfy the functional contract rather than chasing 100% internally). Chasing 100% produces artificial tests with no assertions. As a rough target: 80%+ for business logic / handlers / adapters; generated code and main are out of scope.

**Detect**: assertion-free tests written only to raise coverage / coverage earned from HappyPath alone while the rejection paths go untested

## 14. Avoiding flakiness

Main causes and remedies: **time-based** (`time.Sleep` waits / implicit `time.Now()` dependence → fix by injection) / **ordering** (dependence on map iteration order → convert to a sorted slice before asserting) / **net IO** (binding a real port → httptest, bufconn) / **goroutine races** (wait for termination in `t.Cleanup` / sync via channel close) / **shared state** (mutating globals under `t.Parallel()` → move to test-local state).

**Detect**: `time.Sleep` inside a test / order-sensitive comparison of map iteration results / goroutines surviving after the test ends

## Identifying false positives

The following are **not violations** even when a detection signal fires:

- **Generated code**: files containing `Code generated by ... DO NOT EDIT.` at the top (fix the source schema instead)
- **Language / library idioms**: fixed signatures and the like. These take precedence over this skill's rules
- **Deliberate design exceptions**: decisions whose intent is stated in code or docs
- **Public API compatibility**: exported symbols that can't change for backward compatibility

When in doubt, don't exclude it — flag it as a "false positive candidate" and seek the user's judgment.

## Output

When called from `code-refactor-advisor`, return a per-section list of violations / improvement opportunities, each with its **detection signal**, the **section number** it's based on, and a remediation stance (convert to table-driven / switch to a fake / move to a golden file / add boundary cases, etc.).
