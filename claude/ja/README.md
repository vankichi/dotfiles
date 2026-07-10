# claude/ja — 日本語原文 (source of truth)

`claude/skills/` / `claude/agents/` の **日本語原文** を同じ階層構造で保持する。
実際に model が読む live ファイル (`claude/skills/`, `claude/agents/`) は英語版。

## 更新手順 (必ずこの順番)

1. **この `claude/ja/` 配下の日本語本文を修正する**
2. 修正内容を対応する live ファイル (`claude/skills/…`, `claude/agents/…`) に **英訳して反映する**

live 側だけを直接編集しない (ja と live が乖離する)。
新規 skill / agent を作る場合も、ja に日本語原文を置いてから英訳版を live に置く。

## 英訳時の規約

- frontmatter の `name:` / `tools:` / `model:` は変更しない
- `description:` は英訳するが、「…」で括られた日本語の発火フレーズ例は日本語のまま残す (user は日本語で話しかけるため)
- code block / コマンド / path / URL / 見出し構造は変更しない
- 要約・再構成・改善はしない (忠実な翻訳のみ)
