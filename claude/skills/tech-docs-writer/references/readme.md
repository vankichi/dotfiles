# README / Guide Template (Diataxis compliant)

> **Source of truth:** `claude/ja/skills/tech-docs-writer/references/readme.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

Diataxis classifies documents into four quadrants: Tutorial / How-to / Reference / Explanation.
A README should not cram all four types into one file. The repository root `README.md` should function purely as an "entry point," with the details separated out under `docs/readme/`.

## Type determination

| What you want to write | Quadrant | Intended reader |
|---------------|------|---------|
| Getting a first-time user to something working | Tutorial | New onboarding |
| How to solve a specific problem | How-to | Developers who already know the project |
| List of configuration items / commands | Reference | Developers who look things up like a dictionary while implementing |
| Explanation of background / architecture | Explanation | People who want to understand the architecture |

Do not mix two or more types within a single document. A structure where 「チュートリアルの途中で突然Reference表が挟まる」 (a Reference table suddenly appears midway through a tutorial) is hard to read.

## Required interview items

- Target audience (new onboarding / existing developers / operations staff)
- Which quadrant to write
- Project name and repository URL
- Assumed environment (language version / OS / dependent services)
- For Tutorial/How-to: the final state to achieve (a working app / output files)
- For Reference: what to enumerate (CLI commands / configuration keys / environment variables)

## Root README.md template (entry point)

```markdown
# <プロジェクト名>

<1〜2文でプロジェクトの目的>

[![CI](<badge-url>)](<link>) [![License](<badge>)](<link>)

## これは何

<もう少し詳しい説明。3〜5文。何を解決するか、何を解決しないか。>

## クイックスタート

```bash
git clone <repo>
cd <repo>
make setup
make run
```

詳細は [セットアップガイド](docs/readme/getting-started.md) を参照。

## ドキュメント

- [セットアップガイド (Tutorial)](docs/readme/getting-started.md)
- [よくあるタスク (How-to)](docs/readme/how-to.md)
- [設定リファレンス (Reference)](docs/readme/configuration.md)
- [アーキテクチャ解説 (Explanation)](docs/readme/architecture.md)
- [API仕様](docs/api/)
- [運用Runbook](docs/runbook/)

## 開発者向け

- コントリビュートガイド: [CONTRIBUTING.md](CONTRIBUTING.md)
- 変更履歴: [CHANGELOG.md](CHANGELOG.md)

## ライセンス

<license-name>
```

## Tutorial template (learning for beginners)

```markdown
# <プロジェクト名> セットアップガイド

このチュートリアルを最後まで進めると、ローカルで <X> が動く状態になります。
所要時間の目安: <N>分。

## 前提

- <OS/言語バージョン/必要ツール>

## ステップ1: <動詞で始める見出し>

<コマンド>

```bash
$ command
```

**確認**: <期待される出力や状態を明示>

## ステップ2: ...

...

## 完成

<何が達成できたか、次に何を読めばよいか>

## うまくいかない場合

<よくあるつまずきポイント2〜3つ>
```

## How-to template (steps for a specific task)

```markdown
# <動詞ではじまるタイトル: 例「新しいAPIエンドポイントを追加する」>

## 前提

- <既に満たされていること>

## 手順

1. <ステップ>
2. <ステップ>
3. <ステップ>

## 検証

<変更が正しく入ったかの確認方法>

## 関連

- <関連するHow-to、参照ドキュメント>
```

## Reference template (enumeration of facts)

```markdown
# <対象の名前> リファレンス

## 設定項目

| キー | 型 | 既定値 | 説明 |
|------|-----|-------|------|
| `FOO` | string | `""` | <役割> |

## コマンド

### `<command> <subcommand>`

<1行要約>

**使い方**:
```bash
<command> <subcommand> [flags]
```

**フラグ**:

| フラグ | 型 | 既定 | 説明 |
|--------|-----|-----|------|
| `--bar` | int | 10 | <説明> |
```

## Explanation template (explanation for understanding)

```markdown
# <概念/アーキテクチャのタイトル>

## 背景

<なぜこの設計/概念が存在するか>

## 全体像

<Mermaid C4図 or アーキテクチャ図>

## 主要コンポーネント

### <コンポーネントA>

<責務と他コンポーネントとの関係>

## 設計上の選択

<採用したパターン・採用しなかったパターンと理由>
<関連ADRへのリンクを張る>

## 参考

- <論文、書籍、ブログ>
```

## Writing tips

1. A Tutorial is about "doing," not "reading to memorize." Place a confirmation point at each step.
2. Start How-to titles with a verb: use 「データベースに接続する」 rather than 「データベースに接続するには」.
3. Reference should prioritize completeness. Adding too much explanation drifts it toward Explanation and makes it harder to look things up.
4. Always include a diagram in Explanation. Text alone doesn't get the point across.

## Save location

- Repository root `README.md` (entry point)
- Details: `docs/readme/<topic>.md` (split per Tutorial/How-to/Reference/Explanation)

## References

- Diataxis official site: https://diataxis.fr/
