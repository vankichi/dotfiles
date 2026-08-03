---
name: ddd-architecture
description: DDD の house 規約。**clean (Hexagonal) と layered (classic N-tier) の両 style を扱い、style により適用範囲が変わる**。layer 境界 / 依存方向 / Port-Adapter / ACL / Aggregate / Repository / DTO 変換 / cross-cutting を扱う。手順 skill ではない reference。
when_to_use: 「層が曖昧」「責務違反では」「port の切り方」「layered と同じ?」等の問いが来た時。設計 review / 層境界の判断 / refactor 候補出しの基準が要る時。`code-refactor-advisor` / `go-feature-tdd` からの参照。
---

# ddd-architecture

DDD の house 規約と検出シグナル集。**clean (Hexagonal) と layered (classic N-tier) の両 style を扱う** — §0 で style を確定してから読む。設計判断 / review / refactor 候補出しの判断基準。

**一般論 (Entity と Value Object の定義 / Repository pattern とは何か 等) は再掲しない** — 本 skill が持つのは house のレイアウトと選択、YAGNI の線引き、grep で違反を拾うための signal。

## 0. まず architecture style を確定する

**DDD には DIP を要求する形 (Clean / Hexagonal) と要求しない形 (Layered) がある。** DDD の戦術パターン (Entity / VO / Aggregate / Repository / UL / ACL) はどちらでも成立し、**Layered は劣化 Clean ではなく正当な変種** (Evans 原典は Layered)。style を確定せずに review すると、Layered で正しく書かれた code に「依存方向違反」「Port 抽象化欠如」を出してしまう。

| style | 依存の向き | Port (interface の所有者) | 本 skill の適用 |
|---|---|---|---|
| **clean** (= Hexagonal) | 常に内向き。外側との通信は Port 経由 | 内側 (Application) が定義し外側 (Adapter) が実装 | 全 section |
| **layered** (= classic N-tier / Evans 原典) | 上位層が下位層の concrete 型を直接参照してよい | **不要**。Repository は concrete 実装で足りる | **§2 と §11 の DIP 系を除外** |

**判定順**:

1. 対象 repo の `CLAUDE.md` / `.claude/rules/` に style の宣言があればそれに従う
2. 無ければ layout から推定 — `application/ports/` 相当があれば clean、無ければ layered
3. 判別できなければ **layered と仮定して進み、verdict に仮定を明記する** (安全側 = 過剰な指摘を出さない側)

**本質的な違いは依存方向の逆転の有無**であり、物理配置が層状に見えることではない。

**Clean Architecture と Hexagonal はほぼ同義** (Dependency Rule = 内向き依存 + Port は内側が定義し外側が実装、という同じ機構)。4 リングは下表の Domain / Application / Interfaces+Adapters / cmd に対応する。

## 1. Layer 定義

| Layer | path | 責務 | 依存可能な内側 |
|---|---|---|---|
| **Domain** | `internal/domain/` | Entity / VO / Aggregate / Domain Service / Domain Event / sentinel error。**外部依存を持たない** | (最内側) |
| **Application** | `internal/application/` | Use Case orchestration / Application Service / Port (interface 定義) / DTO | Domain |
| **Interfaces** | `internal/interfaces/` | Inbound adapter (gRPC / HTTP handler / CLI / interceptor / wire shape ⇄ DTO 変換) | Application + Domain |
| **Adapters** | `internal/adapters/` | Outbound adapter (DB / vendor SDK / external API。Port を実装) | Application (Port 実装) + Domain (型参照) |

**clean**: 依存は常に内向き。外側との通信は **Port 経由** (Application が定義し Adapter が実装)。内側 → 外側が必要なら Domain Event を発行し外側で subscribe して反転させる。

**layered**: 上位層が下位層の concrete 型を直接参照してよい。**Domain が外部 SDK / framework に依存しないことだけは両 style 共通で守る** (Evans の Domain 隔離。DIP とは別の要請)。

## 2. Port-Adapter — **clean のみ**

> **layered では本 section 全体が適用外**。Application が Repository の concrete 実装を直接使ってよく、interface の抽出は「差し替える予定がある」「test で fake を差す必要がある」時の任意の選択にすぎない。Port が無いことを違反として報告しない。

- **Port は vendor-neutral**。SDK 固有型を漏らさない (`[]float32` を渡し、`openai.EmbeddingResponse` を port shape に登場させない)
- Port の signature は**必要最小限の method** に絞る (1 method port も可)

```go
// Application 層: port 定義
type EmbeddingPort interface {
    Embed(ctx context.Context, req EmbedRequest) (*EmbedResult, error)
}

// Adapter 層: port 実装 (SDK 固有 logic は adapter 内に閉じる)
package openai
func (a *Adapter) Embed(ctx context.Context, req ports.EmbedRequest) (*ports.EmbedResult, error) { ... }
```

## 3. Anti-Corruption Layer (ACL)

外部 system / vendor との境界で**語彙 / 型 / 例外モデル**を変換する。adapter 内の boundary で vendor 固有 → port-neutral 変換と、**vendor 固有 error → port sentinel error の wrap** を行う。逆方向 (wire shape → application DTO) も同じ。

```go
sdkResp, err := a.client.Embeddings.New(ctx, openai.EmbeddingNewParams{...})
if err != nil {
    return nil, fmt.Errorf("openai: %w: %w", ports.ErrEmbeddingProviderUnavailable, err)
}
return toPortResult(sdkResp), nil
```

## 4. Ubiquitous Language

domain 用語は **business / docs / code で同じ語彙**を使う (docs で「ナレッジチャンク」なら code も `Chunk`)。wire shape (proto field 名 / JSON key) も UL に揃える。語彙が割れている場合は **docs 側で先に統一する** (ADR で確定させる)。

**検出**: 同一概念に package ごとに別名 (`User` / `Member` / `Account` 混在) / proto field 名と Go struct field 名の乖離 / docs と code で用語が違う

## 5. YAGNI の線引き

- **business rule が無い simple data は plain struct で十分**。過剰な Aggregate / Value Object 化はしない
- prototype 期は `Hit{ChunkID, Text, ...}` のような plain struct で start し、business rule が出てきたら昇格させる
- Aggregate を切るなら **Aggregate Root が business invariant を保護する** (`Document.AddChunk(c)` が chunk_sequence の連続性を保証する形)
- **Domain Event も過剰導入注意** — prototype 期は不要、audit / metrics / 連携が増えてから検討する

**検出**: Aggregate Root を skip して内部 entity が外部から直接編集されている

## 6. Application Service vs Domain Service

- **Application Service**: use case 単位の orchestration (複数 port / entity を呼んで 1 つの business operation を達成)。dependency (port 群 + logger) を注入する
- **Domain Service**: 単一 entity に閉じない domain logic。domain object のみ受け取る
- 両方 stateless

**検出**: Domain Service が port を import (依存方向違反) / Application Service が validation しかしていない (business orchestration が無く handler に統合できる)

## 7. Repository

DB / persistent store への抽象 (port の特殊形)。**entity 単位で粒度を切り** (`ChunkRepository` / `DocumentRepository`)、検索専用の read model は別に切ってもよい。**vendor-neutral** に保ち SQL / 表名 / SDK 詳細を漏らさない。

**検出**: Repository の引数 / 戻り値に SQL string / Repository が CRUD でなく business logic を含む (Application Service と責務混同)

## 8. DTO 変換

各層境界で変換を挟む: `Interfaces` 境界で wire shape ⇄ Application DTO、`Application` 境界で DTO ⇄ Domain entity、`Adapters` 境界で Domain ⇄ vendor SDK shape (= ACL)。変換 helper は境界 layer に置き、**pure function にする** (test 容易)。

**検出**: Domain entity が proto / JSON tag を持つ (wire shape と domain shape の混在) / wire shape のまま application 層を流れている

## 9. Cross-cutting concerns

Logging / Tracing / Auth / Rate Limit / Recovery は **interfaces / adapters 境界に置く** (gRPC は `UnaryServerInterceptor`、HTTP は middleware)。**Application / Domain layer に直接 import しない**。context key / logger factory は `internal/observability/` に置き各 interceptor が consume する。

**検出**: Application Service / Domain Service 内で `slog.Info(...)` を直接呼んでいる / auth check が handler 内に inline

## 10. 設定値の注入 (functional option + ConfigMap)

override は **3 段階**で expose する:

| 優先 | 経路 | 用途 |
|---|---|---|
| 1 | **default const** (`defaultXxx`、code hardcode) | 安全な base value |
| 2 | **functional option** (`WithXxx(...)` を constructor で inject) | deployment 単位の override、global 設定の wiring path |
| 3 | **proto field** (request 単位) | **例外**。「どうしても個別対応が必要」レベル (user 承認必須) |

通常運用は (1) + (2)。**proto 拡張は last resort**。

```go
const defaultRenderDPI = 150
func WithDPI(dpi int) PDFOption { return func(pp *PDFParser) { pp.dpi = dpi } }

// cmd/api-server/main.go (wiring)
parser := adapters.NewPDFParser(vlm, adapters.WithDPI(cfg.Parser.DPI)) // ConfigMap 値
```

**検出**: `defaultXxx` const が無く数値リテラルが散在 / `WithXxx(...)` が export されておらず cmd 側で override 不可 / adapter struct field が public (caller 直接代入で immutable 性が破綻) / proto field に adapter internal 値が露出

## 11. 検出方法

**3 系統に分かれる。混同しない。**

### A. lint が落とす

**層境界の違反は `depguard` (golangci-lint) で強制できる** — grep で毎回探すより確実。**style によって宣言する規則が変わる**:

```yaml
linters-settings:
  depguard:
    rules:
      # 両 style 共通: Domain の隔離
      domain:
        files: ["**/internal/domain/**"]
        deny:
          - pkg: "**/internal/adapters/**"
            desc: domain は infrastructure に依存しない
          - pkg: "**/internal/interfaces/**"
            desc: domain は presentation に依存しない

      # clean のみ: DIP の強制。layered ではこの rule を入れない
      application:
        files: ["**/internal/application/**"]
        deny:
          - pkg: "**/internal/adapters/**"
            desc: Port 経由で使う (concrete adapter の直 import は禁止)
```

**`application` rule は clean 専用**。layered の repo に入れると正常な依存を落とすので入れない。

導入すれば対応する grep は lint が落とすため review から外れる。未導入の repo では B で拾う。

### B. grep で拾う

```bash
# [両 style] Domain → 外側 import (Domain の隔離)
grep -rn 'import.*adapters\|import.*interfaces' internal/domain/

# [clean のみ] Application → concrete adapter import (ports 経由でない)
#   layered では正常な依存。実行しない
grep -rn 'import.*adapters/[a-z]\+/' internal/application/ | grep -v 'application/ports'

# [両 style] Adapter → interfaces import (横方向依存)
grep -rn 'import.*interfaces' internal/adapters/

# Port shape に SDK 固有型 (vendor 名は対象 repo に合わせる)
grep -rnE '(pineconego|openaigo|aws)\.' internal/application/ports/

# Application Service 内の logger 直接呼び (cross-cutting の混入)
grep -rnE 'slog\.(Info|Error|Warn|Debug)' internal/application/ | grep -v 'logger\.'

# handler / service 内の SDK 型直 import
grep -rnE '(pineconego|openaigo)' internal/interfaces/ internal/application/

# Repository の signature に SQL string
grep -rnE '(SELECT|INSERT|UPDATE|DELETE)' internal/application/ports/

# Domain entity が wire tag を持つ (層の混在)
grep -rnE '`(json|protobuf|yaml):' internal/domain/
```

**vendor 名 (`pineconego` 等) は対象 repo の実際の依存に置き換える** — skill 側に hardcode しない (`MEMORY.md` / `go.mod` から取る)。

### C. 判断が要る (grep 不可)

- **[clean のみ] adapter が Port を実装しているか** — 実装していないと位置付けが不明で ad-hoc に直接 import される。interface の充足は型を追わないと分からない
- **[clean のみ] Application code が adapter を concrete type で受け取っていないか** — test で fake を注入できるかで判定する。**layered では concrete 受け取りが正常**なので指摘しない
- **vendor 固有 error が sentinel wrap なしで漏れていないか** — error の流れを追う必要がある
- **YAGNI の線引き** — plain struct で足りるものを Aggregate 化していないか / Aggregate Root が invariant を守っているか
- **Ubiquitous Language の drift** — docs と code の語彙比較は機械化できない

## False positive 判定基準

以下は検出シグナルがヒットしても**違反扱いしない**:

- **生成コード**: 冒頭に `Code generated by ... DO NOT EDIT.` を含む file (生成元 schema 側で直す)
- **言語 / library の慣用 pattern**: 固定 signature 等。本 skill の規則より優先する
- **意図的設計の例外**: code / docs で意図が明示されている決定
- **public API 互換性**: 後方互換のため変えられない exported symbol

疑わしい場合は除外せず「false positive 候補」として flag し user 判断を仰ぐ。

## 出力

`code-refactor-advisor` から呼ばれた場合、**層別の責務マップ** (file × layer × 責務) / **層境界・依存方向の違反 list** (file:line + 違反内容) / **Port・Adapter・ACL 欠如**の指摘 / **UL drift** の指摘 と、修正方針 (層移動 / port 抽出 / DTO 変換層追加 等) を返す。
