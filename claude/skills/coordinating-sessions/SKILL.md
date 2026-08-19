---
name: coordinating-sessions
description: 並行して動いている別の Claude session (research session / implementation session / review session) と調査結果・修正 plan・質問をやり取りする手順。「research session に渡して」「調査結果を受け取って実装しよう」「別 session に聞いて」「plan を実装 session へ」のように、片方の session が出した成果をもう片方が使う時に使用する。相手が到達不能な場合の file 経由 fallback も含む。
---

# 別 session との連携

調査役と実装役を別 session に分けて回す時の手順。**役割を跨がないこと**と、**受け手が self-contained に動けること**の 2 点が要。

## 宛先の解決

1. `ListAgents` を実行する
2. 出力された **name を正確にコピー**して `SendMessage({to: "<name>", message: "..."})`
3. `No reachable agents` なら **file 経由 fallback** へ (下記)

**名前を推測して送らない**。同名が複数ある時だけ行末の ` [ref]` を付ける。

## 役割の境界

| session | やること | やらないこと |
|---|---|---|
| research / review | 調査・plan 作成・質問への回答 | **code を編集しない** |
| implementation | 実装・test・commit | 調査を一からやり直さない |

**両 session が同じ file を編集すると衝突する**。調査役に「ついでに直して」と言われたら、実装役へ渡す形に誘導する。

## 渡す側 — handoff payload

受け手は**こちらの会話履歴も state file も読めない**。単体で実行可能な形にする。

```
## 目的
<何を達成するか 1-2 行>

## 対象
- <file:line> — <何をどう変える>

## 方針
<既存実装のどの pattern を踏襲するか。なぜその方式か>

## 触らない範囲
- <file / 機能> — <理由>

## 検証
- <実行するコマンド> → <期待する結果>

## 未決 (実装側の判断が要る点)
- <選択肢と trade-off。無ければ「なし」>
```

**「未決」を空欄にしない**。判断を渡し忘れると受け手が勝手に埋める。

渡したら**自分は実装に着手しない**。

## 受け取る側

1. payload の**機械検証可能な主張を自分で確かめる** — file:line の実在 / 関数 signature / test の現状の合否。`~/.claude/rules/verify-before-assert.md` が SoT
2. ズレを見つけたら**実装を進めず相手 session に返す** (自分の解釈で修正しない)
3. 「未決」項目は user か相手 session に確認してから着手する

## 質問する

1 往復で終わる形にする。**何を知りたいか + なぜ必要か + 自分が既に確認した範囲**を書く。

```
Q: <質問>
文脈: <どの実装判断のために要るか>
確認済み: <自分が既に見た file / 実行したコマンドと結果>
```

**返答が来るまで、その判断に依存する実装を進めない**。憶測で埋めて後から直すと handoff の意味が消える。

## 到達不能時の fallback

`ListAgents` が `No reachable agents` を返したら:

1. **返答を捏造しない**。「聞いた」「確認済み」と報告しない
2. handoff payload を per-project plans dir (`~/.claude/projects/<encoded>/plans/`) に `handoff-<topic>.md` として書く
3. user に **path を伝えて停止する**

相手 session が後から立ち上がった時、この file がそのまま入力になる。
