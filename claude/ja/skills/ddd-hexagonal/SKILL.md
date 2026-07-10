---
name: ddd-hexagonal
description: DDD + Hexagonal architecture の reference skill。layer 境界 / 依存方向 / Port-Adapter / ACL / Aggregate / Repository / DTO 変換 / cross-cutting を扱う。「層曖昧」「責務違反」「port の切り方」等の問いや設計 review 時に参照する。手順 skill ではない。
---

# ddd-hexagonal

DDD + Hexagonal architecture の慣用句・原則を集めた reference skill。設計判断 / review / refactor 候補出しの判断基準として参照する。

## 適用条件

- DDD + Hexagonal を採用したプロジェクト (`internal/{domain,application,interfaces,adapters}/` レイアウト)
- code-refactor-advisor agent からの参照
- 層境界 / port 設計 / adapter 切り方の判断場面

## 1. Layer 定義

| Layer | path | 責務 | 依存可能な内側 layer |
|---|---|---|---|
| **Domain** | `internal/domain/` | Entity / Value Object / Aggregate / Domain Service / Domain Event / sentinel error。**外部に対する依存は持たない** (純粋ロジック) | (最内側、依存先なし) |
| **Application** | `internal/application/` | Use Case orchestration / Application Service / Port (interface 定義) / DTO | Domain |
| **Interfaces** | `internal/interfaces/` | Inbound adapter (gRPC handler / HTTP handler / CLI / interceptors / wire shape ⇄ application DTO 変換) | Application + Domain |
| **Adapters** | `internal/adapters/` | Outbound adapter (DB / vendor SDK / external API 実装、Port を実装) | Application (Port 実装のため) + Domain (型参照のため) |

検出シグナル:
- domain が adapter / application を import している (依存方向違反)
- adapter が interfaces を import している (横方向依存、reuse 不可)
- application が adapter を直接 import (= port 抽象化欠如)

## 2. 依存方向 (内向き原則)

```
Interfaces ──┐                                  ┌── Adapters
             ├──> Application ──> Domain <──────┤
             └─────────────────────────────────┘
```

- **依存は常に内向き** (外側 → 内側)。内側 (Domain) は外側 (Application / Adapters) を知らない
- 外側との通信は **Port (interface)** 経由。Application が Port を定義、Adapter が実装
- 内側 → 外側の通信が必要な場合は **Domain Event + 外側で subscribe** などの仕組みで反転

検出シグナル:
- Domain code 内に `import ".../adapters/..."` / `import ".../interfaces/..."`
- Application code 内に `import ".../adapters/concrete-vendor"` (= concrete adapter 直 import、port 経由でない)

## 3. Port-Adapter pattern

- **Port** = interface (Application 層に定義)。例: `EmbeddingPort` / `VectorStorePort`
- **Adapter** = Port の実装 (Adapters 層)。例: `openai.Adapter` (= `EmbeddingPort` 実装) / `pinecone.Adapter` (= `VectorStorePort` 実装)
- Port は **vendor-neutral**。SDK 固有型を漏らさない (e.g. `[]float32` を渡す、`openai.EmbeddingResponse` は port shape に登場させない)
- Port の signature には **必要最小限のメソッド**。adapter で使わない method は port に入れない (`I` 接尾辞 / `xxxer` 命名で 1 method port も OK)

例:
```go
// Application 層: port 定義
type EmbeddingPort interface {
    Embed(ctx context.Context, req EmbedRequest) (*EmbedResult, error)
}

// Adapter 層: port 実装
package openai
type Adapter struct { ... }
func (a *Adapter) Embed(ctx context.Context, req ports.EmbedRequest) (*ports.EmbedResult, error) {
    // SDK 固有 logic は adapter 内に閉じる
}
```

検出シグナル:
- Port shape に SDK 固有型が登場 (`*openai.EmbeddingResponse` / `*pinecone.QueryResponse` 等)
- Adapter が Port を実装していない (= adapter として位置付け不明、ad-hoc 直接 import される)
- Application code が adapter を concrete type で受け取っている (= mock 不可、test で fake 注入できない)

## 4. Anti-Corruption Layer (ACL)

- 外部 system / vendor との境界で **語彙 / 型 / 例外モデル** を変換する変換層
- adapter 内の boundary で **vendor 固有 → port-neutral** 変換 + **vendor 固有 error → port sentinel error** wrap
- 反対方向 (interface → application) も同じ。wire shape (proto / JSON) → application DTO 変換

例:
```go
// Adapter 内 ACL
func (a *Adapter) Embed(ctx context.Context, req ports.EmbedRequest) (*ports.EmbedResult, error) {
    sdkResp, err := a.client.Embeddings.New(ctx, openai.EmbeddingNewParams{...})
    if err != nil {
        return nil, fmt.Errorf("openai: %w: %w", ports.ErrEmbeddingProviderUnavailable, err)
    }
    // sdkResp.Data → []ports.Vector への変換
    return toPortResult(sdkResp), nil
}
```

検出シグナル:
- handler が SDK 型を引数 / 戻り値で扱っている (= ACL 欠如、application が vendor lock-in)
- Application 層が `pinecone.Client` を受け取っている (Port 経由でない)
- vendor 固有 error が application 層 / handler に直接漏れている (sentinel wrap なし)

## 5. Ubiquitous Language (UL)

- domain 用語は **business / docs / code で同じ語彙**を使う
- 例: docs で「ナレッジチャンク」と呼ぶなら code も `Chunk` (`Document` / `Item` 等の別名混在を避ける)
- wire shape (proto field 名 / JSON key) も UL に揃える
- 部署 / 関係者で語彙が割れている場合 → docs 側で先に統一する (ADR で語彙確定)

検出シグナル:
- 同じ概念に対して package ごとに異なる名前 (`User` / `Member` / `Account` / `Principal` 混在)
- proto field 名と Go struct field 名が異なる (`product_ids` ⇔ `ProductIDList`)
- docs と code で用語が違う (docs: 「コレクション」 / code: `Index` `Collection` 混在)

## 6. Aggregate / Entity / Value Object

- **Entity**: identity (ID) を持つ object。`Chunk{ID, Text, ...}` 等
- **Value Object**: identity なし、value の equality で判断。`Vector []float32` / `EmbedRequest{Inputs []string}` 等
- **Aggregate**: 整合性境界。Aggregate Root を経由してのみ内部 entity を操作する
- Aggregate Root は **business invariant を保護**。例: `Document` を root とすれば `Document.AddChunk(c)` で chunk_sequence の連続性を保証

注意:
- 過剰な Aggregate / Value Object 化は YAGNI。**business rule が無い simple data** は plain struct で十分
- Phase 1 prototype 期は `Hit{ChunkID, Text, ...}` のような plain struct で start、business rule が出てきたら昇格

検出シグナル:
- Entity と Value Object の区別が無い (= 全部 plain struct、ID 比較で identity 扱いされていない)
- Aggregate Root を skip して内部 entity が外部から直接編集されている

## 7. Application Service vs Domain Service

- **Application Service**: use case 単位の orchestration。複数 port / domain entity を呼び出して 1 つの business operation を達成
- **Domain Service**: 単一 entity に閉じない domain logic (entity 同士の演算 / domain rule 検証)
- 両方 stateless。Application Service は dependency 注入 (port 群 + logger)、Domain Service は domain object のみ受け取る

例:
```go
// Application Service (推奨 pattern)
type Service struct {
    embedding   ports.EmbeddingPort
    vectorStore ports.VectorStorePort
}
func (s *Service) Search(ctx, in SearchInput) (*SearchOutput, error) {
    // Embed → vector search → hit 変換 (use case orchestration)
}
```

検出シグナル:
- Domain Service が port を import (依存方向違反)
- Application Service が validation だけしている (= business orchestration が無い、handler に統合できる)
- Application Service が 1 method しかない (= use case 1 つだけ、struct にする意義が薄い場合あり)

## 8. Repository pattern

- DB / persistent store への抽象は **Repository** (port の特殊形)
- entity 単位で粒度を切る: `ChunkRepository` (CRUD on Chunk) / `DocumentRepository`
- 検索専用 / read model は別 Repository に切ることもある (`ChunkSearchRepository`)
- **Vendor-neutral**。SQL / 表名 / SDK 詳細を漏らさない

例:
```go
type ChunkRepository interface {
    Save(ctx context.Context, c Chunk) error
    GetByID(ctx context.Context, id string) (*Chunk, error)
    Delete(ctx context.Context, id string) error
}
```

検出シグナル:
- Repository に SQL string が引数 / 戻り値に登場
- Repository が CRUD ではなく business logic を含む (= Application Service と責務混同)

## 9. DTO / wire shape vs domain shape

- 各層境界で **DTO 変換**を挟む:
  - `Interfaces` 境界: wire shape (proto message / JSON request) ⇄ Application DTO (`SearchInput` / `SearchOutput`)
  - `Application` 境界: Application DTO ⇄ Domain entity / Value Object
  - `Adapters` 境界: Domain ⇄ vendor SDK shape (Anti-Corruption Layer)
- DTO 変換 helper は境界 layer に置く (`internal/interfaces/grpc/search_handler.go` 内 `toProtoResponse` 等)
- DTO 変換は pure function 推奨 (test 容易)

検出シグナル:
- Domain entity が proto field tag を持つ / JSON tag を持つ (= wire shape と domain shape が混在)
- Wire shape のまま application 層を流れている (= DTO 変換欠如)

## 10. Cross-cutting concerns

- **Logging / Tracing / Auth / Rate Limit / Recovery** は cross-cutting で、**interfaces / adapters 境界に置く**
- gRPC: `UnaryServerInterceptor` / HTTP: middleware
- Application / Domain layer に直接 import しない (= business logic と分離)
- 例: `internal/observability/` に context key / logger factory を置き、各 interceptor が consume

検出シグナル:
- Application Service / Domain Service の中で `slog.Info(...)` が直接呼ばれている (= cross-cutting がbusiness logic に混入)
- auth check が handler 内 inline で書かれている (= interceptor / middleware に切り出すべき)

## 11. Domain Event (optional)

- aggregate 内の状態変化を event として publish、外側 layer で subscribe
- 反対方向依存を回避するため: domain は event を発行するのみ、subscribe は application / adapter
- 過剰導入注意: Phase 1 prototype 期は不要、Phase 2 で audit / metrics / 連携が増えてきたら検討

## 12. 検出シグナル総括 (refactor 候補洗い出し用)

agent から呼ばれたとき、以下の grep パターンで違反を検出:

| 違反 | 検出 grep |
|---|---|
| Domain → 外側 import | `grep -r 'import.*adapters\|import.*interfaces' internal/domain/` |
| Application → concrete adapter import | `grep -r 'import.*adapters/[a-z]\+/' internal/application/ \| grep -v 'application/ports'` |
| Adapter → interfaces import | `grep -r 'import.*interfaces' internal/adapters/` |
| Port shape に SDK 固有型 | `grep -rn 'pineconego\.\|openaigo\.\|aws\.' internal/application/ports/` |
| Application Service 内 logger 直接呼び | `grep -rn 'slog\.Info\|slog\.Error' internal/application/ \| grep -v 'logger\.'` |
| handler / service 内に SDK 型直 import | `grep -rn 'pineconego\|openaigo' internal/interfaces/ internal/application/` |
| Repository に SQL string | `grep -rn 'SELECT\|INSERT\|UPDATE\|DELETE' internal/application/ports/` |

## 13. Configuration injection (functional option + ConfigMap)

設定値の override は **3 段階** で expose する:

| Priority | 経路 | 用途 |
|---|---|---|
| 1 | **default const** (`defaultXxx`、code hardcode) | Phase 1 動作確認、安全な base value |
| 2 | **functional option** (`WithXxx(...)` constructor 時 inject) | deployment 単位 override、global 設定の wiring path |
| 3 | **proto field** (request 単位 inject) | **例外**、「どうしても個別対応必要」レベル (user 承認必須) |

通常運用は (1) + (2)。proto 拡張は last resort。

例:
```go
const defaultRenderDPI = 150
func WithDPI(dpi int) PDFOption { return func(pp *PDFParser) { pp.dpi = dpi } }

// cmd/api-server/main.go (wiring)
parser := adapters.NewPDFParser(vlm, adapters.WithDPI(cfg.Parser.DPI)) // ConfigMap 値
```

検出シグナル (refactor 候補):
- adapter / service に `defaultXxx` const なし → 数値リテラルが code 内に散在
- `WithXxx(...)` Option が export されていない → cmd 側で値を override 不可
- adapter struct field が public → caller 直接代入で immutable 性破綻
- proto field に adapter internal 値が露出 → wire surface 膨張

project に functional option 採用の ADR があればそちらも参照。

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
- 対象 codebase に対する **層別 責務マップ** (file × layer × 責務)
- **層境界 / 依存方向違反** list (file:line + 違反内容)
- **Port / Adapter / ACL 欠如** の指摘
- **Ubiquitous Language drift** の指摘
- 修正方針 (層移動 / port 抽出 / DTO 変換層追加 / etc.)

## 参照

- Eric Evans, "Domain-Driven Design"
- Vaughn Vernon, "Implementing Domain-Driven Design"
- Alistair Cockburn, "Hexagonal architecture": https://alistair.cockburn.us/hexagonal-architecture/
- Mark Seemann, "Dependency Injection in .NET" (依存方向の議論)
- project の ADR (DDD + Hexagonal 採用判断) があれば参照
