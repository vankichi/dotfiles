# reference (information-oriented)

The reader comes **while at work** to look up a fact. It is consulted, not read. Stick to neutral description.

## Principles

| Principle | Concretely |
|---|---|
| Describe only — no instruction, no opinion | Never write 「〜してください」「推奨」「〜すべき」. Warnings (「〜を指定しない場合は失敗する」) are facts, so they are fine |
| Mirror the structure of the machinery | Make the doc's ordering match the target's structure: package / table / command hierarchy as-is |
| Fix the pattern | Same order, same headings, same tables for items of the same kind. Never let one item have a different shape |
| Include examples, don't explain them | A usage example conveys context in the shortest way. Don't inflate it into an explanation |
| Generate what can be generated | Handwriting rots. When a generated artifact exists, make it the SoT and link to it |

## Do not write API specs (the link convention)

**The SoT of an API spec is the schema (proto / OpenAPI).** Do not duplicate it into Markdown — duplicates always drift, and then nobody knows which one is right.

`docs/reference/` should only carry:

- A link to the artifact (proto / OpenAPI / generated docs)
- Usage constraints that can't live in the schema (rate limits / link to how to obtain credentials / idempotency semantics / deprecation)

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

## template: configuration / environment variables

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

List self-service scaffolder templates and required catalog fields in the same format (template name / purpose / required parameters / what it generates).

## checklist

- [ ] No procedures, recommendations, or opinions
- [ ] The ordering matches the target's structure (package / table / command)
- [ ] The format of same-kind items is perfectly consistent
- [ ] Type / default / required-ness present for every item
- [ ] API spec bodies are not duplicated (linked to the schema)
- [ ] Generatable information isn't handwritten, or the SoT is stated
- [ ] Consistent noun-ending phrasing

## Common failures

| Failure | Why it's bad |
|---|---|
| 「まず〜を設定します」 | Procedure contamination. Move it to how-to |
| Adding "why it's written this way" to an example | Explanation contamination. Link to architecture |
| API spec exists in both proto and Markdown | They drift and neither is trusted |
| Different table columns per item | It stops being lookup-able. Pattern consistency is reference's value |
| 「詳細は実装を参照」 | The reference isn't doing its job. Write it, or link to the artifact |
