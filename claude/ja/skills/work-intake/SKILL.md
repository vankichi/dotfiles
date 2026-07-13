---
name: work-intake
description: Notion の ready ticket を拾い、spec contract (rules/spec-contract.md) を検証して正規化 work item を返す Dev loop の入口 skill。「次の work 拾って」「ready ticket ある?」「work-intake」等で使う。contract を満たさない ticket は skip + 理由コメント。watch 対象 DB は memory reference から取得。
---

# work-intake

Dev loop の入口。ready な ticket を 1 件選び、dev-cycle が自律実装できる work item に正規化する。
**ticket 内容の修正・補完はしない** (直すのは人間 + write-spec)。

## 手順

### Step 1: 設定解決 (hardcode 禁止)

- `MEMORY.md` の reference memory から watch 対象 Notion DB / ready flag / 「進行中」status の表現を取得する
- memory reference は **project ごと**に登録が必要 (repo ごとに watch する DB が異なり得る)
- 見つからない場合は「memory reference 未登録」と明示して停止し、user から DB 情報を取得 → その project の memory に reference を登録してから続行する
- option: 引数に ticket URL が渡された場合は Step 2 の列挙を skip し、その ticket だけを対象にする

### Step 2: ready ticket 列挙

- `references/notion-adapter.md` の手順で ready 状態の ticket を列挙する
- 0 件なら「該当なし」と明示して正常終了する

### Step 3: contract 検証 (全項目判定を出力)

- 各 ticket に `~/.claude/rules/spec-contract.md` の検証 checklist を適用する
- **全項目の判定 (満たす / 満たさない + 理由) を必ず出力する** (黙った skip 禁止)
- 満たさない ticket: skip し、不備理由を ticket にコメントする (本文は編集しない)

### Step 4: 選択と状態遷移

- contract 充足 ticket から優先度順 (同優先度は古い順) に **1 件**選択する
- 呼び出し時に user の明示指示 (例:「ID が若い順」) がある場合はそれを優先度規則より優先し、規則からの逸脱を 1 行 flag する
- 選択 ticket の status を「進行中」相当に更新する (二度拾い防止。状態は source 側に置き、本 skill は状態を持たない)

### Step 5: work item 出力

```
## work item
- source: notion
- id: <ticket id>
- url: <ticket URL>
- 対象 repo: <spec メタから>
- 優先度: <spec メタから>
- 残り ready 件数: <N> (参考)

### spec
<目的 / スコープ・non-goals / 設計本体 / DoD / 制約 / メタ の全セクション>
```

## 障害時

- Notion MCP 不達 / auth 切れ: retry せず「Notion に到達できない」を明示して異常終了する (通知は呼び出し側の責務)

## 鉄則

1. ticket 内容の修正・補完をしない (non-goal)
2. contract 検証は全項目判定を出力する (黙った skip 禁止)
3. write は status 更新 + コメント追加のみ (ticket 本文の編集はしない)
4. ticket 本文を log / insights に丸ごと転記しない (参照は id / URL で)
5. DB 情報を skill に hardcode しない (memory reference が SoT)
