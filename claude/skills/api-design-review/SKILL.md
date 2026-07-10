---
name: api-design-review
description: API / 上流設計 (ADR / Design Doc / API 契約 / ドメインモデル / ACL) の考慮漏れを 6 軸で洗い出す read-only review skill。wire 表現に落とす前の logical 設計段階 — ExitPlanMode 前 / ADR 起票時 / Design Doc draft 完成時 — に invoke する。「設計 review して」「考慮漏れチェック」等で使う。
model: claude-fable-5
---

# api-design-review

API / システム上流設計の **turn を跨いだ段階的発覚を防ぐ** ための系統的レビュー skill。read-only (Edit / Write しない、Bash で grep のみ可)。

考慮漏れの源泉は wire 表現 (proto / OpenAPI) ではなく、その **前段のドメイン設計 / use case 分析 / ACL モデル / API 体験設計** にあるため、proto を書き始める **前** に通すのが最も効果的。proto を触り始めてからの review は補完用。

## 適用条件

以下のいずれかで invoke:

### 上流設計時 (主用途)
- 新 ADR を起票する **前** または draft 完成時 (MADR v3、`docs/adr/`)
- Design Doc / System Design (arc42 / C4) の新規作成 / 章追加時 (`docs/design/`)
- 新 API 契約 (proto / OpenAPI / GraphQL schema) の logical 設計時、wire に落とす前
- ドメインモデル / Aggregate / Bounded Context の新規 / 改訂時
- use case / user story 分析時、特に CRUD 以外の動詞が含まれる場合
- ACL / authorization / 多 tenant 分離モデルの設計時

### 下流補完 (proto / OpenAPI 触り始め後)
- 既存 message / enum の構造変更 (sub-message 切り出し / field rename / enum 値追加) 前
- SDK surface の改修時 (TypeScript / Go 等)
- 多 file refactor の plan-first 適用時、ExitPlanMode 前

### invoke しないとき
- バグ fix / typo / format / lint fix
- 既存 contract への影響なしの内部 refactor
- documentation のみの軽微更新

軽微な変更では CLAUDE.md「判断と質問の作法」の日常 check で足りる (本 skill は **重い分析専用**)。

## 進め方 (1 周 = 20-40 分目安、上流ほど時間を取る)

設計対象を確認 (ADR draft / Design Doc / proto / 関連 docs を Read) してから、以下 6 観点で **1 つずつ書き出す**。各観点で「該当なし」も明示する (空欄 = 未検討 = 漏れ)。

### 1. client 抽象 vs server 展開の分離

設計対象に登場する concept / 概念 / field / enum 値 / RPC parameter を列挙し、それぞれ:

- (a) **client / caller / 外部 user が直接認識・導出できる値**か (自分の id、user 入力、自社内設定値)
- (b) **server / platform が文脈から導出する値**か (他 tenant id、認証情報、内部 resource id、role / claims、cross-tenant fan-out 対象)
- (c) (b) を wire / 契約 / 公開 surface に置いている箇所がないか

(c) が見つかったら、wire から外して server-side concept に移す。SDK example も併せて check。

**check phrasing**: 「この概念を client がどう知るのか」「client が知っていてはいけない情報を contract に出していないか」

**過去事例**: `repeated string product_ids` を proto に置く案 → client は他 product_id を知らない (情報漏洩 + ACL bypass)、wire から外して server-side concept (collection-level config / access_group 等) に移した

### 2. ACL の読み / 書き 両側

ACL / 可視性 / アクセス制御が絡む場合 (絡まない場合は「該当なし」と明記):

- (a) **読み (search filter / fetch / row-level / collection ACL)** の表現と server 側挙動
- (b) **書き (visibility / scope 別の許可主体 / write authorization / role-based gating)** の表現と server 側挙動
- (c) 同 visibility でも内部投入 vs 外部投入 / admin vs regular で許可 role が違うケースを想定
- (d) 認可失敗の挙動 (403 vs 404 / 情報漏洩リスク)

書き許可は wire field ではなく ACL ドメイン層 (ReBAC / ABAC 等) で判定すべき (proto field に焼くと spoofable)。endpoint 分離 (`/v1/upsert` vs `/v1/admin/upsert`) は wire surface に権限境界を出す選択肢。

**check phrasing**: 「この visibility / scope を **誰が書ける** か」「個別 caller が広い visibility を書けるリスクは」

**過去事例**: PRODUCT_WIDE を個別 product client が書けるリスクの議論不在 → ACL の書き側を別 ADR (ReBAC/ABAC) で扱う方針に確定

### 3. forward-compat の系統的確認

設計対象が将来どう拡張されうるか、非破壊で対応可能か:

- enum 値追加 (proto3 で non-breaking、OpenAPI でも append OK)
- field 追加 (新 field number / property、proto3 / OpenAPI で non-breaking)
- 新 RPC / 新 endpoint / 新 service 追加
- 新 message / 新 schema 追加
- ADR 改訂 / 撤回時の互換性

将来予見される拡張 (cross-tenant / admin / batch / streaming / role / scope group / pre-signed URL / async worker / VLM / 多 region 等) を 3-5 件挙げ、それぞれ非破壊拡張で対応できるか確認。breaking 必要なケースは Phase 内で完結させる。

**check phrasing**: 「将来 X が来た時、契約をどう拡張するか」を各拡張ケースで 1-3 行記述

**過去事例**: 一過性のラベル (組織名 = academy 等) を enum / field に焼く設計が組織変更で rot、組織名フリーの命名 (CURATED / BOOK 等) に変更

### 4. edge case 列挙 ("こういう時どうするの?")

設計対象に対して以下のドメイン質問を **5-10 件書き出し、1 つずつ答える**:

- **同 ID 再投入 / 重複 / 冪等性** (Upsert: 上書き / `AlreadyExists` / version / soft delete / version vector)
- **empty / unspecified / null / zero value** (各 field でどう扱うか、validation で reject か defaulting か)
- **集合操作** (cross-tenant / cross-company / global wildcard `*` / 部分集合 / 全選択)
- **境界値** (max payload / max array length / pagination / rate limit / timeout / retry policy)
- **timezone / locale / encoding** (UTF-8 / multi-byte / collation / 日本語固有事情)
- **partial failure** (batch operation の途中失敗、idempotency / 補償 transaction)
- **順序 / 重複 / 冪等性 / 並行性**
- **認証 / 認可失敗の挙動** (403 vs 404 / 情報漏洩リスク)
- **形式変換 / 推測** (mime_type の auto-inference / explicit / fallback / 推測失敗時)
- **依存サービス障害時の挙動** (degraded / circuit breaker / fallback)

**check phrasing**: ドメイン寄りに「X でこういう時どうするの?」を 5-10 件出す。回答が「未検討」「将来検討」になった場合は、design phase で答えを出すべき領域

**過去事例**: source_type の「組織が消えたらどうする?」「内部 FAQ vs 外部 FAQ をどう分ける?」が turn 4 で発覚 → 分類軸を format に絞る判断に

### 5. 既存 SoT との整合 (grep-first)

新命名 / 新構造を出す **前** に既存 SoT を全 grep:

- 旧 field 名 / 旧 method 名 / 旧 enum 値 / 旧 ADR 番号 / 旧 design doc 用語が docs / api.md / metadata literal / SDK example / proto / Go code / Markdown notes に残っていないか
- 修正範囲を **全 file 一気に** 把握 (turn を跨いだ段階的発覚を防ぐ)
- design 完了時に grep 検証条件を 5-10 件用意 (`grep -nE "..."` の literal、PR description / commit description / ADR appendix で記録)

Bash で:
```bash
grep -rnE "<old-name-pattern>" docs/ apis/ internal/ cmd/ cli/
```

の hit list を design 結果に含めて、修正範囲を確定させる。

**check phrasing**: 「旧名 を grep して 0 hits になる条件は何か」「新名 が何箇所追加されるか」

**過去事例**: `accessScopes` 旧 surface が docs §11.2 SDK example に残置、turn 4 で発覚 → 設計時 grep で先に全箇所把握すべきだった

### 6. memory 規約準拠 (毎回チェック)

設計対象が以下 規約 のいずれにも違反していないか 1 周 review (SoT は CLAUDE.md / 各 skill):

| 規約 | 違反しがちな箇所 |
|---|---|
| Phase / ticket をコメントに残さない | proto / Go コメントに Phase / ticket / PR 参照 |
| commit title は簡潔 (1 行) | commit title が長文 |
| コード系コメントは英語 | *.go / proto / Makefile / shell コメントが日本語 |
| push は user 明示指示後 (CLAUDE.md) | push 提案が user 確認なし |
| test 内 inline コメント不可 | test 内 inline コメント |
| docs 冒頭に前提節を立てない | docs 冒頭の scope 前提節 |
| 個別 ticket plan を repo に置かない | docs/plan/ に個別 ticket plan |
| コメントは原文 literal 範囲 (推測 mapping 禁止) | コメントで原文 literal 範囲を超えた推測 mapping |
| 多 file 改修は plan-first (CLAUDE.md) | 多 file 改修なのに plan 飛ばし |
| spec 逸脱は明示・承認・記録 (CLAUDE.md) | spec literal 逸脱が plan に書かれていない |
| substantive edit は subagent 経由 | 主体 agent が直接 Edit (substantive) |
| PR は自動作成しない (CLAUDE.md) | PR 自動作成 |
| subagent brief は state-file 参照型 | subagent brief に context 反復 |
| 設計 phase checklist の遵守 | 本 checklist 自体の準拠漏れ |
| プロダクト用語の正確性 | プロダクト名・用語の誤称 |
| アーキ前提の遵守 | アーキテクチャ前提に反する用語混入 |

unused import / 機械的整合の漏れも本観点で check。

## 出力フォーマット

skill 完了時、以下を成果物として user に提示:

```markdown
# api-design-review 結果

## 設計対象
<対象 ADR / Design Doc / proto / API spec / domain model の path or 名前>

## 観点別レビュー

### 1. client 抽象 vs server 展開
- 検出: <内容、または「該当なし」>
- 対応案: <提案、または「現状で OK」>

### 2. ACL 読み書き両側
- 検出: ...

### 3. forward-compat
- 検出: ...

### 4. edge case 列挙
質問形式で 5-10 件、回答付き

### 5. 既存 SoT 整合 (grep 結果)
- `grep -rnE "..."` → hit list

### 6. memory 規約準拠
- 違反候補: <内容、または「クリア」>

## まとめ
- 設計を進めて OK (該当箇所なし): ◯
- 修正必要 (具体箇所): X 件 → ...
- user 判断要 (trade-off 提示): Y 件 → ...
```

main agent / dev-orchestrator / Plan agent / tech-docs-writer / notion-ticket-plan に引き継ぐ場合、上記を state-file に書き出すと subagent 再起動時の brief が薄くなる (state-file 参照型 brief)。

## 適用しないこと

- 実装 / Edit / Write は行わない (read-only review)
- git mutation / push / PR 作成しない
- skill 内で AskUserQuestion しない (結果を main agent に返し、main agent が user 判断を仰ぐ)

## 関連 artifact

- 日常 check (軽量版): CLAUDE.md「判断と質問の作法」
- 関連 skill: `tech-docs-writer` (ADR / Design Doc 起票時、本 skill を内部で通過)、`notion-ticket-plan` (ticket 解析 / plan 起票時、本 skill 通過)、`ddd-hexagonal` (層境界・依存方向、本 skill 観点 1 と関連)、`code-refactor-advisor` (実装面の refactor 候補、本 skill の implementation pass version)
- 主 agent への引き継ぎ: state-file 参照型 brief
- agent 側組み込み: `dev-orchestrator` agent の plan phase で本 skill を通過 (組み込み済)
