---
name: api-design-review
description: API / 上流設計 (ADR / Design Doc / API 契約 / ドメインモデル / ACL) の考慮漏れを 6 軸で洗い出す read-only review skill。wire 表現に落とす前の logical 設計段階 — ExitPlanMode 前 / ADR 起票時 / Design Doc draft 完成時 — に invoke する。
when_to_use: ADR / Design Doc の起票前・draft 完成時、新 API 契約を wire に落とす前、ドメインモデル / ACL の設計時。「設計 review して」「考慮漏れチェック」。バグ fix / typo / 内部 refactor では使わない。
model: fable
---

# api-design-review

上流設計の **turn を跨いだ段階的発覚を防ぐ** ための系統的レビュー skill。read-only (Edit / Write しない、Bash は grep のみ)。**principal engineer の視座で行う**: 表現の妥当性ではなく設計判断そのものの正しさ — 将来の拡張・運用・保守者にとって正しいか — を問う。

考慮漏れの源泉は wire 表現 (proto / OpenAPI) ではなく前段のドメイン設計 / use case 分析 / ACL モデルにあるため、**proto を書き始める前**に通すのが最も効果的。

## 適用条件

**通す**: 新 ADR の起票前 / Design Doc の新規作成・章追加 / 新 API 契約の logical 設計 (wire に落とす前) / ドメインモデル・Aggregate・Bounded Context の新規改訂 / CRUD 以外の動詞を含む use case 分析 / ACL・authorization・多 tenant 分離の設計。下流補完として既存 message・enum の構造変更前、SDK surface 改修時にも使える。

**通さない**: バグ fix / typo / format / lint / 既存 contract に影響しない内部 refactor / 軽微な docs 更新。軽微な変更は CLAUDE.md の日常 check で足りる (本 skill は重い分析専用)。

## 進め方 (1 周 20-40 分目安)

設計対象 (ADR draft / Design Doc / proto / 関連 docs) を Read してから、以下 6 観点を **1 つずつ書き出す**。各観点で「該当なし」も明示する (**空欄 = 未検討 = 漏れ**)。

### 1. client 抽象 vs server 展開の分離

登場する概念 / field / enum 値 / RPC parameter を列挙し、(a) client が直接認識・導出できる値か (自分の id / user 入力 / 自社内設定値)、(b) server が文脈から導出する値か (他 tenant id / 認証情報 / 内部 resource id / role / cross-tenant fan-out 対象)、(c) **(b) を wire / 契約 / 公開 surface に置いている箇所が無いか** を判定する。(c) があれば wire から外し server-side concept に移す。SDK example も併せて確認。

- **問い**: 「この概念を client がどう知るのか」「client が知っていてはいけない情報を contract に出していないか」
- **事例**: `repeated string product_ids` を proto に置く案 → client は他 product_id を知らない (情報漏洩 + ACL bypass) → server-side concept へ移動

### 2. ACL の読み / 書き 両側

ACL / 可視性 / アクセス制御が絡む場合 (絡まなければ「該当なし」と明記):

- **読み** (search filter / fetch / row-level / collection ACL) の表現と server 側挙動
- **書き** (visibility / scope 別の許可主体 / write authorization / role-based gating) の表現と server 側挙動
- 同 visibility でも内部投入 vs 外部投入 / admin vs regular で許可 role が違うケース
- 認可失敗の挙動 (403 vs 404 / 情報漏洩リスク)

書き許可は wire field ではなく **ACL ドメイン層 (ReBAC / ABAC) で判定する** (proto field に焼くと spoofable)。endpoint 分離 (`/v1/upsert` vs `/v1/admin/upsert`) は権限境界を wire surface に出す選択肢。

- **問い**: 「この visibility / scope を**誰が書ける**か」「個別 caller が広い visibility を書けるリスクは」

### 3. forward-compat の系統的確認

将来予見される拡張 (cross-tenant / admin / batch / streaming / role / scope group / pre-signed URL / async worker / 多 region 等) を 3-5 件挙げ、それぞれ **非破壊拡張で対応できるか** を 1-3 行で書く。enum 値追加 / field 追加 / 新 RPC / 新 message は proto3・OpenAPI で non-breaking。breaking が必要なケースは Phase 内で完結させる。

- **事例**: 一過性のラベル (組織名) を enum に焼く設計が組織変更で rot → 組織名フリーの命名 (CURATED / BOOK 等) へ変更

### 4. edge case 列挙

以下の軸からドメイン質問を **5-10 件書き出し、1 つずつ答える**。回答が「未検討」「将来検討」になった領域が、この phase で答えを出すべき箇所:

同 ID 再投入 / 重複 / 冪等性 (上書き か `AlreadyExists` か version か soft delete か) / empty・null・zero value の扱い (reject か defaulting か) / 集合操作 (cross-tenant / wildcard / 部分集合) / 境界値 (max payload / array 長 / pagination / rate limit / timeout / retry) / timezone・locale・encoding (UTF-8 / multi-byte / 日本語固有事情) / partial failure (batch 途中失敗の補償) / 順序と並行性 / 認可失敗の挙動 / 形式変換と推測 (auto-inference の失敗時) / 依存サービス障害時 (degraded / circuit breaker) / **状態遷移の運用再実行** (その状態に落ちた対象を運用者が redrive するとどうなるか)

- **事例**: source_type の「組織が消えたらどうする?」「内部 FAQ と外部 FAQ をどう分ける?」が turn 4 で発覚 → 分類軸を format に絞る判断に

### 5. 既存 SoT との整合 (grep-first)

新命名 / 新構造を出す**前**に既存 SoT を全 grep する。旧 field 名 / 旧 method 名 / 旧 enum 値 / 旧 ADR 番号 / 旧用語が docs / metadata literal / SDK example / proto / code / notes に残っていないか、**repo 全体**を対象に調べる (dir 列挙で絞ると root の instruction file が漏れる):

```bash
git grep -nE "<old-name-pattern>"
```

root の instruction file 群 (`CLAUDE.md` / `.github/copilot-instructions.md` / `.claude/rules/`) は agent が毎回 load するため、stale な契約が後続実装へ伝播する経路 — 必ず含める。逆に改訂履歴 / changelog 行は immutable なので hit しても触らない。

**名前 grep は必要だが不十分**。設計対象が producer / worker 等の process flow を記述する場合、関連する Accepted ADR / design doc の **flow / lifecycle 記述** (どの行を誰がいつ作るか / dedup 方式 / 失敗時の観測境界) まで読み合わせ、設計案と矛盾しないか確認する。

**新設する状態が既存 runbook の前提遷移を壊さないか**も同時に見る: 新規に書く状態を列挙 → 各状態からの出口が state machine にあるか → 出口の無い terminal 状態を前提にした運用手順 (「redrive で再処理」型) が docs に無いか grep する。terminal 状態の書き手を新設した瞬間に既存手順と矛盾する構造は、実装前のこの段階でしか安く検出できない。

- **問い**: 「旧名を grep して 0 hits になる条件は何か」「関連 Accepted ADR の flow 記述と設計案の flow が一致するか」
- **事例 (naming)**: `accessScopes` の旧 surface が docs の SDK example に残置し turn 4 で発覚
- **事例 (flow)**: ticket の producer/worker flow (enqueue 前に PENDING 作成 / 明示 dedup) が関連 Accepted ADR の中核決定 (worker が受信時に INSERT / content-based dedup) と真逆。field 名 grep は naming overlap を拾ったが散文フローの矛盾を見逃し、review iteration の cap でようやく発覚 → escalation

### 6. memory 規約準拠

設計対象が規約に違反していないか 1 周見る (SoT は CLAUDE.md / 各 skill)。違反しがちな箇所:

Phase / ticket / PR 参照をコメントに残す / コード系コメントが日本語 / test 内 inline コメント / docs 冒頭に前提節 / repo に個別 ticket plan を置く / コメントで原文 literal を超えた推測 mapping / 多 file 改修で plan を飛ばす / spec 逸脱が plan に書かれていない / PR の自動作成 / プロダクト用語の誤称 / アーキ前提に反する用語混入。unused import 等の機械的整合もここで見る。

## 出力

観点ごとに「検出 (または該当なし)」と「対応案 (または現状で OK)」を書き、末尾にまとめ (進めて OK / 修正必要 X 件 / user 判断要 Y 件) を出す。観点 4 は質問と回答の形で 5-10 件、観点 5 は grep の hit list を含める。

dev-cycle から呼ばれた場合、結果 summary は state file の「Design review」section に記録される (記録の規定は dev-cycle 側)。

## 適用しないこと

実装 / Edit / Write / git mutation / PR 作成はしない。skill 内で `AskUserQuestion` もしない (結果を呼び出し元に返し、呼び出し元が user 判断を仰ぐ)。
