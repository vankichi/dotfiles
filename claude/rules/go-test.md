---
paths:
  - "**/*_test.go"
---

# Go test house 規約

## 命名

- 関数名は**意図ベース** (`TestX_RejectsEmpty`)。index ベース (`TestX1`) は禁止
- table-driven の case 名も意図を含む (`{name: "EmptyProductID"}`。`case1` は NG)
- **sub-test 名にスペースを入れない** — `t.Run("foo bar")` は `foo_bar` に正規化され grep しにくくなる
- **test 内に説明 inline コメントを書かない**。意図は test 名と変数名で表現する

## table-driven の標準形

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

- `wantErr` は **sentinel error** (`errors.Is`)。**文字列比較は禁止**
- nil error 期待も `wantErr: nil` を明示する
- `t.Parallel()` は **default で有効化**。global state / 順序依存の時のみ外す

## fake は手書きする

**mock 生成 tool (testify / gomock / mockery) を新規導入しない**。interface を narrow に切り、test 用の struct で実装する。呼び出し回数だけ検証して input / output を unchecked にしない。

## setup / teardown

- cleanup は **`t.Cleanup()`**。`defer` は fail 経路で走らないことがある
- case 個別の前処理を struct field に持たせる場合の命名は **`beforeFunc` / `afterFunc`** (`setup` / `teardown` の語は使わない)
- **struct field 方式自体が default 非推奨** (boilerplate / closure capture / `t.Parallel()` と相性が悪い)。genuinely 異なる前処理が要る case のみ

## 境界値 — rune と byte を区別する

house で最も事故が多い箇所。

- `len(string)` は **byte count**。文字数は `utf8.RuneCountInString`
- **マルチバイト文字は 1 rune ≒ 3-4 byte。byte 上限ならマルチバイトのみの境界 test が必須** — ASCII の境界 test だけでは検証漏れ
- 数値 field は 0 / 1 / 上限 / 上限+1 / 負数
- **rejection path を網羅する**: validation 失敗 / 上流 dependency error / context cancellation / permission 違反

## 決定性

- `time.Now()` を production code から直接呼ばない。`now func() time.Time` を注入する
- **HTTP は `httptest.NewServer`、gRPC は `bufconn`**。実 port を bind しない
- map iteration 順序に依存しない。test 内で `time.Sleep` しない

## 実行

- **`-race` 常時 ON**。benchmark のみ別実行 (race ON では測定にならない)
- 大きい期待値は `testdata/` へ。integration / E2E は build tag で分離する
- coverage は guide rail。**信仰しない** — 100% を目指すと assertion の無い artificial test が生まれる

## 機械化できない観点

**assertion が trivially pass しないか** — 「実装の挙動を逆にしても pass するか」。実装と test の両方を読まないと判定できず、最も価値がある。
