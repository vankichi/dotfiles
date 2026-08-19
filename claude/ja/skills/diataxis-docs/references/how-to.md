# how-to (goal-oriented)

読者は**仕事中**で、すでに competent。目的の達成だけを助ける。教えない。

## 原則

| 原則 | 具体 |
|---|---|
| 人の目的で書く (機械の操作で書かない) | ✗「Deploy ボタンを押す」 ✓「本番相当の負荷に耐える構成でデプロイする」 |
| title は動詞終止で内容そのもの | ✓「APM を導入する」 ✗「APM の導入」(可否の話かもしれない) ✗「APM」 |
| 現実の複雑さに開く | 条件分岐を書く (「<条件> の場合は〜」)。1 つの狭い case 専用にしない |
| 完全性より実用性 | 全 option を並べない。必要な範囲で始めて終わる。残りは reference に link |
| 順序に意味を持たせる | 依存関係だけでなく、思考の流れが途切れない順に並べる |
| 判断も手順のうち | 「何を見て何を決めるか」を書く。手を動かす操作だけが手順ではない |

## template: 汎用 how-to

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

障害対応の how-to。読者は on-call、深夜、焦っている。**上から順に実行できる形**にする。

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

- [ ] title が動詞終止で、読めば内容が分かる
- [ ] 冒頭で「誰のどの状況か」が分かる
- [ ] 教える内容 (概念解説 / 学習目的の寄り道) が入っていない
- [ ] 条件分岐が必要な箇所に if-then がある
- [ ] 確認手順がある。破壊的操作には戻し方がある
- [ ] 全 option の列挙になっていない (reference に link)
- [ ] runbook: Symptom / Impact / Diagnosis / Mitigation / Verification / Escalation が埋まっている

## よくある失敗

| 失敗 | なぜ悪いか |
|---|---|
| 「〜の設定」「〜について」という title | 手順か説明か判別できない |
| ツールの機能単位で章立てする | 読者の目的に対応しないので使われない |
| 全 flag を表で列挙する | reference の仕事。手順が埋もれる |
| 「まず〜の仕組みを理解します」 | 仕事中の読者に学習を強いる。architecture に link |
| runbook に平常時の運用手順を混ぜる | 障害時に読む分量が増える。通常の how-to に分ける |
