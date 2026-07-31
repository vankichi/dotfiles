---
name: go-test
description: Go の test design / test code 慣用句の reference skill。命名 / table-driven / t.Parallel / race detector / fake・mock / boundary value / coverage 解釈を扱う。「test 名どうする」「table-driven にする」「coverage 何 % まで」等の問いで参照する。手順 skill ではない。
---

# go-test

Go の test に関する house 規約と検出シグナル集。実装 / review / refactor 候補出しの判断基準として参照する。

**一般論 (black-box と white-box の違い / 同値分割とは何か 等) は再掲しない** — 本 skill が持つのは house の選択と、grep で気付くための signal のみ。

## 1. 命名

- 関数名は**意図ベース** (`TestX_RejectsEmpty` / `TestX_When_..._Should_...`)。`TestX1` のような index ベースは禁止
- table-driven の case 名も意図を含む (`{name: "EmptyProductID"}`。`case1` は NG)
- **sub-test 名にスペース / 特殊文字を入れない** (`t.Run("foo bar")` は `foo_bar` に正規化され grep しにくい)
- helper は意図を表す prefix (`newFixture(t)` / `newAdapterWithFake(t, fake)`)

**検出**: **test 内に説明 inline コメントがある** (= test 名 / 変数名で意図を表現できていない) / index ベースの case 名 / スペース入りの `t.Run` 名

## 2. Table-driven test

house の標準形:

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

- struct field は必要最小限に (全 case で同じ値なら struct の外に定数で置く)
- `wantErr` は **sentinel error** (`errors.Is` で検証可能) を入れる。**文字列比較は禁止**
- nil error 期待も `wantErr: nil` を明示する (省略でも動くが意図が伝わらない)

**検出**: case が 1 件しかない table-driven (通常の test func で十分) / struct field の半数以上が空値・同値 (struct 過剰) / `wantErr string` での文字列比較

## 3. `t.Parallel()`

- **default で有効化する** (wall time 短縮 + race detector の効果増)
- Go 1.22+ で loop 変数 scope が iteration 単位になり capture 罠は解消されたが、**CI が古い Go で動く可能性があるなら `tc := tc` の local 変数化が安全**
- global state を触る / 順序依存の test では呼ばない

**検出**: table-driven で全 case が `t.Parallel()` を呼んでいない / 外側の loop 変数を bind せず参照 / global state を触るのに `t.Parallel()` を呼んでいる (flaky)

## 4. `t.Helper()`

`t.Errorf` / `t.Fatal` を呼ぶ helper の冒頭で必ず呼ぶ (失敗時の line 報告が呼び出し側になる)。純粋な data 生成 helper には不要。

**検出**: `t.Errorf` / `t.Fatal` を呼ぶのに `t.Helper()` が無い helper

## 5. Setup / Teardown

- リソース cleanup は **`t.Cleanup()` で inline 登録**する
- 共通 fixture は helper constructor (`newFixture(t)`) に集約し、内部で `t.Cleanup` を登録する
- **case 個別の前処理を struct field に持たせる場合の命名は `beforeFunc` / `afterFunc`** (`setup` / `teardown` の語は使わない)
- **struct field 方式自体は default 非推奨** (boilerplate / closure capture 罠 / `t.Parallel()` と相性が悪い)。case ごとに genuinely 異なる前処理が要る時のみ `beforeFunc` を足す (`afterFunc` は通常不要 — `beforeFunc` 内の `t.Cleanup` で済む)

**検出**: `defer cleanup()` だけで cleanup (test 全体 fail 時に走らない) / struct field 名が `setup` / `teardown` / 全 case が同じ setup function を持つ (共通 helper に切り出すべき)

## 6. Race detector

- **常時 ON** (`make test` に `-race` を含める)。並行コードの data race は静的解析で検出できず、CI で常時走らせる価値が高い
- コストは ~10x 遅い + memory 5-10x 増だが unit test scale なら問題視しない
- **benchmark は race ON だと意味のある測定ができない** → 別実行にする。例外的に外すなら build tag (`//go:build !race`)

**検出**: CI / Makefile の default が `go test` のみ (race なし) / `go test -bench` を `-race` 付きで走らせている

## 7. Test design

- **black-box** (`package x_test`) は API 契約の検証、**white-box** (`package x`) は実装 coverage の補完。両方共存してよい
- **boundary value**: off-by-one / 上限下限 / 0 / 空 / nil / max / min を意図的に置く (`top_k` なら 0 / 1 / 上限 / 上限+1 / 負数)
- **文字列 boundary は rune count と byte count を明示的に区別する**:
  - Go の `len(string)` は **byte count**。文字数は `utf8.RuneCountInString` / `[]rune(s)`
  - 上限を持つ string API は spec 側でどちらの単位かを決め、test もそれに揃える
  - **マルチバイト文字 (日本語 / 絵文字) は 1 rune ≒ 3-4 byte。byte 上限ならマルチバイトのみの境界 test が必須** (ASCII の境界 test だけでは検証漏れ)
  - 結合文字 / 異体字 selector を含む文字列は rune count ≠ grapheme cluster count
- **同値クラスは代表 1 件**で足りる (`query` なら ASCII / マルチバイト / 絵文字・結合文字 / 空文字・空白のみ / 上限・上限+1)
- **rejection path を網羅する**: validation 失敗 (各 field の境界違反) / 上流 dependency error / context cancellation / permission・ACL 違反
- property-based test (`testing/quick` / `rapid`) の適用は限定的 — pure function / encoder-decoder の roundtrip / ordering 保持に有効。業務 logic には value-based の方が読みやすい

**検出**: HappyPath のみで rejection / boundary が無い / 数値 field で 0・上限・上限+1 が漏れ / **マルチバイト文字列の入力 test が無い** (日本語 query で fail する潜在 bug)

## 8. Fake / Mock / Stub

**手書き fake を推奨する。testify / gomock / mockery のような generation tool は使わない** (dependency 最小 / fake の挙動が src 上で完結 / 過剰 mock の回避)。interface は narrow に切り (port pattern)、test 用に簡潔な struct で実装する。

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

**検出**: mock framework の新規導入 / mock の expectation が呼び出し回数だけで input・output が unchecked

## 9. testdata / golden file

大きい input / 期待 output は `testdata/` に置く (Go が build から自動除外する)。golden file は `testdata/golden/<name>.json` 等に保存して test 内で diff し、実装変更時は独自の `-update` flag で一括更新する。

**検出**: 巨大な期待値 string が test code 中に inline

## 10. Test 区分 / build tag

- **unit**: 同 package 内、外部 IO なし、ms オーダー。常時実行
- **integration**: 外部 dependency と接続。build tag (`//go:build integration`) で分離し `go test -tags=integration ./...` で実行
- **E2E**: 全体起動 + black-box。`tests/e2e/` 等の外側 directory + build tag

**検出**: 外部サービスに直接 net 接続する test が `go test ./...` で走る (flaky / 外部依存) / build tag なしで external IO する test

## 11. HTTP / gRPC test pattern

- **HTTP**: `httptest.NewServer` で in-process 起動し SDK の base URL を差し替える。request 検証は handler 内で `r.URL` / `r.Body` を assert
- **gRPC**: `bufconn.Listen` で in-memory listener を立て `grpc.WithContextDialer(bufDialer)` で client を配線する (interceptor まで test したい場合。不要なら handler の直接 method 呼びでも可)

**検出**: 実 TCP port を bind している HTTP test (flaky / 並行 test 衝突) / 実 net listener を起動する gRPC test

## 12. Time / Context の決定性

`time.Now()` を直接呼ばず `now func() time.Time` を struct field / param に注入し、test では固定値を返す。random seed も注入するか `math/rand/v2` を local 化する。

**検出**: production code が `time.Now()` を直接呼ぶ / random・UUID 生成が global state 由来

## 13. Coverage の解釈

line coverage は guide rail であって**信仰しない**。branch / boundary / 重要 path を重視し、**DoD ベース** (機能契約を満たす test を書き、内部 100% を目指さない) で判断する。100% を目指すと assertion の無い artificial test が生まれる。目安は business logic / handler / adapter が 80%+、generated code と main は対象外。

**検出**: coverage を上げるためだけの assertion なし test / HappyPath だけで coverage を稼ぎ rejection path が抜けている

## 14. Flakiness 回避

主因と対処: **time-based** (`time.Sleep` 待ち / `time.Now()` の暗黙依存 → 注入で固定) / **ordering** (map iteration 順序依存 → sorted slice に変換してから assert) / **net IO** (実 port bind → httptest・bufconn) / **goroutine race** (`t.Cleanup` で終了待ち / channel close で sync) / **shared state** (`t.Parallel()` 下で global を mutate → test 内 local へ)。

**検出**: test 内の `time.Sleep` / map iteration 結果の順序付き比較 / test 終了後に残る goroutine

## False positive 判定基準

以下は検出シグナルがヒットしても**違反扱いしない**:

- **生成コード**: 冒頭に `Code generated by ... DO NOT EDIT.` を含む file (生成元 schema 側で直す)
- **言語 / library の慣用 pattern**: 固定 signature 等。本 skill の規則より優先する
- **意図的設計の例外**: code / docs で意図が明示されている決定
- **public API 互換性**: 後方互換のため変えられない exported symbol

疑わしい場合は除外せず「false positive 候補」として flag し user 判断を仰ぐ。

## 出力

`code-refactor-advisor` から呼ばれた場合、section 別の違反 / 改善余地 list に、各指摘の**検出シグナル**と**根拠 section 番号**、修正方針 (table-driven 化 / fake 切り替え / golden file 化 / boundary case 追加 等) を添えて返す。
