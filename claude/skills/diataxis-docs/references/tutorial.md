# tutorial (learning-oriented)

The reader is **studying**. The goal is not "getting something finished" but "gaining the conviction that they can do it". The teacher is absent, so **the author carries all the responsibility**.

## Principles

| Principle | Concretely |
|---|---|
| State the destination first | 「このチュートリアルでは〜を作ります」. Never write 「〜を学べます」 (presumptuous) |
| Show results early and often | Every step produces output the reader can verify |
| Put expectations into words | 「数秒後に〜と表示されます」「数百行の log が流れます」. Paste the sample output |
| Point out what to notice | Point at changes the reader would miss, e.g. 「prompt が `(venv)` に変わります」 |
| Cut the explanation | One line of reasoning at most. Link to `docs/architecture/` for the depth |
| Offer no options | No branches, no alternative commands, no 「お好みで」. Keep a single path |
| Make repetition possible | Each step can be redone. Avoid irreversible operations, or attach the way back |
| Make it perfectly reproducible | Same result for anyone, anytime. Pin versions, state prerequisites |

**A tutorial for an IDP = the golden path** — create one service from the standard scaffold, get CI green, and confirm traffic works. Deviation procedures belong to how-to.

## template

````markdown
---
title: はじめての <対象>
description: <対象> を雛形から作成し、<環境> で疎通するまでを一通り体験する
---

# はじめての <対象>

このチュートリアルでは <対象> を作成し、<環境> にデプロイして疎通するところまでを行います。所要時間は約 <N> 分です。

途中で <ツールA> と <ツールB> を使いますが、いま理解する必要はありません。詳しくは [<link>](../architecture/<topic>.md) を参照してください。

## 前提

- <CLI> v<X.Y> 以上がインストール済み
- <権限> が付与済み (未付与の場合は [<申請手順>](../how-to/<goal>.md))

前提が揃っているか確認します。

```bash
<check command>
```

次のように表示されれば準備完了です。

```
<期待される出力>
```

## 1. <動詞で始める見出し>

```bash
<command>
```

<結果の説明>。次のように表示されます。

```
<期待される出力>
```

`<注目点>` が変わったことに注目してください。これは <一言の意味> です。

## 2. <動詞で始める見出し>

...

## できたこと

<対象> を作成し、<環境> で動かすところまで到達しました。ここまでで <要素A> / <要素B> / <要素C> に一通り触れています。

## 次にやること

- 実際の業務で <目的> を行う → [<how-to>](../how-to/<goal>.md)
- 仕組みを知る → [<architecture>](../architecture/<topic>.md)

## うまくいかない時

| 症状 | 対処 |
|---|---|
| <エラーメッセージ> | <対処> |
````

## checklist

- [ ] The opening states the destination and the time required
- [ ] Every step shows the expected output
- [ ] No branches, options, or 「お好みで」
- [ ] Explanation stays within one line; depth is linked
- [ ] Prerequisites are explicit and have a check command
- [ ] Verified to succeed end-to-end by actually running it
- [ ] Consistent polite style (not noun-ending phrasing)

## Common failures

| Failure | Why it's bad |
|---|---|
| Explaining every option of each command | Breaks the learning flow. Put it in reference and link |
| 「環境に応じて適宜読み替えてください」 | The reader cannot judge. Fix it to one value |
| 「なお、〜という設計になっている」 mid-way | Explanation contamination. Link to architecture |
| Omitting sample output | The reader can't tell whether it worked, so confidence never builds |
| A procedure that can fail (unpinned versions / unchecked prerequisites) | One failure and the reader stops trusting the whole tutorial |
