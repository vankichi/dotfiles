---
name: retrospect
description: dev cycle / 作業 session の最後に、詰まった点・やり直し・新規判明した規約や環境の癖を insights として 1 件記録する軽量 skill。分析・集約・改善 PR 化はしない (improve-harness の責務)。
when_to_use: cycle / 作業 session の終わりに、詰まった点・やり直し・新規判明した規約があった時。「retrospect して」「振り返り記録して」。該当なしなら書かない。
---

# retrospect

cycle 末の軽量記録。**1 分で書ける粒度を守る**。分析・集約・改善 PR 化は improve-harness の責務で、本 skill は記録のみ。

## 手順

### Step 1: 要点収集

直前の cycle / 作業から以下を洗い出す (該当なしなら記録せず終了してよい):

- 詰まった点 / やり直したこと
- user からの訂正・指摘
- 新規に判明した規約・環境の癖
- skill / agent / rules の欠陥や不足

### Step 2: category 判定

| category | 意味 |
|---|---|
| skill-gap | skill の手順・観点の不足や欠陥 |
| rule-gap | CLAUDE.md / rules/ の規約不足・曖昧さ |
| env-quirk | 環境・tool の癖 (再現する挙動) |
| spec-gap | spec contract / spec 内容の不備 |

skill-gap / rule-gap と分類する前に、**master 側の当該 file を確認する** (`git -C <dotfiles> diff origin/master -- <file>`)。稼働 harness は dotfiles working tree への symlink のため、稼働 copy が master から drift していた (= 規約は既に master に存在した) 可能性を排除してから skill / rule の欠陥と分類する。

### Step 3: insights ファイルに記録

対象 project の per-project dir に **1 insight = 1 ファイル**で書く。**「対象 project」= FB の target ファイルが属する project** (cycle の実行 repo とは限らない。harness への FB なら dotfiles 側):

- path: `~/.claude/projects/<encoded>/insights/<YYYYMMDD>-<slug>.md`
- `<encoded>` = 対象 project 絶対パスの `/` と `.` を `-` に置換 (CLAUDE.md「plan / session state file の保存先」と同じ規約)

```markdown
---
date: <YYYY-MM-DD>
category: skill-gap | rule-gap | env-quirk | spec-gap
ticket: <ticket URL / id / なし>
target: <対象の skill / agent / rules ファイル (あれば)>
---

## 事象

<何が起きたか 1-3 行>

## 提案

<どう直すべきか 1-3 行 (不明なら「未定」)>
```

## 鉄則

1. 記録のみ。分析・修正・PR 化はしない
2. 1 insight = 1 ファイル。まとめ書きしない
3. secret / ticket 本文の丸ごと転記をしない (参照は id / URL)
4. 該当なしの cycle は無理に書かない (ノイズを溜めない)
