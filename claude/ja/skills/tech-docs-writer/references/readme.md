# README / ガイドテンプレート (Diataxis 準拠)

Diataxis は Tutorial / How-to / Reference / Explanation の4象限で文書を分類する。
READMEはこの4種を1ファイルに詰め込まない。リポジトリ直下 `README.md` は「入口」に徹し、詳細は `docs/readme/` 配下に分離する。

## 種別判定

| 何を書きたいか | 象限 | 想定読者 |
|---------------|------|---------|
| 初めて触る人が動くところまで | Tutorial | 新規オンボーディング |
| 特定の課題の解き方 | How-to | 既にプロジェクトを知っている開発者 |
| 設定項目・コマンド一覧 | Reference | 実装中に辞書的に引く開発者 |
| 背景・アーキテクチャの説明 | Explanation | アーキテクチャを理解したい人 |

1つのドキュメントに2種以上を混在させない。「チュートリアルの途中で突然Reference表が挟まる」構成は読みにくい。

## 必須ヒアリング項目

- 対象読者 (新規オンボーディング / 既存開発者 / 運用担当)
- どの象限を書くか
- プロジェクト名・リポジトリURL
- 前提環境 (言語バージョン / OS / 依存サービス)
- Tutorial/How-to の場合: 達成したい最終状態 (動くアプリ / 出力されるファイル)
- Reference の場合: 列挙する対象 (CLIコマンド / 設定キー / 環境変数)

## Root README.md のテンプレート (入口用)

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

## Tutorial テンプレート (初心者向けの学習)

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

## How-to テンプレート (特定タスクの手順)

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

## Reference テンプレート (事実の列挙)

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

## Explanation テンプレート (理解のための解説)

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

## 書き方のコツ

1. Tutorial は"読んで覚える"ではなく"手を動かす"。段階ごとに確認ポイントを置く。
2. How-to は動詞ではじめるタイトル。「データベースに接続するには」ではなく「データベースに接続する」。
3. Reference は網羅性優先。説明を足しすぎると Explanation に寄って引きにくくなる。
4. Explanation は図を必ず入れる。テキストだけだと伝わらない。

## 保存先

- リポジトリ直下 `README.md` (入口)
- 詳細: `docs/readme/<topic>.md` (Tutorial/How-to/Reference/Explanation ごとに分割)

## 参考

- Diataxis 公式: https://diataxis.fr/
