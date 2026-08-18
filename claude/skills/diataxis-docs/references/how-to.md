# how-to (goal-oriented)

The reader is **at work** and already competent. Help them reach the goal, nothing else. Do not teach.

## Principles

| Principle | Concretely |
|---|---|
| Write from the human's purpose (not the machine's operation) | ✗「Deploy ボタンを押す」 ✓「本番相当の負荷に耐える構成でデプロイする」 |
| The title ends with a verb and says exactly what it shows | ✓「APM を導入する」 ✗「APM の導入」(might be about whether to) ✗「APM」 |
| Stay open to real-world complexity | Write conditional branches (「<条件> の場合は〜」). Don't serve exactly one narrow case |
| Usability over completeness | Don't list every option. Start and end somewhere reasonable. Link the rest to reference |
| Give the ordering meaning | Order by dependencies, and also so the reader's train of thought is not broken |
| Judgement is part of the procedure | Write "what to look at and what to decide". Physical operations aren't the whole procedure |

## template: general how-to

````markdown
---
title: <目的>を<動詞>する
description: <どの状況の誰が><何を達成するか>
---

# <目的>を<動詞>する

<この手順で解決する問題を 1-2 文>。<対象読者の前提>。

## 前提

- <権限 / 事前状態>

## 手順

1. <動詞で始める>

   ```bash
   <command>
   ```

2. <動詞で始める>

   <条件A> の場合は <対応A>、<条件B> の場合は <対応B> を選びます。判断材料は <観測点>。

## 確認

```bash
<verification command>
```

<期待される状態>。

## 元に戻す

```bash
<rollback command>
```

## 関連

- 全 option: [<reference>](../reference/<topic>.md)
- 背景: [<architecture>](../architecture/<topic>.md)
````

## template: runbook (`docs/how-to/runbook/<alert>.md`)

A how-to for incident response. The reader is on-call, it's the middle of the night, and they are stressed. Make it **executable top to bottom**.

````markdown
---
title: <アラート名 or 症状>
description: <アラート名> 発火時の切り分けと復旧手順
---

# Runbook: <アラート名 or 症状>

| 項目 | 値 |
|---|---|
| アラート | `<alert name>` |
| 深刻度 | <SEV> |
| 一次対応者 | <role> |
| エスカレーション先 | <role / channel> |

## Symptom (症状)

- <観測される事象>
- ダッシュボード: <link>

## Impact (影響)

- <誰の何が壊れるか>。<SLO への影響>

## Diagnosis (切り分け)

1. <確認コマンド / クエリ>

   ```bash
   <command>
   ```

   | 結果 | 次に進む先 |
   |---|---|
   | <パターンA> | Mitigation A |
   | <パターンB> | Mitigation B |

## Mitigation (暫定対応)

### A. <対応名>

```bash
<command>
```

### B. <対応名>

...

## Verification (復旧確認)

- <確認手順>。<正常値>

## Resolution (恒久対応)

- <根本対応 / 起票先>

## Escalation

- <条件> を満たす場合は <連絡先> へ即エスカレーション

## Postmortem

- <SEV> 以上は postmortem 必須。テンプレート: <link>
````

## checklist

- [ ] The title ends with a verb and reading it tells you the content
- [ ] The opening makes clear "who, in what situation"
- [ ] No teaching material (conceptual explanation / learning detours)
- [ ] if-then branches wherever they are needed
- [ ] A verification step exists. Destructive operations have a way back
- [ ] Not an enumeration of every option (link to reference)
- [ ] runbook: Symptom / Impact / Diagnosis / Mitigation / Verification / Escalation are filled in

## Common failures

| Failure | Why it's bad |
|---|---|
| Titles like 「〜の設定」「〜について」 | You can't tell whether it's a procedure or an explanation |
| Chaptering by the tool's features | Doesn't map to the reader's goal, so it goes unused |
| Tabulating every flag | That's reference's job. The procedure gets buried |
| 「まず〜の仕組みを理解します」 | Forces study on a reader who is working. Link to architecture |
| Mixing steady-state operations into a runbook | Increases what must be read during an incident. Split into a normal how-to |
