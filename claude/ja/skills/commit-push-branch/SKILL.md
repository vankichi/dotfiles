---
name: commit-push-branch
description: 作業ツリーの変更を過去の commit スタイル (type prefix / ticket ID / Co-Authored-By) に倣ったメッセージで、新 branch を切って commit & push する。
when_to_use: 「branch 切って commit & push して」「PR 用に push」。dev-cycle の commit & push 工程からも起動される。
---

# commit-push-branch

新 branch を切り、過去スタイルに倣った commit を作って push する skill。PR 作成は別 (`gh pr create`)。

## 適用条件

git repo 内 / 作業ツリーに commit すべき変更がある / remote `origin` が設定済み。

## 手順

### Step 1-2: 状態確認と過去スタイル抽出

`git status` / `git diff --stat` / `git diff --cached` と `git log -3 --format='%H%n%B%n---'` を実行し、過去 commit から **type prefix の慣用 / タイトルの言語 / ticket ID の置き方 / body の有無 / Co-Authored-By の慣例** を読み取る。以降の判断はこの抽出結果が優先する。

### Step 3: type と branch 名

| 変更内容 | type / branch prefix |
|---|---|
| 新機能 | `feat` |
| バグ修正 | `fix` |
| インフラ / 設定 / build / ツール | `chore` |
| ドキュメントのみ | `docs` |
| リファクタ (機能変化なし) | `refactor` |
| テスト追加 | `test` |

branch 名は ticket があれば `<prefix>/<ticket-id>-<slug>`、無ければ `<prefix>/<slug>`。slug は kebab-case で 3-5 語。**ticket ID だけで branch を識別せず必ず内容 slug を付ける**。ticket ID を付けるかは Step 2 の抽出結果に従う (本表はパターン例であり Step 2 を override しない)。

`git checkout -b <name>` で作成。既存とぶつかったら `-2` 等の suffix。

### Step 4: 明示的 add

`-A` / `-a` を**使わない**。対象を明示列挙して `git add` し、`git status` で `.env` / `*.pem` / `credentials*` 等が混ざっていないことを確認する。

**同一 file 内に対象外の既存変更が同居する場合**: file 単位の add では分離できず、`git add -p` は interactive のため使えない。**working tree を触らず** (checkout / stash 禁止) index だけに自分の変更を載せる:

```bash
tmp=$(mktemp)
git show HEAD:<path> > "$tmp"        # HEAD 版を起点に
# "$tmp" へ自分の変更だけを適用 (Edit / sed / patch)
git update-index --cacheinfo 100644,$(git hash-object -w "$tmp"),<path>
```

stage 後に `git diff --cached -- <path>` (commit に載るのは自分の変更のみ) と `git diff -- <path>` (working tree に既存変更が残存) の**双方**を出して分離を確認する。

### Step 5: commit

**default は title 1 行のみ**。title に書くのは**変更内容のみ** — why / 背景 / 影響範囲 / ticket 文脈は title にも body にも書かない (PR description / ticket / git 履歴で追える)。

```bash
git commit -m "<type>(<scope>): <変更内容>"
```

- 良い例: `docs(api): SearchMeta を RequestMeta にリネームし common.proto へ切り出す`
- 悪い例: `chore: 前 commit で導入した slog.Info の "phase" 引数を削除して rot を回避` (why 入り)

**body を書く例外**は 3 つだけ: breaking change (`BREAKING CHANGE: <impact>` 行を含める) / PR description に残せない事情のある非自明な why (稀) / 過去スタイルが body 必須で揃っている場合。HEREDOC を使う場合は `<<'EOF'` (シングルクォート) で展開を抑止する。`Co-Authored-By:` と ticket ID の付与は過去 commit の慣例に倣う (独断で付けない / 外さない)。

**GPG signing hang**: `commit.gpgsign=true` の環境では pinentry 待ちで hang しうる。`git commit` は Bash tool の timeout を 30 秒に設定して実行し、hang したら `git status` で staged が維持されていることを確認 (慌てて reset しない) → user に手動 commit を案内する (別 terminal で `echo test | gpg --clearsign > /dev/null` を実行すれば cache が温まる)。**`--no-gpg-sign` / `commit.gpgsign=false` で勝手に回避しない** (鉄則 2 と同じ精神)。

### Step 6: push と完了報告

`git push -u origin <branch-name>`。完了報告に Branch / Commit (short-sha + title) / Files (n files, +追加/-削除) / PR 作成 URL (push 出力から抽出) を出す。PR 作成は別タスク。

## loop-mode (dev-cycle からの起動時のみ)

呼び出し時に **loop-mode が明示された場合のみ**適用する (根拠: CLAUDE.md「loop-mode」)。

- branch 名 / commit message は規約と過去スタイルで自動決定し user 確認を挟まない
- **base ref は default branch ではなく PR の base branch**: stacked PR では base = 親 branch。squash と `gh pr create` の両方で `origin/<default-branch>` 決め打ちにしない (stack を壊す)
- **WIP squash の適用判定**: 作業 branch に `wip(<工程>):` commit がある場合、squash 前に必ず `git ls-remote --heads origin <branch>` を実行し、**出力が空 (未 push) の場合のみ** `git reset --soft $(git merge-base HEAD <base>)` で staged に戻して 1 commit にする (`--hard` は使わない)。この場合 Step 4 の明示 add は「staged 内容に secret / 対象外が無いことの確認」に読み替える。squash 前に `git log --oneline <base>..HEAD` が自分の WIP commit だけであることを確認する (親 branch の commit が混ざっていれば base の取り違えなので squash せず base を訂正する)
- **push 済み branch では squash しない** (force push が必要になり禁止と衝突する)。wip の上に最終 commit を積んで fast-forward で push する。PR の commit 欄に wip が残るが squash merge 運用なら default branch は汚れない
- push 後に **draft PR を作成する**: `gh pr create --draft`。**base が default branch でなければ `--base <base>` を明示する**
- 本 PR 化 (draft 解除) と merge はしない

### PR body の構築

dev-cycle から渡される材料 = 実装計画 / DoD チェック結果 / spec deviation (SD#) / impact scope / review・security review 結果 / ticket URL。

1. **PR template を探索**: `.github/pull_request_template.md` → `.github/PULL_REQUEST_TEMPLATE.md` → `.github/PULL_REQUEST_TEMPLATE/*.md` → `PULL_REQUEST_TEMPLATE.md` → `docs/pull_request_template.md` の順で最初に見つかったもの
2. **template があればその section 構成が SoT**。HTML comment (`<!-- ... -->`) は**記入指示として読んでから**削除する。section 名は repo により異なるため意味で対応させる:

| template section (例) | 記入する材料 |
|---|---|
| Summary | 実装計画の要約 / 変更内容 |
| Spec compliance | DoD 各項目 ↔ 実装・テストの対応 |
| Spec deviations | SD# (無ければ "none") |
| Impact scope | 変更 symbol → 参照元の mapping と impact 分類 |
| Review guide | diff の読み順 (file → symbol で指定し行番号を使わない — push で rot する) / 重点確認箇所 |
| Compat & rollback | breaking の有無 / migration・env・config 変更と適用順 / rollback 手順 |
| Verification | test / lint 結果 + review・security review の結果 |
| References | ticket URL / 関連 doc |
| Checklist | 機械的に判定できる項目のみ check |

   対応する section が無い材料は body 末尾に section を足して記載する (黙って捨てない)
3. **template が無ければ** `## Summary` / `## Spec compliance` / `## Spec deviations` / `## Impact scope` / `## Verification` / `## References` の 6 section で生成する
4. **repo の可視性で ticket 記載を分岐** (`gh repo view --json visibility` で機械判定): private repo は References に ticket URL を記載する。**public repo では内部 URL / ticket 本文を書かない**
5. **埋められない section も削除しない**: 該当なしなら "none" と明記する

**文体**: 体言止め / bullet 主体 (散文の段落を置かない) / review nit と follow-up は全件列挙せず「件数 + state file path」+「merge 前に知る必要がある 2-3 件」に圧縮する / 目安 45-70 行。

## 鉄則

1. **新 commit を作る**: `--amend` を使わない
2. **`--no-verify` 禁止**: pre-commit hook を尊重し、失敗したら原因を直す
3. **main / master に直 push しない**
4. **`git add -A` / `-a` を使わない**: 明示列挙で secret 混入を防ぐ
5. **過去スタイルに揃える**: type / 言語 / ticket 表記 / Co-Authored-By の慣例
6. **PR は user 指示後** (例外: loop-mode の draft PR 作成のみ)
7. **default は title 1 行・変更内容のみ**

## stacked PR の rebase (親が squash merge された後)

親が squash merge されると親の全 commit は patch-id が一致しなくなり、`git rebase --onto` は親相当の再適用で衝突する。commit 単位の rebase を試さず、目標 tree を確定させて 1 commit に collapse する:

1. `git diff <親 tip> origin/<default>` が**空**であることを確認する (空でなければこの手順は使えない)
2. `git branch backup/<name> <子 tip>` で復旧点を作る
3. `NEW=$(git commit-tree <子 tip>^{tree} -p origin/<default> -F <msg file>)`
4. `git checkout -B <branch> $NEW` (`reset --hard` は使わない)
5. `git diff <子 tip> HEAD` が空 (review 済み head と tree が byte 一致) と `git diff origin/<default> HEAD --stat` が想定差分と一致することを機械的に検証する

push は force が必要なので **user の明示指示を待つ** (`--force-with-lease` + backup ref を提示する)。
