# reference (information-oriented)

読者は**仕事中**に事実を引きに来る。読むものではなく引くもの。中立記述に徹する。

## 原則

| 原則 | 具体 |
|---|---|
| 記述だけ、指示も意見もなし | 「〜してください」「推奨」「〜すべき」を書かない。警告 (「〜を指定しない場合は失敗する」) は事実なので可 |
| 機構の構造をそのまま写す | doc の並びを対象の構造に一致させる。package / table / command の階層をそのまま |
| pattern を固定する | 同種の項目は同じ順・同じ見出し・同じ表で書く。1 つだけ形式が違う項目を作らない |
| 例は載せる、解説はしない | 使用例は文脈を最短で伝える。例を膨らませて説明にしない |
| 生成できるものは生成する | 手書きは腐る。生成物がある場合は生成物を SoT にして link |

## API 仕様は書かない (link 規約)

**API 仕様の SoT は schema (proto / OpenAPI)**。Markdown に複製しない — 複製は必ず乖離し、どちらが正か分からなくなる。

`docs/reference/` に置くのは次のみ:

- 生成物 (proto / OpenAPI / 生成 doc) への link
- schema に書けない利用上の制約 (rate limit / 認証の取得手順への link / 冪等性の扱い / 廃止予定)

```markdown
## API

契約の SoT は [`apis/proto/<path>`](../../apis/proto/<path>)。生成 doc は <link>。

| 制約 | 値 |
|---|---|
| rate limit | <値> |
| 認証 | <方式>。取得手順は [<how-to>](../how-to/<goal>.md) |
| 冪等性 | <キー> による重複排除 (<保持期間>) |
```

## template: DB schema

````markdown
---
title: <DB 名> スキーマ
description: <DB 名> のテーブル・カラム・制約の一覧
---

# <DB 名> スキーマ

SoT は <migration ファイル / DDL> ([link])。本 doc は参照用の写し。

## <テーブル名>

<1 文で何を保持するか>

| カラム | 型 | NULL | 既定値 | 説明 |
|---|---|---|---|---|
| `id` | `uuid` | NO | `gen_random_uuid()` | 主キー |

- 主キー: `id`
- 一意制約: `(<col>, <col>)`
- 索引: `<index name>` (`<col>`)
- 外部キー: `<col>` → `<table>.<col>` (`ON DELETE <action>`)
````

## template: 設定 / 環境変数

````markdown
---
title: 環境変数一覧
description: <対象> が参照する環境変数と既定値
---

# 環境変数一覧

| 変数 | 型 | 必須 | 既定値 | 説明 |
|---|---|---|---|---|
| `<NAME>` | `string` | yes | — | <何を決めるか> |
| `<NAME>` | `duration` | no | `30s` | <何を決めるか>。`0` で無効 |

未設定の必須変数がある場合、起動時に <挙動>。
````

## template: CLI / catalog template

````markdown
---
title: <CLI 名> コマンド一覧
description: <CLI 名> のサブコマンドと option
---

# <CLI 名>

```
<cli> <command> [options] <args>
```

## <command>

<1 文で何をするか>

| option | 型 | 既定値 | 説明 |
|---|---|---|---|
| `--<name>` | `string` | — | <何を決めるか> |

例:

```bash
<cli> <command> --<name> <value>
```
````

self-service の scaffolder template / catalog の必須 field も同じ形式で列挙する (template 名 / 用途 / 必須 parameter / 生成物)。

## checklist

- [ ] 手順・推奨・意見が入っていない
- [ ] 並びが対象の構造 (package / table / command) と一致している
- [ ] 同種項目の書式が完全に揃っている
- [ ] 型 / 既定値 / 必須の別が全項目にある
- [ ] API 仕様本文を複製していない (schema へ link)
- [ ] 生成できる情報を手書きしていない、または SoT を明記している
- [ ] 体言止めで統一

## よくある失敗

| 失敗 | なぜ悪いか |
|---|---|
| 「まず〜を設定します」 | 手順の混入。how-to に移す |
| 例に「なぜこう書くか」を足す | explanation の混入。architecture に link |
| proto と Markdown 両方に API 仕様がある | 乖離して両方信用されなくなる |
| 項目ごとに表の列が違う | 引けなくなる。pattern の一貫性が reference の価値 |
| 「詳細は実装を参照」 | reference が仕事をしていない。書くか、生成物へ link |
