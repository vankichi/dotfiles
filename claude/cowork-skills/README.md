# claude/cowork-skills — cowork 用 skill (claude.ai account 配布)

設計工程を担う cowork 用 skill の authoring SoT。日本語原文は `claude/ja/cowork-skills/` (更新は ja → 英訳の順、`claude/ja/README.md` の規約に従う)。

## `claude/skills/` と分けている理由

- `claude/skills/` は `~/.claude/skills` に symlink される (Makefile) ため、置いたものは **Claude Code に載る**
- cowork session は `~/.claude/skills/` も repo の `.claude/skills/` も読まない。**claude.ai account で有効化された skill を session 開始時に sync する**
- 本 directory の skill は設計工程 (cowork) 専用で、Claude Code 側の着手ゲート (`/spec-check`) と責務が重ならないよう local には load させない

## 配布手順

1. ja 原文を更新 → 英訳を本 directory に反映
2. skill directory を **ZIP の root に置いて** 固める (file を直に ZIP root へ置くのは誤り)
   ```sh
   cd claude/cowork-skills && zip -r ../../harden-spec.zip harden-spec
   ```
3. Mac の Claude desktop app の Customize sidebar (または claude.ai の skill 設定) から upload して有効化
4. cowork session を開き直す (skill は session 開始時に sync される)

自動 sync 経路は無いので、本 repo と claude.ai 側の drift は手運用で受ける。

## 制約

- frontmatter の上限: `name` 64 文字 / `description` 200 文字。**発火条件を description に詰め込まない** (本文冒頭の「発火条件」節に置く)
- account 単位で全 cowork session に載るため、project 固有語 (repo 名 / service 名 / ticket prefix / 環境 URL) を hardcode しない
- 観点の SoT は対象 repo 側の `.claude/rules/` に置き、skill 本文からは path で参照する。repo 側に無い場合の fallback は各 skill の `references/` に汎用版を持つ
- cowork は working tree しか読めない。`git` / `gh` に依存する手順を書かない

## skill 一覧

| skill | 責務 |
|---|---|
| `harden-spec` | 設計 draft / ticket を repo と突き合わせ、実装可能な spec にする (設計判断はしない) |
| `plan-implementation` | 確定 spec を層配置 → PR 分割 → 着手手順に落とす (実装はしない) |
