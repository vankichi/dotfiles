---
name: go-style
description: Go の慣用句・命名・error handling・context・logging・concurrency・lint / format の house 規約。手順 skill ではない reference。
when_to_use: 「Go お作法的にどう」「命名規約」「error wrap どうする」等の問いが来た時。Go コードの review / refactor 候補出しで判断基準が要る時。`code-refactor-advisor` / `go-feature-tdd` からの参照。
---

# go-style

Go の house 規約集。各 section は **Do (house の選択)** と **Don't (禁止事項 = そのまま検出シグナル)** の 2 ブロック構成。

**一般的な Go の作法は再掲しない** (error は値 / ctx は第一引数 / 送信者が channel を close / `fmt.Errorf("%w")` で wrap 等)。本 skill が持つのは house の選択と、破れた時に grep で気付くための signal のみ。

## 1. Package layout

**Do**
- `cmd/<bin>/main.go` がバイナリ entry。1 バイナリ = 1 サブディレクトリ
- 実装は原則 `internal/` に置く
- `pkg/` は外部 import を意図する場合のみ
- `apis/` で proto / OpenAPI / SDK の公開 surface を分離
- DDD 採用時は `internal/{domain,application,interfaces,adapters}/` (層境界は `ddd-clean-architecture` が SoT)

**Don't**
- `util` / `common` / `helper` の catch-all package (1 package = 1 責務)
- `internal/util/` に複数責務が同居
- `cmd/` 内の business logic
- 外部 import の実例が無いのに `pkg/` を使用

## 2. 命名

**Do**
- exported / unexported は **今公開する必要があるか**だけで決定
- receiver 名は同じ型なら全 method で同じ短い名前 (`s *Server`)
- interface は単一 method なら `-er` suffix、多 method は名詞
- enum 値は型名接頭辞 (`type Model string` + `ModelTextEmbedding3Large Model = "..."`)
- magic number / 繰り返す literal (文字列 key・閾値・timeout・URL path) を named const へ抽出 (自明な `0` / `1` / `""` は対象外)
- 関連定数は 1 つの const block にまとめる

**acronym は全大文字保持**

| 対象 | 正 | 誤 |
|---|---|---|
| 3 文字以上 | `URL` `ID` `HTTP` `API` | `Url` `Id` `Http` |
| 2 文字 | `AI` `IO` `UI` `OS` `DB` | `Ai` `Io` `Ui` |
| 商標 / 一般化された綴り | `OpenAI` `OpenAPI` `gRPC` | — |
| 商標が unexported の先頭 | `openaiKey` `openapiSpec` | `openAIKey` |

最下行に注意 — 商標が先頭に来る unexported 識別子は商標部分も lowercase 化。

**Don't**
- `this *X` / `self *X` の receiver
- 1 型で receiver 名が file ごとにバラバラ
- 「将来公開するかも」だけの exported symbol
- `Url` `Id` `Http` `Ai` `Io` `Ui` 型の mixed case acronym / `openAIKey` 型の case mix
- 式中の裸の数値 literal / 同一 string literal の 2 回以上の出現
- 同種の定数が複数の const 宣言に散在

## 3. Error handling

**Do**
- sentinel error は package level の `var Err... = errors.New("pkg: human message")` (message の `package:` prefix で wrap chain を読みやすく)
- API 境界で「sanitize された外向き message」と「内部 wrap chain」を分離。内部詳細は logger 側へ
- panic は真に異常な状態のみ (起動時の不変量違反等)

**Don't**
- `errors.New(fmt.Sprintf(...))`
- error の文字列比較 (`err.Error() == "..."`)
- handler / gRPC server の error response への upstream SDK error の leak
- `cmd/` 以外での panic・`log.Fatal`

## 4. Context

**Do**
- `ctx.Value` は cross-cutting metadata (request_id / trace span / auth principal) のみ
- ctx key は package private struct type で衝突回避 (`type requestIDKey struct{}`)

**Don't**
- library 内の `context.Background()`
- `ctx.Value("string-key")` — 衝突 risk のある string key
- struct field の `ctx context.Context`
- 引数の最後や中央に置かれた ctx

## 5. Logging

**Do**
- 標準 `log/slog` を採用。構造化 JSON (`slog.NewJSONHandler`) 推奨
- level は `Error` (action 必要) / `Warn` (異常だが継続) / `Info` (通常運用) / `Debug` (開発時のみ)
- ctx は `LogAttrs(ctx, ...)` で渡し、interceptor が span・request_id を付与できる形に
- log message は固定文字列、可変値は attr (cardinality 制御 + grep 容易性)

**Don't**
- **PII / 認証情報の log 出力**
- `fmt.Println` / `log.Print*` での運用 log
- `slog.Info(fmt.Sprintf(...))` の interpolated message

## 6. Concurrency

**Do**
- mutex は保護対象を明示 (struct field 直前のコメント、または `mu sync.Mutex` 直後に保護対象を列挙)
- channel direction を関数 signature で限定 (`<-chan T` / `chan<- T`)
- 複数 IO の並行実行は `errgroup.Group` (context 連動 cancellation + 最初の error 取得)

**Don't**
- `ctx.Done()` も channel 受信もしない goroutine — leak 候補
- 保護対象が不明な `mu sync.Mutex`
- signature の両方向 channel (`chan T`)
- defer recover の無い goroutine 内 panic

## 7. Lint / format

**Do**
- `golangci-lint` **v2 系** (`.golangci.yaml` で config)。CI で必須
- `goimports` の local prefix は各 repo の module path に合わせる
- 推奨 linter: `errcheck` / `govet` / `staticcheck` / `ineffassign` / `unused` / `gosimple` / `gofmt` / `goimports`

**Don't**
- 理由コメントの無い `// nolint:` (正: `// nolint:errcheck // intentional fire-and-forget`)
- stdlib・3rd-party・local が混在した import 順序
- 戻り値 error の `_` への破棄

## 8. godoc / コメント

**Do**
- exported symbol には godoc 必須。package コメントは `// Package <name> ...` を各 package 1 file に
- **コメントは WHY を書く。WHAT は code が語る**
- unexported symbol への doc comment は任意 (書くなら WHY のみ 1-3 行)
- 「将来 X したい」は `TODO:` で書く
- `Deprecated:` は対象 symbol の godoc に明示

**Don't**
- **Phase / ticket ID をコメントに残す** (`Phase 0` 等の時系列・ticket scope 言及)
- 直下 code の逐語訳 doc block — **隣接 code がそうなっていても真似しない** (過去の生成物が規約から drift している可能性)
- godoc の無い exported symbol
- WHAT しか書いていないコメント
- unexported method の機械的な WHAT 説明 block (4 行以上は特に疑う)

## 9. Import order

**Do**
- stdlib / third-party / local の 3 group を空行で区切る (`goimports` の `-local` 設定で自動化)
- 各 group 内は alphabetical
- alias は衝突回避のみ (`pgsql "github.com/lib/pq"` は可)

**Don't**
- group 区切りなし
- 不要 alias (`f "fmt"` / `io2 "io"`)

## 10. Type safety / nil 安全

**Do**
- `interface{}` / `any` は本当に型不定なときのみ (passthrough は可)
- nil pointer 防御は constructor で nil reject

**Don't**
- 業務 logic 中の `any`
- 1 型での pointer receiver と value receiver の混在 (mutating method があるなら全 method pointer receiver)
- nil check 漏れの map 代入

## 検出方法

**Don't の検出手段は 3 系統ある。混同しない。**

### A. lint が落とす (skill 側で grep しない)

`.golangci.yaml` (`standard` + `revive` / `gocritic` / `misspell` / `gofmt` / `goimports`) が拾うもの:

| Don't | linter |
|---|---|
| godoc の無い exported symbol | `revive` (exported) |
| import 順序の混在 | `goimports` (自動修正) |
| 戻り値 error の `_` 破棄 | `errcheck` |
| `this` / `self` receiver、1 型での receiver 名の揺れ | `revive` (receiver-naming) |
| `errors.New(fmt.Sprintf(...))` | `gocritic` |

**`make lint` が green ならこれらは検出済み**として扱う。review で再走しない。

### B. grep で拾う (house 固有 — lint では落ちない)

```bash
# 2 文字 acronym の mixed case (revive の initialism リストに AI/IO/OS/DB は無い)
grep -rnE '\b[A-Za-z]*(Ai|Io|Os|Db)([A-Z]|\b)' --include='*.go' .

# 商標 acronym の case mix (openAIKey → openaiKey が正)
grep -rnE '\b[a-z]+(AI|API|OpenAI)[A-Z]' --include='*.go' .

# library 内の context.Background() (cmd/ と _test.go は除外)
grep -rn 'context.Background()' --include='*.go' internal/ pkg/ 2>/dev/null | grep -v '_test.go'

# 衝突 risk のある string key
grep -rn 'ctx.Value("' --include='*.go' .

# struct field の ctx (1 行 struct 記法にも当たるよう `{` 直後も見る)
grep -rnE '(^|\{)\s*ctx\s+context\.Context' --include='*.go' .

# 運用 log を fmt / 標準 log で出している
grep -rnE '(fmt\.Print|log\.Print|log\.Fatal)' --include='*.go' internal/ pkg/ 2>/dev/null

# interpolated な log message
grep -rnE 'slog\.[A-Z][a-z]+\(fmt\.Sprintf' --include='*.go' .

# 理由コメントの無い nolint
grep -rn 'nolint:' --include='*.go' . | grep -v '//.*nolint:.*//'

# 時系列 / ticket scope の言及
grep -rnE '(Phase [0-9]|TODO\(.*-[0-9]+\)|ticket)' --include='*.go' .

# signature の両方向 channel
grep -rnE 'func .*\bchan [A-Za-z]' --include='*.go' .
```

**grep は候補抽出であり判定ではない**。hit を必ず実物で確認する (生成コード / 慣用 pattern は「false positive 判定基準」で落とす)。

### C. 判断が要る (grep 不可)

grep では拾えず、**reviewer が読んで判断する**もの。検出できないことを自覚した上で見る:

- 「将来公開するかも」だけの exported symbol
- WHAT しか書いていないコメント / unexported method の機械的 WHAT doc block (4 行以上を grep で候補出しはできる)
- `mu sync.Mutex` の保護対象が不明 (宣言の grep で候補は出せる)
- goroutine の終了経路の有無
- `cmd/` 内の business logic / 過剰な抽象化 / altitude の不揃い

## False positive 判定基準

Don't にヒットしても、以下は違反扱いしない。

| 分類 | 判断 |
|---|---|
| 生成コード | 冒頭に `Code generated by ... DO NOT EDIT.` を含む file。生成元 schema 側で直す |
| 言語 / library の慣用 pattern | `http.Handler` 等の固定 signature。本 skill の規則より優先 |
| 意図的設計の例外 | code / docs で意図が明示されている決定 (例: shutdown context を signal-aware ctx から detach するための library 内 `context.Background()`) |
| public API 互換性 | 後方互換のため変えられない exported symbol。改名ではなく移行戦略を提案 |

疑わしい場合の除外は**禁止**。「false positive 候補」として flag し user 判断を仰ぐ。

## 出力

`code-refactor-advisor` から呼ばれた場合、section 別の違反 / 改善余地 list に以下を添えて返す。

- **どの Don't に当たるか** (根拠 section 番号)
- **修正方針** — 規約に揃える / 例外として残す / 別途議論
