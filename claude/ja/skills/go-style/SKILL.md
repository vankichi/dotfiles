---
name: go-style
description: Go の慣用句・命名・error handling・context・logging・concurrency・lint / format の reference skill。「Go お作法的にどう」「命名規約」「error wrap」等の問いや code review 時に参照する。手順 skill ではない。
---

# go-style

Go の慣用句・お作法を集めた reference skill。実装 / review / refactor 候補出しの判断基準として参照する。

## 適用条件

- Go コード (`*.go` / `Makefile` / `*.proto` の Go 生成系) を扱う任意の場面
- code-refactor-advisor agent からの参照
- ユーザーが「Go 的にどう書く」「命名どうする」を尋ねる場面

## 1. Package layout

- `cmd/<bin>/main.go` でバイナリエントリ。1 バイナリ = 1 サブディレクトリ
- `internal/` 配下は他リポジトリから import 不可。基本的にここに実装を置く
- `pkg/` は外部 import を意図する場合のみ。reuse の見込みが無いなら `internal/` に置く
- DDD + Clean Architecture 採用時: `internal/{domain,application,interfaces,adapters}/` (層境界の詳細は `ddd-clean-architecture` skill)
- `apis/` で proto / OpenAPI / SDK 公開 surface を分離 (推奨規約)
- 1 package = 1 責務。`util` / `common` / `helper` のような catch-all package は anti-pattern

検出シグナル:
- `internal/util/` 配下に複数責務の関数が同居
- `cmd/` の中に business logic
- `pkg/` を使っているのに外部 import 実例なし

## 2. 命名

- exported (大文字始まり) ⇔ unexported (小文字始まり) の判断は **公開する必要があるか** だけで決める。「将来公開するかも」で大文字にしない
- acronym は **全大文字保持**:
  - 3 文字以上: `URL` `ID` `HTTP` `API` (`Url` / `Id` / `Http` は NG)
  - 2 文字: `AI` / `IO` / `UI` / `OS` / `DB` も全大文字 (`Ai` / `Io` / `Ui` は NG)
  - 複数 acronym 含む商標 / 一般化された綴り: `OpenAI` / `OpenAPI` / `gRPC` の standard 綴りに従う
  - 商標が unexported 識別子の先頭に来る場合: 商標部分も lowercase 化して acronym 規則と整合させる (`openaiKey` / `openapiSpec`)。`openAIKey` のような acronym 内部 case mix は NG
- receiver 名は **同じ型なら全 method で同じ短い名前** (`s *Server` / `c *Client`)。`this` / `self` は禁止
- interface 名は単一 method なら `-er` suffix (`Reader` / `Writer`)。多 method は名詞 (`FileSystem`)
- error 型・変数は `Err` / `err` 接頭辞 (`var ErrNotFound = ...` / `func ... (err error)`)
- enum 値は型名接頭辞 (`type Model string` + `ModelTextEmbedding3Large Model = "..."`)
- test 名は `TestX_When_..._Should_...` または `TestX_RejectsEmpty` 等の意図ベース (詳細は `go-test` skill)
- **定数は集約する**: magic number / 繰り返し登場する literal (文字列 key / 閾値 / timeout / URL path 等) は named const に抽出する (自明な zero value `0` / `1` / `""` は除く)。関連する定数は 1 つの const block にまとめて宣言し、file / package 内に散在させない。値集合は型付き const block (上記 enum 規則) に揃える

検出シグナル:
- 式中の裸の数値 literal (timeout / limit / サイズ等) / 同一 string literal の 2 回以上の出現 / 同種の定数が複数の const 宣言に散在
- `Url` / `Id` / `Http` / `Ai` / `Io` / `Ui` のような mixed case acronym
- `openAIKey` のような商標 acronym と他文字の case mix (商標を unexported 先頭で使う場合は `openaiKey` 等に lowercase 化)
- receiver が `this *X` / `self *X`
- 1 型に対して `s` `srv` `server` のように receiver 名が file ごとにバラバラ
- 「将来公開するかも」だけで exported にしている symbol

## 3. Error handling

- error は **値**。最後の戻り値、`if err != nil { return ..., err }` を省略しない
- wrap には `fmt.Errorf("context: %w", err)` を使う。`errors.Is` / `errors.As` で sentinel / typed match できる状態を保つ
- sentinel error は package level の `var Err... = errors.New("pkg: human message")`。message に `package:` prefix を付けると wrap chain が読みやすい
- 文字列比較で error 判別しない (`err.Error() == "..."` 禁止)
- panic は **真に異常な状態のみ** (例: program 起動時の不変量違反)。通常 flow では使わない
- error message は **小文字始まり、句点なし** (`io: short read` / `not "Io: short read."`)
- wrap した chain は **API 境界で「sanitize された外向き message」と「内部 wrap chain」を分ける**。client に upstream 詳細を leak しない (内部詳細は logger で出す)

検出シグナル:
- `errors.New(fmt.Sprintf(...))` (= `fmt.Errorf` を使うべき)
- error の文字列比較
- handler / gRPC server の error response に upstream SDK error が漏れている
- panic / `log.Fatal` が library code 内に存在 (cmd/ 以外)

## 4. Context

- `context.Context` は **関数の第 1 引数**。`ctx context.Context` で名前統一
- ctx を struct field に保持しない (request scoped と struct lifetime が混ざる)
- ctx の伝搬は明示的 (関数呼び出しで pass、暗黙の global 不可)
- `context.Background()` は entry point (main / test / signal handler) のみ。library 内では caller の ctx を使う
- `ctx.Value` は cross-cutting metadata (request_id / trace span / auth principal) のみ。引数で渡せる値は引数で渡す
- ctx key は **package private struct type** で衝突回避 (`type requestIDKey struct{}`)
- cancellation / deadline はライブラリ側で `<-ctx.Done()` を観察し、長い IO は `select` でブロック解除

検出シグナル:
- `context.Background()` を library 内で呼んでいる
- `ctx.Value("string-key")` (= 衝突 risk のある string key)
- struct field に `ctx context.Context`
- ctx を引数の最後 / 中央に置いている

## 5. Logging

- 標準 `log/slog` を採用。構造化 JSON 推奨 (`slog.NewJSONHandler`)
- level 使い分け: `Error` (action 必要) / `Warn` (異常だが処理継続) / `Info` (通常運用) / `Debug` (開発時のみ)
- key-value pair で構造化: `slog.String("key", "value")` / `slog.Int(...)` / `slog.Duration(...)`
- ctx を `LogAttrs(ctx, ...)` で渡し、interceptor / middleware に span / request_id を付与可能にする
- **PII / 認証情報を log しない** (API key / password / token / personal identifier)
- log message は固定文字列、可変値は attr で渡す (cardinality 制御 + grep しやすさ)
- error log では wrap 元の root cause も attr で出す (`slog.String("error", err.Error())`)

検出シグナル:
- `fmt.Println` / `log.Print*` (標準 log や fmt) で運用 log を出している
- `slog.Info(fmt.Sprintf("user %s logged in", userID))` 等の interpolated message
- log message に API key / password / 個人識別子が混入

## 6. Concurrency

- goroutine は **必ず終了経路を確保** (cancellation / done channel / WaitGroup / errgroup)
- goroutine leak の代表的原因: blocked send/recv on unbuffered channel, ctx 観察忘れ, errgroup `g.Wait()` 忘れ
- mutex は **保護対象を明示** (struct field 直前にコメント、または `mu sync.Mutex` の直後に保護対象を並べる)
- channel は **送信者が close する**。受信者 close は禁止 (panic / race risk)
- channel direction を関数 signature で限定 (`<-chan T` / `chan<- T`)
- `errgroup.Group` は context 連動 cancellation + 最初の error 取得 + `g.Wait()` で sync。複数 IO の並行実行に推奨
- `sync.Once` は init 用途。複数回必要な状態は別 pattern (mutex / atomic)
- shared mutable state は最小化、可能なら immutable copy + channel pass

検出シグナル:
- goroutine の中で `ctx.Done()` も channel 受信もしていない (= leak 候補)
- mutex の保護対象が不明 (`mu sync.Mutex` しかない)
- channel direction が両方向 (`chan T`) で signature に書かれている
- goroutine 内 panic を defer recover していない (= 上位 goroutine ごと crash)

## 7. Lint / format

- `gofmt` / `goimports` 強制 (`goimports` の local prefix は各リポジトリの module path に合わせる)
- `golangci-lint` v2 系 (`.golangci.yaml` で config)。CI で必須
- 推奨 linter: `errcheck` / `govet` / `staticcheck` / `ineffassign` / `unused` / `gosimple` / `gofmt` / `goimports`
- 警告 (`// nolint:`) は **理由コメント必須** (`// nolint:errcheck // intentional fire-and-forget`)
- 自動 fixable は CI 前に local で fix (`gofmt -w` / `goimports -w` / `golangci-lint run --fix`)

検出シグナル:
- `// nolint:` が理由なし
- import 順序が stdlib / 3rd-party / local 混在
- `errcheck` 警告無視 (戻り値 error を `_` に捨てる、必要なら `// intentional`)

## 8. godoc / コメント

- exported symbol には godoc 必須 (`// FuncName ...` で symbol 名から始まる文)
- package コメントは `// Package <name> ...` で各 package 1 ファイルに置く (大抵 doc.go or 主要 file)
- コメントは **WHY を書く**。WHAT は code が語る (well-named identifier がある前提)
- unexported symbol への doc comment は必須ではない — 書くなら WHY のみ 1-3 行。直下 code の逐語訳 block を習慣で付けない (隣接 code がそうなっていても真似ない — 過去の生成物が規約から drift している可能性)
- 「将来 X したい」は `TODO:` で書く。Phase / ticket ID をコメントに残さない
- `Deprecated:` は対象 symbol の godoc に明示 (`// Deprecated: use NewX instead.`)
- multi-line block comment より行 comment (`//`) を好む

検出シグナル:
- exported func / type / var で godoc なし
- コメントが WHAT (code を翻訳しているだけ) しか書いていない
- unexported method に機械的に付いた WHAT 説明の doc block (4 行以上の block は特に疑う)
- `Phase 0` / リリースサイクル名付き ticket のような時系列 / ticket scope 言及

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

- 3 group を空行で区切る (goimports の `-local` 設定で自動)
- 各 group 内 alphabetical sort
- alias は **必要最小限** (衝突回避 / 短縮目的のみ)。`pgsql "github.com/lib/pq"` は OK、`f "fmt"` は NG

検出シグナル:
- group 区切りなし (1 つの import block に全部混ざる)
- 不要 alias (`io2 "io"` 等)

## 10. Type safety / nil 安全

- `interface{}` / `any` は本当に型不定なときのみ。型が決まっているなら明示 type
- nil pointer dereference 防御は **constructor で nil reject** (`func NewX(...) (*X, error) { if ... == nil { return nil, ErrNil }`)
- nil map への代入 panic、nil slice の append は OK (混同しない)
- pointer receiver と value receiver は **混在禁止** (1 type に対して統一、mutating method があるなら全 method pointer receiver)

検出シグナル:
- `any` / `interface{}` が業務 logic で使われている (passthrough なら可)
- pointer receiver と value receiver が同じ type で混在
- nil check 漏れた map 代入

---

## False positive 判定基準

以下に該当する場合は本 skill の検出シグナルがヒットしても **違反扱いしない**:

- **生成コード由来**: protoc / buf / openapi-generator / `go generate` などで生成された symbol / file (典型: ファイル冒頭に `Code generated by ... DO NOT EDIT.` 行を含む)。生成元の schema 側で改善されるべきで、生成後の Go コードを手で直さない
- **言語 / library の慣用 pattern**: `func(...) (resp any, err error)` の named return + defer-recover、`http.Handler` などの固定 signature、`context.Context` を第一引数で取る規約等は本 skill の規則より優先
- **意図的設計の例外**: コード / docs で意図が明示されている設計上の決定 (例: shutdown context を signal-aware ctx から detach するための `context.Background()` の library 内使用)
- **public API 互換性**: 後方互換のため変えられない exported symbol (改名提案より移行戦略の提案を優先)

疑わしい場合は除外せず、output で「false positive 候補」として flag し user 判断を仰ぐ。

## このスキルが出力すべきもの

code-refactor-advisor agent から呼ばれた場合、以下を提供する想定:
- 対象コードに対する **section 別の違反 / 改善余地 list**
- 各指摘に対する **検出シグナル** (どの pattern で気付いたか) と **根拠 section** (この skill 内の section 番号)
- 修正方針 (お作法に揃える / 例外として残す / 別途議論)

## 参照

- Go Code Review Comments: https://go.dev/wiki/CodeReviewComments
- Effective Go: https://go.dev/doc/effective_go
- Go Proverbs: https://go-proverbs.github.io/
- Uber Go Style Guide: https://github.com/uber-go/guide/blob/master/style.md
