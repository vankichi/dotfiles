---
name: commit-push-branch
description: 作業ツリーの変更を過去の commit スタイル (type prefix / ticket ID / Co-Authored-By) に倣ったメッセージで、新 branch を切って commit & push する。「branch 切って commit & push して」「PR 用に push」等で使う。
---

# commit-push-branch

新しい branch を切って、過去スタイルに倣った commit を作り、push まで行う skill。PR 作成は別 (`gh pr create`)。

## 適用条件

- git リポジトリ内
- 作業ツリーに commit すべき変更がある (`git status` で何か出る)
- リモート `origin` が設定済み

## 手順

### Step 1: 状態確認

```bash
git status
git diff --stat
git diff --cached
git log -3 --format='%H%n%B%n---'   # 過去スタイル把握
```

### Step 2: 過去スタイル抽出

`git log -3` の出力から:
- **type prefix の慣用** (`chore:`, `feat:`, `fix:`, `docs:`, `refactor:`, `test:`)
- **タイトルの言語** (英語 / 日本語)
- **ticket ID の置き方** (`(PROJ-123)` / `Refs: PROJ-123` / `(#123)` 等、リポジトリ慣例次第)
- **HEREDOC で多行記述** されているか
- **Co-Authored-By 行** が付いているか
- **PR merge style** (squash か merge commit か)

### Step 3: type と branch 名の決定

| 変更内容 | type | branch prefix |
|---|---|---|
| 新機能 | `feat` | `feat/` |
| バグ修正 | `fix` | `fix/` |
| インフラ / 設定 / build / ツール | `chore` | `chore/` |
| ドキュメントのみ | `docs` | `docs/` |
| リファクタ (機能変化なし) | `refactor` | `refactor/` |
| テスト追加 | `test` | `test/` |

branch 名のパターン:

| ケース | 形式 | 例 |
|---|---|---|
| ticket あり | `<prefix>/<ticket-id>-<description-slug>` | `chore/proj-123-add-feature` |
| ticket 無し | `<prefix>/<description-slug>` | `docs/api-error-codes-cleanup` |

description slug は kebab-case で短く (3-5 語)。ticket ID だけで branch を識別せず、必ず内容を表す slug を付ける。

過去 PR が ticket ID を含む慣習なら ticket ID を付与、ticket 無しの慣習 (主に `docs/` / `chore/` 系で見られる) なら slug only。**判定は Step 2「過去スタイル抽出」の結果に従う** (本 table はあくまでパターン例で、Step 2 を override しない)。

### Step 4: branch 作成

```bash
git checkout -b <prefix>/<ticket-id>-<slug>
```

既存 branch にぶつかったら `-N` などで suffix。

### Step 5: 明示的 add

`-A` / `-a` を**使わない**。新規ファイル / 編集ファイルを明示的に列挙:

```bash
git add <file1> <file2> <dir1>/ <dir2>/
git status   # 確認
```

`.env` / `*.pem` / `credentials*` 等の secret パターンが含まれないこと確認。

### Step 6: commit

**default は title 1 行のみ**。`-m "<title>"` で十分。HEREDOC + body は default にしない。

```bash
git commit -m "<type>: <変更内容>"
# または scope 付き
git commit -m "<type>(<scope>): <変更内容>"
```

title に書くもの = **変更内容のみ**。why / 背景 / 影響範囲 / rot リスク / ticket 文脈は title にも body にも書かない (PR description / Notion ticket / git 履歴で追える)。

良い例:
- `chore: ブートログから phase フィールドを削除`
- `docs(api): SearchMeta を RequestMeta にリネームし common.proto へ切り出す`
- `chore: translate Makefile comments and error messages to English`

悪い例 (verbose / why 入り):
- `chore: ブートログから phase フィールドを削除\n\nphase 値はログに焼き付けると rot するだけで利得がない。`
- `chore: 前 commit で導入した slog.Info の "phase" 引数を削除して rot を回避`

#### body / HEREDOC を使う例外

下記のときだけ body を書く:
- **breaking change** → `BREAKING CHANGE: <impact>` 行を含める
- **本当に非自明な why** があり、PR description には残せない事情がある (稀)
- **過去スタイルが HEREDOC + body 必須** で揃っている (Step 2 の調査結果による)

例外時のテンプレ:

```bash
git commit -m "$(cat <<'EOF'
<type>: <変更内容>

<最小限の why。1-2 行。>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

注意:
- HEREDOC は `'EOF'` (シングルクォート) で展開抑止
- `Co-Authored-By:` は **過去 commit に倣ってあれば付ける、無ければ付けない**。短文 commit でも `-m "..." -m "Co-Authored-By: ..."` のように 2 行指定すれば付与可能 (リポジトリ慣例次第)
- ticket ID `(PROJ-123)` 等の付与も過去スタイル次第。title が長くなるなら省略しても可

#### GPG signing hang への対処

`commit.gpgsign=true` 設定の環境では `git commit` が pinentry 待ちで hang することがある (agent 環境は TTY が無く pinentry GUI が起動できない、または gpg-agent cache 切れで passphrase 待ち)。

対処手順:

1. **`git commit` 実行は Bash tool の timeout を 30 秒に設定** (default の 2 分待たない)
2. **hang / timeout 検出時**: `git status` で staged 状態が維持されていることを確認 (commit は失敗、ファイルは staged のまま)
3. **`ps aux | grep -E "gpg|git commit" | grep -v grep`** で hung プロセスがあるか確認、必要なら user に kill を依頼
4. **user に手動 commit を案内**:
   - 別ターミナルで `echo test | gpg --clearsign > /dev/null` を実行 → pinentry でパスフレーズ入力 → cache が温まる
   - もしくは下記コマンドを user 側で直接実行:
     ```bash
     git commit -m "<type>: <変更内容>" -m "Co-Authored-By: <name> <email>"
     ```
5. **手動 commit 完了後、user から「commit done」等の合図を受けたら skill 側で push に進む** (`git log --oneline -1` で確認後)
6. cache が温まれば以降の commit / push は agent 側でも通る (続く Step 7 push も skill 側で実行可)

注意:
- skill 側で勝手に `--no-gpg-sign` や `commit.gpgsign=false` で workaround しない (鉄則 #2「`--no-verify` 禁止」と同精神 — 安全スキップは user 明示要請があるときだけ)
- staged 状態は hang しても破壊されないので慌てて reset しない

### Step 7: push

```bash
git push -u origin <branch-name>
```

main / master への直 push は警告 (作業 branch であることを Step 4 で保証している前提)。

### Step 8: 完了報告

| 項目 | 値 |
|---|---|
| Branch | `<prefix>/<ticket-id>-<slug>` |
| Commit | `<short-sha>` (`<type>: ...`) |
| Files | `<n>` files (+<additions>/-<deletions>) |
| PR 作成 URL | (push 出力から抽出: `https://github.com/<org>/<repo>/pull/new/<branch>`) |

PR 作成は別タスク。ユーザーが指示したら `gh pr create` で続ける。

## loop-mode (dev-cycle からの起動時のみ)

呼び出し時に **loop-mode が明示された場合のみ**適用する (根拠: CLAUDE.md「loop-mode (自律実行の例外規定)」):

- Step 3-6 の branch 名 / commit message は規約と過去スタイルで自動決定し、user 確認を挟まない
- **WIP squash の適用判定 (機械実行)**: 作業 branch に `wip(<工程>):` commit が積まれている場合 (dev-cycle の工程境界 WIP commit)、squash の前に必ず `git ls-remote --heads origin <branch>` を実行する。**出力が空 (= 未 push) の場合のみ**、`git reset --soft $(git merge-base HEAD origin/<default-branch>)` で全変更を staged に戻してから規約通りの 1 commit を作る (`--hard` は使わない)。この場合 Step 5 の明示 add は「`git status` で staged 内容に secret / 対象外ファイルが混ざっていないことを確認する」に読み替える
- **escalation で push 済みの branch では squash しない**: push 済み履歴の書き換えは force push が必要になり禁止と衝突する。wip の上に最終 commit を積み増してそのまま push する (fast-forward)。PR の commit 欄に wip が残るが、merge は squash merge 慣例のため default branch は汚れない
- Step 7 の push 後に **draft PR を作成する**: `gh pr create --draft` (title = commit title、body = 下記「PR body 構築規則」で組み立てる)
- 本 PR 化 (draft 解除) と merge はしない
- loop-mode 指定がない対話時の挙動は従来通り不変 (PR 作成は user 指示後)

### PR body 構築規則 (loop-mode)

呼び出し元 (dev-cycle) から渡される材料 = 実装計画 / DoD チェック結果 / spec deviation (SD#) / impact scope / self-review・security review 結果 (観点実施状況を含む) / ticket URL。これを次の規則で body に落とす:

1. **対象 repo の PR template を探索**: `.github/pull_request_template.md` → `.github/PULL_REQUEST_TEMPLATE.md` → `PULL_REQUEST_TEMPLATE.md` → `docs/pull_request_template.md` の順で最初に見つかったもの
2. **template があればその section 構成に従う**: HTML comment の記入 hint (`<!-- ... -->`) は削除し、各 section へ材料を対応付けて記入する。section 名は repo により異なるため意味で対応させる (目安):

| template section (例) | 記入する材料 |
|---|---|
| Summary / Changes | 実装計画の要約 / 変更内容 |
| Spec compliance | DoD 各項目 ↔ 実装・テストの対応 (チェック結果) |
| Spec deviations | SD# (無ければ "none") |
| Impact scope | 変更 symbol → 参照元の mapping と impact 分類 |
| Review guide | diff の読み順 (entry point → 本体 → test。impact scope の mapping から導出) / 重点確認箇所 (review 指摘を受けて修正した箇所・自信の低い箇所) / reviewer が手元で DoD を確認する手順 (DoD 検証手順から転記) |
| Verification | test / lint 実行結果 + self-review・security review の結果 (観点実施状況を含む) |
| References | ticket URL / 関連 doc |
| Checklist | 機械的に判定できる項目のみ check (reviewer assign 等の人間項目は空欄のまま) |

   材料に対応する section が template に無い場合は body 末尾に section を追加して漏らさず記載する (黙って捨てない)
3. **template が無ければ default skeleton で生成**: `## Summary` / `## Spec compliance` / `## Spec deviations` / `## Impact scope` / `## Verification` / `## References` の 6 section
4. **repo の可視性で ticket 記載を分岐** (`gh repo view --json visibility` で機械判定): private repo は References に ticket URL を記載する (review-loop が「PR body + 参照 ticket」を spec として辿る前提)。**public repo では内部 URL / ticket 本文を書かない** (improve-harness 鉄則と同精神 — insights / ticket は名前・ID のみで参照)

## 鉄則

1. **新 commit を作る**: `--amend` を使わない (前の commit を破壊する可能性)
2. **`--no-verify` 禁止**: pre-commit hook を尊重。失敗したら原因を直す
3. **branch を main に直 push しない**: 必ず作業 branch
4. **`git add -A` / `-a` を使わない**: 明示列挙で secret 混入を防ぐ
5. **過去スタイル尊重**: 前 3 commit の type / 言語 / ticket 表記 / Co-Authored-By 慣例に揃える
6. **PR は user 指示後**: skill は push まで。`gh pr create` はユーザーから指示があれば (例外: loop-mode 時の draft PR 作成のみ — 上記「loop-mode」section 参照)
7. **default は title 1 行・変更内容のみ**: why / 背景 / 影響範囲は書かない。body は breaking change / 本当に非自明な why のときだけ

## アンチパターン

- `git commit -am` (untracked が漏れる + 全 staged を盲目 commit)
- `git push --force` を作業 branch でも安易に使う
- HEREDOC を `EOF` (クォート無し) で書いて変数展開される
- 過去スタイルを確認せずに英語タイトルで commit (リポジトリは日本語タイトル慣例だった等)
- `Co-Authored-By` を独断で付ける / 付けない (リポジトリ慣例に合わせる)
- title に why や rot リスクや「〜のため」を書く (変更内容のみ書く)
- 単純な commit でも HEREDOC + 数行 body を default で書く (1 行で済むなら 1 行)
