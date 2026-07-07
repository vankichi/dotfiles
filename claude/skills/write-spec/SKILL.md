---
name: write-spec
description: 人間の設計 draft を spec contract (rules/spec-contract.md) を満たす spec に仕上げる補佐 skill。設計判断はせず、穴の尋問・整形・contract 検証のみ行う。「spec にして」「spec 書くの手伝って」「設計を spec 化」等で使う。ready flag を立てるのは人間。
---

# write-spec

人間が主導して書いた設計を、agent (dev-cycle) が自律実装できる spec に仕上げる。
**設計判断はしない。実装計画も作らない。** 穴を見つけて聞き、埋まったら整形して検証するだけ。

## 入力

会話中の設計説明 / ローカル file / Notion page URL のいずれか。

## 手順

### Step 1: contract を読む

`~/.claude/rules/spec-contract.md` を Read する (必須セクション / 検証 checklist / ready の意味)。

### Step 2: draft を template にマップ

入力を必須セクション 1-6 に振り分け、埋まっていない・曖昧なセクションを列挙して user に提示する。

### Step 3: 尋問 (1 問ずつ)

`references/interrogation.md` の観点で、埋まっていない箇所を AskUserQuestion で 1 問ずつ確認する。

- 回答を勝手に補完しない。選択肢を出す場合も「推奨」は根拠付きで 1 つまで
- 人間が「これで良い」と確定した設計に異論を続けない (懸念は 1 回 flag して従う)
- 提案 (DoD 案 / 制約案 等) への確認を取る時は、**提案内容を質問文の中に再掲する** (直前メッセージへの参照だけだと user に見えないことがある)
- 全観点の実施状況 (実施 / skip + 理由) を記録し Step 5 の出力に含める

### Step 4: api-design-review の発火判定 (機械的)

設計本体に以下のいずれかが含まれる場合、`api-design-review` skill を invoke し、検出された考慮漏れを Step 3 の尋問に追加する:

- 新規 / 変更される API endpoint・RPC・event schema・enum・公開 interface (**repo 外に公開されるものが対象**。harness 内部の skill 間契約は対象外 — spec の設計本体で扱う)
- ACL / 権限モデルの変更

含まれない場合は skip し、理由を Step 5 の出力に明記する。

### Step 5: 整形と検証

spec を markdown で組み立て、contract の検証 checklist **全項目の判定を出力する** (満たす / 満たさない + 理由)。満たさない項目が残る場合は Step 3 に戻る。

### Step 6: 出力

- 完成 spec を提示する (Notion に貼れる markdown)
- Notion への書き込みは user の明示指示があった場合のみ (MCP 経由)
- **ready flag は立てない** — 「ready にするのは人間」と明記して終了する

## 鉄則

1. 設計判断・実装計画の代行をしない (補佐に徹する)
2. 検証 checklist と尋問観点は全項目の判定 / 実施状況を必ず出力する (黙った skip 禁止)
3. 尋問は 1 問ずつ (multiple choice 優先)
4. project 固有情報 (Notion DB 等) は hardcode せず MEMORY.md の reference から取得する
