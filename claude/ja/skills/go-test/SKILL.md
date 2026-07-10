---
name: go-test
description: Go の test design / test code 慣用句の reference skill。命名 / table-driven / t.Parallel / race detector / fake・mock / boundary value / coverage 解釈を扱う。「test 名どうする」「table-driven にする」「coverage 何 % まで」等の問いで参照する。手順 skill ではない。
---

# go-test

Go の test design / test code 慣用句を集めた reference skill。実装 / review / refactor 候補出しの判断基準として参照する。

## 適用条件

- Go の test code (`*_test.go`) を扱う任意の場面
- code-refactor-advisor agent からの参照
- ユーザーが「test 何書く / どう書く」を尋ねる場面

## 1. 命名

- 関数名は **意図ベース** (`TestX_RejectsEmpty` / `TestX_When_..._Should_...`)。`TestX1` `TestX2` のような index ベースは禁止
- table-driven の case 名は **意図を含む** (`{name: "EmptyProductID", ...}` / 単に `{name: "case1"}` は NG)
- sub-test 名にスペース / 特殊文字を入れない (`t.Run("foo bar")` は `foo_bar` に正規化される、grep しにくい)
- Helper 命名: `newFixture(t)` / `newAdapterWithFake(t, fake)` のように **意図を表す** prefix (`new` / `make`)

検出シグナル:
- test 内に説明 inline コメントがある (= test 名 / 変数名で意図を表現できていない)
- case 名が `case1` `case2` のように index ベース
- `t.Run("with spaces")` のような名前

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

- struct field は **必要最小限**。全 case で同じ値なら struct 外に定数で
- `wantErr` は **sentinel error** (errors.Is 検証可能) を入れる。文字列比較は禁止
- nil error 期待は `wantErr: nil` を明示 (省略でも動くが意図が伝わらない)

検出シグナル:
- table-driven で 1 case しかない (= 通常の test func で十分)
- struct field の半数以上が空値 / 同じ値 (= struct 過剰)
- `wantErr string` で文字列比較

## 3. `t.Parallel()`

- **デフォルトで有効化推奨**。test 全体の wall time 短縮 + race detector 効果増
- table-driven 内の `t.Run(tc.name, func(t *testing.T) { t.Parallel(); ... })` で **closure 内 tc capture に注意**:
  ```go
  for _, tc := range tests {
      tc := tc  // Go 1.22+ は不要だが <= 1.21 なら必須
      t.Run(tc.name, func(t *testing.T) {
          t.Parallel()
          ...
      })
  }
  ```
  Go 1.22+ から for loop 変数 scope が iteration 単位になり capture 罠は解消されたが、CI が古い Go で動く可能性があるなら明示的に local 変数化が安全
- parallel 不可な test (global state を触る / 順序依存) は `t.Parallel()` を呼ばない
- `t.Parallel()` 呼んだ test 同士は並行実行、呼ばない test は parallel test 完了後に逐次実行

検出シグナル:
- table-driven test で全 case が `t.Parallel()` を呼んでいない (= wall time 損失)
- closure capture で `tc` を bind せずに外側の loop 変数を参照 (古い Go で bug)
- global state 触っているのに `t.Parallel()` 呼んでいる (race / flaky)

## 4. `t.Helper()`

- helper 関数 (assertion / fixture 構築) の **冒頭で `t.Helper()` 呼ぶ**。失敗時の line 報告が呼び出し側になり debug 容易
- 純粋な data 生成 helper には不要 (実際に `t.Errorf` / `t.Fatal` を呼ばないなら)

検出シグナル:
- `t.Errorf` / `t.Fatal` を呼ぶ helper で `t.Helper()` 呼んでいない

## 5. Setup / Teardown

- リソース cleanup は **`t.Cleanup()` で inline 登録** (Go 1.14+ の慣用)
- 共通 fixture は helper constructor (`newFixture(t)`) に集約、内部で `t.Cleanup` 登録
- struct field で table case 個別の前処理を持たせるときの命名は **`beforeFunc` / `afterFunc`** (`setup` / `teardown` の語は使わない)
- struct field 方式自体は default 非推奨 (boilerplate / closure capture 罠 / `t.Parallel()` と相性悪い)
- 例外: case ごとに genuinely 異なる前処理が必要なときのみ `beforeFunc` を struct field に追加。`afterFunc` は通常省略 (`beforeFunc` 内で `t.Cleanup` で済む)、必要なときだけ入れる

例:
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

検出シグナル:
- `defer cleanup()` だけで cleanup している (test 全体 fail 時に走らない、`t.Cleanup` の方が安全)
- struct field 名が `setup` / `teardown` (推奨は `beforeFunc` / `afterFunc`、project 規約があればそちら優先)
- 全 case で同じ setup function を持たせている (= 共通 helper に切り出すべき)

## 6. Race detector

- **常時 ON**。`go test -race` で実行 (例: `make test` に `-race` を含めて常時 ON)
- 並行コードのデータ race は static 解析で検出不可、CI で常時走らせる価値が高い
- コスト: ~10x 遅い + memory ~5-10x 増。unit test scale なら問題視しない
- benchmark (`go test -bench`) は race ON だと意味のある測定不可 → 別実行
- 例外的に race を外したい場合は build tag (`//go:build !race`)

検出シグナル:
- CI / Makefile で `go test` のみ (= race なし) を default にしている
- `go test -bench` を `-race` 付きで走らせている (測定が無意味)

## 7. Test design technique

### Black-box vs White-box

- **Black-box**: input → output の契約検証、内部実装に依存しない。`package x_test` (external test package) で書くと implementation symbols に触れず public API のみで test できる
- **White-box**: 分岐 / 内部状態を意図的に通す。`package x` (same package) で unexported symbol に触れる
- **使い分け**: API 契約の test は black-box、実装の coverage 補完は white-box。両方共存可

### Boundary value analysis

- off-by-one / 上限下限 / 0 / 空 / nil / max / min を意図的に test
- 例: `top_k` field なら 0 / 1 / 上限値 / 上限+1 / 負数 / 大きな数
- **文字列 boundary は rune count vs byte count を明示**:
  - Go の `len(string)` は **byte count**、文字数 (rune count) は `utf8.RuneCountInString` / `[]rune(s)`
  - 上限を持つ string API は spec 側でどちらの単位かを決め、test もそれに合わせる
  - マルチバイト文字 (日本語 / 絵文字) は 1 rune ≒ 3-4 byte。byte 上限の場合は **マルチバイトのみの境界 test が必須** (ASCII での境界 test だけでは検証漏れ)
  - 結合文字 / 異体字 selector を含む文字列は rune count ≠ grapheme cluster count。grapheme 単位で扱う API は別途 `golang.org/x/text/unicode/norm` 等を使う

### Equivalence partitioning

- 同値クラスに 1 件代表 test。全網羅を狙わず代表値で trade-off
- 例: `query` 文字列なら「ASCII」「マルチバイト」「絵文字 / 結合文字」「空文字 / 空白のみ」「上限文字数 / +1」

### Negative test

- 正常系 (HappyPath) だけでなく **rejection path を網羅**:
  - validation 失敗 (各 field の境界違反)
  - 上流 dependency error (provider unavailable / timeout)
  - context cancellation
  - permission / ACL 違反

### Property-based test

- `testing/quick` (標準) / `pgregory.net/rapid` (3rd-party) で性質ベース test
- 適用は限定的: pure function / decoder-encoder の roundtrip / ordering 保持などに有効
- 業務 logic には value-based test の方が読みやすい

検出シグナル:
- HappyPath のみで rejection / boundary が test されていない
- `top_k` のような数値 field で 0 / 上限 / 上限+1 が test 漏れ
- マルチバイト文字列入力 test がない (日本語 query で fail する潜在 bug)

## 8. Fake / Mock / Stub の使い分け

- **Fake**: 動く軽量実装 (in-memory db / in-memory adapter)。複雑 logic でも動作再現できる
- **Stub**: 固定 response を返すだけ。input は無視
- **Mock**: input 検証 + 期待呼び出し回数を assert (xUnit style)

推奨方針 (project 規約があればそちら優先):
- **手書き fake 推奨** (testify / gomock 等の generation tool は使わない)
- 理由: dependency 最小 / fake の挙動が src コード上で完結 / 過剰 mock 回避
- interface に narrow なものを切り (port pattern)、test 用に簡潔な struct で実装

例 (推奨 pattern):
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

検出シグナル:
- testify / gomock / mockery 等の mock framework が新規導入されている
- mock の expectation が「呼ばれた回数」だけ検証して input / output が unchecked

## 9. Test fixture / golden file / testdata

- 大きい input / 期待 output は `testdata/` directory に配置 (Go 慣用、build から除外される)
- golden file pattern: 期待 output を `testdata/golden/<name>.json` 等に保存、test 内で diff
  - update flag (`-update` 等の独自 flag) で実装変更時に一括更新
- fixture 共有は `testdata/fixtures/` 配下、test helper で読み込み

検出シグナル:
- 巨大な期待値 string が test code 中に inline (= testdata に切り出すべき)
- testdata に build tag が付いていない、もしくは Go の build から除外されていない (= `testdata` ディレクトリ名は Go が自動除外)

## 10. Test 区分 / build tag

- **Unit test**: 同じ package 内、外部 IO なし、ms オーダー。`*_test.go` で常時実行
- **Integration test**: 外部 dependency (DB / API) と接続、CI で別 stage。build tag で分離:
  ```go
  //go:build integration

  package x_test
  ```
  実行: `go test -tags=integration ./...`
- **E2E test**: 全体起動 + black-box。`tests/e2e/` 等の外側 directory + build tag

検出シグナル:
- Pinecone / OpenAI に直接 net 接続する test が unit test (`go test ./...`) で走る (= flaky / 外部依存)
- 別 build tag が付いていないが external IO する test

## 11. HTTP / gRPC test pattern

### HTTP

- `httptest.NewServer` で in-process server 起動、SDK の base URL を upcast
- request 検証は handler 内で `r.URL` / `r.Body` を assert
- response は `w.WriteHeader` + `w.Write([]byte(...))` で canned

### gRPC

- `bufconn.Listen` で in-memory listener、`grpc.NewClient(... grpc.WithContextDialer(bufDialer)) `で client wire
- service 全体起動が重ければ handler を直接 method 呼びでも可 (interceptor の test も含めたいなら bufconn)

検出シグナル:
- HTTP test で actual TCP port を bind している (= flaky / 並行 test 衝突)
- gRPC test で実 net listener を起動

## 12. Time / Context determinism

- `time.Now()` を直接呼ばず、`now func() time.Time` を struct field / param に注入
- test では `now: func() time.Time { return time.Date(2026, 5, 1, 0, 0, 0, 0, time.UTC) }` で固定
- ctx は test 内で `context.Background()` (entry point) または `context.WithTimeout` で deadline 制御
- random seed も注入 / `math/rand/v2` の Local 化で deterministic

検出シグナル:
- production code が `time.Now()` を直接呼ぶ (= test で固定不可)
- random / UUID 生成が global state 由来 (= 決定的にできない)

## 13. Coverage 解釈

- line coverage は guide rail、**信仰しない**
- branch coverage / boundary coverage / 重要 path 重視
- 100% 目指すと artificial test (`if false { ... }` を消すための pointless test) が生まれる
- DoD ベース: 機能契約 (acceptance criteria) を満たす test を書く、内部 100% を目指さない
- 目安: business logic / handler / adapter は 80%+、generated code / main は coverage 対象外

検出シグナル:
- coverage を上げるためだけの assertion なし test
- handler / service の HappyPath だけで coverage が稼がれているのに rejection path が test 抜け

## 14. Flakiness 回避

主な flaky 原因:
- **time-based**: `time.Sleep` 待ち、`time.Now()` の暗黙依存 → 注入で固定
- **ordering**: map iteration 順序依存 → sorted slice に変換してから assert
- **net IO**: actual port bind → httptest / bufconn を使う
- **goroutine race**: `t.Cleanup` で全 goroutine 終了を待つ、channel close で sync
- **shared state**: `t.Parallel()` 下で global / package var を mutate → test 内 local state に切り替え

検出シグナル:
- test 内に `time.Sleep`
- map iteration 結果を順序付き比較 (`reflect.DeepEqual([]Map, expectedSlice)` は順序保証なし)
- test 終了後に goroutine が残る

---

## False positive 判定基準

以下に該当する場合は本 skill の検出シグナルがヒットしても **違反扱いしない**:

- **生成コード由来**: protoc / buf / openapi-generator / `go generate` などで生成された symbol / file (典型: ファイル冒頭に `Code generated by ... DO NOT EDIT.` 行を含む)。生成元の schema 側で改善されるべきで、生成後の Go コードを手で直さない
- **言語 / library の慣用 pattern**: `func(...) (resp any, err error)` の named return + defer-recover、`http.Handler` などの固定 signature、`context.Context` を第一引数で取る規約等は本 skill の規則より優先
- **意図的設計の例外**: コード / docs で意図が明示されている設計上の決定 (例: shutdown context を signal-aware ctx から detach するための `context.Background()` の library 内使用)
- **public API 互換性**: 後方互換のため変えられない exported symbol (改名提案より移行戦略の提案を優先)

疑わしい場合は除外せず、output で「false positive 候補」として flag し user 判断を仰ぐ。

## このスキルが出力すべきもの

code-refactor-advisor agent から呼ばれた場合:
- 対象 test code に対する **section 別の違反 / 改善余地 list**
- 各指摘の **検出シグナル** + **根拠 section 番号**
- 修正方針 (table-driven 化 / fake 切り替え / golden file 化 / boundary case 追加 / etc.)

## 参照

- Go testing package doc: https://pkg.go.dev/testing
- Go Code Review Comments (Tests section): https://go.dev/wiki/CodeReviewComments
- Effective Go (Test section): https://go.dev/doc/effective_go
- Subtests and sub-benchmarks: https://go.dev/blog/subtests
