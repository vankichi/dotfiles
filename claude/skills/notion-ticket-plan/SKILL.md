---
name: notion-ticket-plan
description: Notion / Linear / GitHub Issue の ticket URL を入力に、関連 docs / ADR を探索して実装プランを plan ファイルに書き出し plan モード承認を取る (planning 専用、実装はしない)。「ticket に沿って計画して」等で使う。
---

# notion-ticket-plan

ticket (Notion / Linear / GitHub Issue) URL を起点に、リポジトリの docs / ADR / 既存コードを探索し、**実装プランを plan ファイルに書き出して承認を取る**ところまでを担う skill。実装は行わない。

## 適用条件

- Plan モードで動くのが基本 (実装は別 skill / 別ターン)
- リポジトリに `docs/` や `ADR/` 等の設計ドキュメントがあると効果的 (なくても動く)

## 手順

### Step 1: ticket 取得

ticket URL から内容を読む。`Definition of Done`、スコープ、関連 ADR / 設計 doc への言及をメモする。

| ticket source | tool |
|---|---|
| Notion | `mcp__claude_ai_Notion__notion-fetch` |
| GitHub Issue / PR | `gh issue view` / `gh pr view` (Bash) |
| Linear | MCP があればそれ、なければ URL を WebFetch |
| その他 URL | WebFetch |

抽出する観点:
- DoD (受入基準)
- スコープ内 / スコープ外
- 関連する別 ticket (前後関係)
- deadline / status

### Step 1.5: DoD ↔ 既存 docs の literal 突合

DoD と既存 docs の両方が古い可能性があるため、両者を**並列に読み比較**して矛盾を抽出する。

1. DoD literal を抽出 (型名 / method 集合 / 配置 path / 設計責務 / 命名)
2. 関連 docs (`docs/design/*.md`、ADR) の literal を抽出
3. **矛盾点を網羅的に列挙**:
   - 命名 (例: `product_id` 単数 vs `product_ids` list)
   - method 集合 (例: 6 method vs 7 method)
   - 配置 path (例: `domain/ports` vs `application/ports`)
   - 設計責務レイヤー (例: ACL を adapter で組むか application で組むか)
4. **AskUserQuestion で採用 literal を user に確定してもらう**
   - DoD と docs どちらが新しい / 信頼できるか user 判断
   - 必要なら docs 側の修正を別タスクとして flag
5. 確定 literal を Step 6 の plan ファイルの "Confirmed decisions" に記録
6. **各矛盾箇所を Tier 1〜4 に分類** (docs / 実装 update の scope 判断)
   - **Tier 1**: 純粋な literal alignment (path / file name / type 名等の機械的揃え) → 本 ticket scope 内、実装と同 commit で修正
   - **Tier 2**: 確定 design の追従 (method 削除 / signature 更新等) → 本 ticket scope 内、実装と同 commit で修正
   - **Tier 3**: 設計判断必要 (caller 側の責務変更を伴う等)
     - 判断軸: 「この変更を実装しないと DoD を満たすか」
     - **DoD 必須なら同一 PR 内で実装**(設計判断は user に仰ぐ、実装も含めて scope 内)
     - DoD scope 外なら別 ticket、本 ticket では flag のみ
   - **Tier 4**: pseudocode / コード例の全面更新 (cosmetic だが分量大) → 別 commit / 別 ticket、本 ticket では flag のみ

**重要**: DoD を rule にしない。docs を rule にしない。**両者を並列提示して user に判断**してもらう。

### Step 2: 関連 docs 探索 (Explore subagent を最大 3 並列で起動)

Explore subagent を使って以下を並列で探索:

- 実装計画ファイル (`docs/plan/*.md` 等) の該当 ticket 周りの記述
- ADR (`docs/adr/*.md`) で関連する決定事項
- 設計 doc (`docs/design/*.md`)
- README / CLAUDE.md の関連情報
- 既存コード (該当機能の周辺)
- 既存 .gitignore / 設定ファイルでスコープに影響するもの

各 Explore に「具体的なファイルパス + 質問リスト」を渡す。返答は file:line で引用させる。

### Step 3: Plan agent で設計

Plan subagent を起動。前ステップで得た情報を背景として渡し、実装プランを書かせる。プロンプトに含める要素:

- ticket DoD (Step 1)
- 関連 ADR 抜粋 (Step 2)
- 既存ファイルの状況
- 確定済み前提
- 検討してほしい論点 (バージョン選定、命名、緩和ルール等)
- スコープ外項目 (別 ticket への引き継ぎ)

複雑なタスクなら最大 3 並列で異なる観点 (簡潔さ vs 拡張性 vs 保守性) を取らせる。

### Step 4: 主要ファイル直接読み込み

Plan agent の返答をもとに、修正対象ファイル / 関連設定ファイルを Read で直接確認する。Plan の前提が現状と合っているか検証。

### Step 5: 必要なら AskUserQuestion で論点詰め

不確定論点 (バージョン値、ライブラリ選択、tone) があれば 1-2 問に絞って AskUserQuestion。AskUserQuestion を「plan 承認」用には絶対に使わない (それは ExitPlanMode の役目)。

### Step 5.5: api-design-review skill で 6 観点 review

plan を書き出す **前** に、`api-design-review` skill を invoke して以下 6 観点で考慮漏れを catch:

1. client 抽象 vs server 展開の分離
2. ACL の読み / 書き 両側
3. forward-compat (enum / field / RPC 追加が非破壊で可能か)
4. edge case 列挙 ("こういう時どうするの?")
5. 既存 SoT との整合 (grep-first)
6. memory 規約準拠

検出された考慮漏れがあれば AskUserQuestion で user 判断を仰ぎ、plan に反映してから Step 6 へ。reviewer 視点での「あとから気づく」を抑制する。skill 結果は plan ファイルに「## Design review (api-design-review)」section として記録。

skill invoke 不要の判断軸: 単純な追加 / 既存 contract に影響ない内部 refactor / バグ fix / 軽微な改修。新 service / 新 RPC / 新 enum / 新 ACL モデル / 新 ADR / 設計責務レイヤーの変更が含まれる ticket では **必須通過**。

### Step 6: plan ファイル書き出し

- Plan モード提示の plan file path に最終プランを書く
- **plan ファイルは `~/.claude/plans/<ticket-slug>.md` を canonical な session state file として扱う**。後続の agent も Read して状態を引き継ぐ
- 構成:

```
# <Phase> / <Ticket ID>: <タイトル> — 実装プラン

## Context
なぜこの変更が必要か (DoD ベース)

## Confirmed decisions
Step 1.5 で確定した literal を列挙。再実装時の参照源、後続 agent が context bootstrap に使う。永続的な設計判断はここに置く (二度と変えない、spec 側を update する対象)。
| 判断項目 | 採用 literal | 根拠 (DoD / docs どちら) |

## Scope decisions (DoD 由来の意図的限定)
DoD で「stub のみで OK」「後続 ticket で実装」と明示されている範囲限定。逸脱ではなく意図的なので PR description には flag しない。
| 範囲限定項目 | DoD 根拠 | 後続 ticket |

## Spec deviations (PR description で flag、reviewer 確認対象)
DoD / docs と実装で割れる「永続的な構造選択」のみを列挙。Scope decisions / Phase 2+ migration は別カテゴリに振り分け、ここには **reviewer に「これで OK か」と確認したい項目だけ** を残す。
| # | 逸脱内容 | 是正方針 (spec update / 維持 / 後日見直し) |

## Phase 2+ migration (follow-up ticket 化)
prototype 段階の暫定実装で、production 移行時に refactor 予定のもの。Notion ticket comment 等に follow-up として記録、本 PR では実装しない。
| 暫定実装 | 将来形 | follow-up ticket / link |

## Carryover (既存問題、別 ticket)
本 ticket scope 外の既存問題で、本 PR では触らないが視認しておきたいもの。
| 既存問題 | 影響範囲 | 対応 ticket |

## Documentation updates (Tier 分類)
Step 1.5 で抽出した矛盾箇所を Tier 別に整理。本 ticket での扱いを明示する。
| 対象 doc | 修正内容 | Tier (1/2/3/4) | 扱い (同 commit / 同 PR / 別 ticket) |

## Current state (随時更新)
進行状態。後続 agent / 後日の自分が Read 1 回で context bootstrap できるように。
- Stage X 完了 / Y 進行中
- 直近 commit: <hash>
- Pending questions: ...

## Design review (api-design-review)
Step 5.5 で実行した api-design-review skill の結果 sumamry。考慮漏れ catch を監査可能に記録。
- 6 観点それぞれの検出有無
- 修正反映済の項目
- user 判断で resolved の項目
- 残置 (follow-up ticket) 項目

## 主要な設計判断
| 判断項目 | 決定 | 根拠 |

## 実装ステップ (実行順)
### Step 1: ...
- 新規 / 編集ファイル + 内容概要

## DoD と実装ステップの対応
| Notion DoD 項目 | 対応 Step | 検証方法 |

## 想定される落とし穴

## 検証手順 (実装完了後)

## 次のチケットへの引き継ぎ (スコープ外)

## 参照
- ticket URL
- docs/... のパス
```

### Step 7: ExitPlanMode で承認を取る

ExitPlanMode を呼んで plan 承認をリクエスト。allowedPrompts に実装で必要な Bash カテゴリを書く (例: `[{tool: "Bash", prompt: "go コマンド実行"}]`)。

## 鉄則

1. **plan モード厳守**: ファイル編集は plan ファイルのみ。それ以外は read-only
2. **ExitPlanMode で承認を取る**: 「いいですか?」「進めて良いですか?」と地の文で聞かない
3. **過去のメモリ feedback を尊重**: prototype 段階の前提節省略、用語規約 (例: tenant→company)、コメント言語など
4. **plan は scan-friendly**: 表 + 箇条書きを多用。長文段落は避ける
5. **scope 外を明示**: 別 ticket / 後続 phase で扱うものを必ず分離
6. **state file を maintain する**: 重要判断確定 / spec 逸脱発見のたびに plan ファイルを update。後続の agent / 後日の自分が Read 1 回で context bootstrap できる状態を保つ
7. **docs update の Tier 別運用**:
   - Tier 1+2 (機械的揃え / 確定 design 追従): 実装と同 commit で修正
   - Tier 3 (設計判断必要): DoD 必須なら同一 PR 内で実装、DoD scope 外なら別 ticket
   - Tier 4 (pseudocode 全面更新): 別 commit / 別 ticket
   
   plan ファイルの "Documentation updates" section に対象 doc / 修正内容 / Tier / 扱いを記録する

## 完了時の動き

ユーザーが ExitPlanMode を承認したら skill 終了。実装は別 skill (例: `/go-bootstrap`, `go-feature-tdd` subagent) や次ターンで行う。
