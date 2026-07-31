---
name: go-style
description: Go の慣用句・命名・error handling・context・logging・concurrency・lint / format の reference skill。「Go お作法的にどう」「命名規約」「error wrap」等の問いや code review 時に参照する。手順 skill ではない。
---

# go-style

Go の house 規約と、規約違反を機械的に拾うための検出シグナル集。実装 / review / refactor 候補出しの判断基準として参照する。

**一般的な Go の作法 (error は値 / ctx は第一引数 / 送信者が channel を close / `fmt.Errorf("%w")` で wrap 等) は再掲しない** — 本 skill が持つのは house の選択と、それが破れた時に grep で気付くための signal のみ。

## 1. Package layout

- `cmd/<bin>/main.go` がバイナリ entry。1 バイナリ = 1 サブディレクトリ
- 実装は原則 `internal/` に置く。`pkg/` は**外部 import を意図する場合のみ** (reuse の見込みが無いなら `internal/`)
- `apis/` で proto / OpenAPI / SDK の公開 surface を分離する
- DDD + Clean Architecture 採用時は `internal/{domain,application,interfaces,adapters}/` (層境界は `ddd-clean-architecture` が SoT)
- 1 package = 1 責務。`util` / `common` / `helper` の catch-all package は anti-pattern

**検出**: `internal/util/` に複数責務が同居 / `cmd/` 内に business logic / `pkg/` を使っているのに外部 import の実例なし

## 2. 命名

- exported / unexported は **今公開する必要があるか**だけで決める (「将来公開するかも」で大文字にしない)
- **acronym は全大文字保持**: 3 文字以上 (`URL` `ID` `HTTP` `API`) も 2 文字 (`AI` `IO` `UI` `OS` `DB`) も全大文字。商標 / 一般化された綴りは standard に従う (`OpenAI` / `OpenAPI` / `gRPC`)。**商標が unexported 識別子の先頭に来る場合は商標部分も lowercase 化する** (`openaiKey` / `openapiSpec` — `openAIKey` のような acronym 内部の case mix は NG)
- receiver 名は **同じ型なら全 method で同じ短い名前** (`s *Server`)。`this` / `self` は禁止
- interface は単一 method なら `-er` suffix、多 method は名詞
- enum 値は型名接頭辞 (`type Model string` + `ModelTextEmbedding3Large Model = "..."`)
- **定数は集約する**: magic number / 繰り返す literal (文字列 key / 閾値 / timeout / URL path) を named const に抽出する (自明な `0` / `1` / `""` は除く)。関連定数は 1 つの const block にまとめ、file / package 内に散在させない

**検出**: 式中の裸の数値 literal / 同一 string literal の 2 回以上の出現 / 同種の定数が複数の const 宣言に散在 / `Url` `Id` `Http` `Ai` `Io` `Ui` のような mixed case acronym / `openAIKey` 型の case mix / receiver が `this *X` / 1 型の receiver 名が file ごとにバラバラ / 「将来公開するかも」だけの exported symbol

## 3. Error handling

- sentinel error は package level の `var Err... = errors.New("pkg: human message")`。message に `package:` prefix を付けて wrap chain を読みやすくする
- **API 境界で「sanitize された外向き message」と「内部 wrap chain」を分ける**。client に upstream 詳細を leak せず、内部詳細は logger 側に出す
- panic は真に異常な状態のみ (起動時の不変量違反等)。通常 flow で使わない

**検出**: `errors.New(fmt.Sprintf(...))` / error の文字列比較 (`err.Error() == "..."`) / handler・gRPC server の error response に upstream SDK error が漏れている / `cmd/` 以外に panic・`log.Fatal`

## 4. Context

- `ctx.Value` は cross-cutting metadata (request_id / trace span / auth principal) のみ。引数で渡せる値は引数で渡す
- ctx key は **package private struct type** で衝突回避する (`type requestIDKey struct{}`)

**検出**: library 内の `context.Background()` / `ctx.Value("string-key")` (衝突 risk のある string key) / struct field の `ctx context.Context` / ctx が引数の最後や中央

## 5. Logging

- 標準 `log/slog` を採用し構造化 JSON (`slog.NewJSONHandler`) を推奨する
- level: `Error` (action 必要) / `Warn` (異常だが継続) / `Info` (通常運用) / `Debug` (開発時のみ)
- ctx は `LogAttrs(ctx, ...)` で渡し、interceptor / middleware が span・request_id を付与できるようにする
- **log message は固定文字列、可変値は attr** (cardinality 制御 + grep しやすさ)。**PII / 認証情報は log しない**

**検出**: `fmt.Println` / `log.Print*` で運用 log を出している / `slog.Info(fmt.Sprintf(...))` の interpolated message / log message に API key・password・個人識別子

## 6. Concurrency

- mutex は **保護対象を明示する** (struct field 直前のコメント、または `mu sync.Mutex` の直後に保護対象を並べる)
- channel direction を関数 signature で限定する (`<-chan T` / `chan<- T`)
- 複数 IO の並行実行は `errgroup.Group` を推奨 (context 連動 cancellation + 最初の error 取得)

**検出**: goroutine 内で `ctx.Done()` も channel 受信もしていない (leak 候補) / 保護対象が不明な `mu sync.Mutex` / signature の channel が両方向 (`chan T`) / goroutine 内 panic を defer recover していない

## 7. Lint / format

- `golangci-lint` **v2 系** (`.golangci.yaml` で config)。CI で必須
- `goimports` の **local prefix は各 repo の module path に合わせる**
- 推奨 linter: `errcheck` / `govet` / `staticcheck` / `ineffassign` / `unused` / `gosimple` / `gofmt` / `goimports`
- `// nolint:` は **理由コメント必須** (`// nolint:errcheck // intentional fire-and-forget`)

**検出**: 理由なしの `// nolint:` / import 順序が stdlib・3rd-party・local 混在 / 戻り値 error を `_` に捨てている

## 8. godoc / コメント

- exported symbol には godoc 必須。package コメントは `// Package <name> ...` を各 package 1 file に置く
- **コメントは WHY を書く。WHAT は code が語る**
- **unexported symbol への doc comment は必須ではない** — 書くなら WHY のみ 1-3 行。直下 code の逐語訳 block を習慣で付けない (**隣接 code がそうなっていても真似ない** — 過去の生成物が規約から drift している可能性がある)
- 「将来 X したい」は `TODO:` で書く。**Phase / ticket ID をコメントに残さない**
- `Deprecated:` は対象 symbol の godoc に明示する

**検出**: godoc の無い exported symbol / WHAT しか書いていないコメント / unexported method に機械的に付いた WHAT 説明の doc block (4 行以上は特に疑う) / `Phase 0` 等の時系列・ticket scope 言及

## 9. Import order

stdlib / third-party / local (current module) の 3 group を空行で区切る (`goimports` の `-local` 設定で自動化)。各 group 内は alphabetical。**alias は必要最小限** (衝突回避 / 短縮目的のみ。`pgsql "github.com/lib/pq"` は OK、`f "fmt"` は NG)。

**検出**: group 区切りなし / 不要 alias (`io2 "io"` 等)

## 10. Type safety / nil 安全

- `interface{}` / `any` は本当に型不定なときのみ (passthrough は可)
- nil pointer 防御は **constructor で nil reject** する
- **pointer receiver と value receiver を 1 型で混在させない** (mutating method があるなら全 method pointer receiver)

**検出**: 業務 logic 中の `any` / 同一 type での receiver 混在 / nil check 漏れの map 代入

## False positive 判定基準

以下は検出シグナルがヒットしても**違反扱いしない**:

- **生成コード**: 冒頭に `Code generated by ... DO NOT EDIT.` を含む file。生成元 schema 側で直す (生成後の Go を手で直さない)
- **言語 / library の慣用 pattern**: `http.Handler` 等の固定 signature、named return + defer-recover など。本 skill の規則より優先する
- **意図的設計の例外**: code / docs で意図が明示されている決定 (例: shutdown context を signal-aware ctx から detach するための library 内 `context.Background()`)
- **public API 互換性**: 後方互換のため変えられない exported symbol (改名提案より移行戦略を提案する)

疑わしい場合は除外せず「false positive 候補」として flag し user 判断を仰ぐ。

## 出力

`code-refactor-advisor` から呼ばれた場合、section 別の違反 / 改善余地 list に、各指摘の**検出シグナル** (どの pattern で気付いたか) と**根拠 section 番号**、修正方針 (規約に揃える / 例外として残す / 別途議論) を添えて返す。
