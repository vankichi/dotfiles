---
name: commit-push-branch
description: 新しい branch を切り、過去の commit スタイルに倣ったメッセージで working tree の変更を commit して push する手順。「branch 切って commit & push して」「PR 用に push」の時に使用する。secret 混入を防ぐ明示 add、同一 file 内の対象外変更の分離、GPG hang の回避を含む。PR 作成は含まない (別途 user 指示)。
---

# branch を切って commit & push

## 適用条件

git repo 内 / working tree に commit すべき変更がある / remote `origin` あり。

## 1. 過去スタイルを抽出する

```bash
git status && git diff --stat
git log -3 --format='%H%n%B%n---'
```

過去 commit から **type prefix の慣用 / タイトルの言語 / ticket ID の置き方 / body の有無 / `Co-Authored-By` の慣例** を読み取る。**以降の判断はこの抽出結果が優先する** (下の表は抽出できなかった時の既定値)。

| 変更内容 | type |
|---|---|
| 新機能 | `feat` |
| バグ修正 | `fix` |
| インフラ / 設定 / build | `chore` |
| ドキュメントのみ | `docs` |
| リファクタ (機能変化なし) | `refactor` |
| テスト追加 | `test` |

branch 名は `<type>/<slug>` (ticket があれば `<type>/<ticket-id>-<slug>`)。slug は kebab-case 3-5 語。**ticket ID だけで識別せず必ず内容 slug を付ける**。`git checkout -b <name>`、衝突したら `-2` 等。

## 2. 明示的に add する

**`-A` / `-a` を使わない**。対象を列挙して `git add` し、`git status` で `.env` / `*.pem` / `credentials*` が混ざっていないことを確認する。

**同一 file 内に対象外の既存変更が同居する場合** — file 単位では分離できず `git add -p` は interactive で使えない。**working tree を触らず** (checkout / stash 禁止) index だけに自分の変更を載せる:

```bash
tmp=$(mktemp)
git show HEAD:<path> > "$tmp"        # HEAD 版を起点に
# "$tmp" へ自分の変更だけを適用 (Edit / sed / patch)
git update-index --cacheinfo 100644,$(git hash-object -w "$tmp"),<path>
```

stage 後に `git diff --cached -- <path>` (commit に載るのは自分の変更のみ) と `git diff -- <path>` (working tree に既存変更が残存) の**双方**を出して分離を確認する。

## 3. commit する

**default は title 1 行のみ。title に書くのは変更内容だけ** — why / 背景 / 影響範囲 / ticket 文脈は書かない (PR description と ticket で追える)。

```bash
git commit -m "<type>(<scope>): <変更内容>"
```

- 良い例: `docs(api): SearchMeta を RequestMeta にリネームし common.proto へ切り出す`
- 悪い例: `chore: 前 commit で導入した slog.Info の "phase" 引数を削除して rot を回避` ← why が入っている

body を書く例外は 3 つだけ: breaking change (`BREAKING CHANGE: <impact>` 行を含める) / PR に残せない非自明な why (稀) / 過去スタイルが body 必須。HEREDOC は `<<'EOF'` で展開を抑止する。

**GPG hang**: `commit.gpgsign=true` の環境では pinentry 待ちで hang しうる。`git commit` は Bash tool の timeout を 30 秒にして実行し、hang したら `git status` で staged が維持されていることを確認して (慌てて reset しない) user に手動 commit を案内する。**`--no-gpg-sign` / `commit.gpgsign=false` で勝手に回避しない**。

## 4. push して報告する

```bash
git push -u origin <branch-name>
```

報告に **Branch / Commit (short-sha + title) / Files (n files, +追加/-削除) / PR 作成 URL** (push 出力から抽出) を出す。**PR 作成は行わない** — user の別途指示を待つ。

## 鉄則

1. **新 commit を作る** — `--amend` を使わない
2. **`--no-verify` 禁止** — pre-commit hook が落ちたら原因を直す
3. **main / master に直 push しない**
4. **`git add -A` / `-a` を使わない**
5. **過去スタイルに揃える** — type / 言語 / ticket 表記 / `Co-Authored-By` を独断で付けない・外さない
6. **PR は user 指示後**

## 親が squash merge された stacked branch

この状況になった時のみ [references/stacked-pr-rebase.md](references/stacked-pr-rebase.md) を読む。通常の push では読まない。
