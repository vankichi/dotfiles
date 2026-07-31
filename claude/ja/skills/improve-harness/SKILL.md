---
name: improve-harness
description: 全 project の未処理 insights を集約し、現状照合 → 反映先判定 (memory → rules → skill → agent) → 改善実装 → dotfiles への改善 draft PR まで行う knowledge loop の反映側 skill。「improve-harness して」「harness 改善して」「insights 集約して」等で使う。設計判断はしない (undecided は要判断一覧で人間へ)。収集側は retrospect (対の skill)。
---

# improve-harness

knowledge loop の反映側。retrospect が蓄積した insights を集約し、harness (skills / agents / rules / CLAUDE.md) への改善を draft PR として出す。
**設計判断はしない** — 複数案併記・undecided な proposal は実装せず人間に返す。

## 適用条件

- 手動起動 (定期実行は未導入)
- 対象 harness repo = dotfiles。cwd が dotfiles でない場合は dotfiles を対象に作業する

## 手順

### Step 0: 稼働 harness の drift 検査

稼働 harness (`~/.claude/{skills,agents,rules}`) は dotfiles working tree への symlink であり、**checkout している branch が harness の実体**。`git -C <dotfiles> fetch origin` 後に以下を実行し、乖離があれば**改善提案の前に人間へ報告する** (乖離したまま insight を処理すると、master で解決済みの問題を再発見・再適用する):

```bash
git rev-list --left-right --count origin/master...HEAD
git diff --stat origin/master HEAD -- claude/
```

### Step 1: 収集

- `~/.claude/projects/*/insights/*.md` を全 project 横断で列挙する
- frontmatter に `status:` がある file は処理済みとして除外する (未処理 = `status` なし)
- 未処理 0 件なら「該当なし」と明示して正常終了する

### Step 2: routing (機械的判定)

frontmatter の `target` で振り分ける:

| target | 扱い |
|---|---|
| harness 内 (`claude/` 配下 / `CLAUDE.md` / `rules/`) | 改善対象 → Step 3 へ |
| harness 外 (他 repo のファイル / Claude Code 本体の挙動 / design doc・plans) | PR に含めない。memory 化で足りるもの (事実 / 環境の癖 / 代替 recipe) は Step 3 の照合 (対象 project の memory の現状確認、既登録なら `status: applied` で除外) を経て Step 4 の memory 反映へ回す。それ以外は「対象外報告」に回し、対象 project 側での対応提案を 1 行付けて `status: deferred` (reason: out-of-scope) |

### Step 3: 現状照合

- 各 insight の target file の**現状**を Read し、proposal が既に反映済みか判定する (手動先行適用があり得る)
- 反映済み → frontmatter に `status: applied` を追記して除外する
- この照合を skip して差分を作らない (重複適用・既存記述との逆行の防止)

### Step 4: クラスタリング + 反映先判定

- 関連する insight をまとめて 1 改善単位 (cluster) にする
- 反映先は `references/promotion.md` の基準で判定する。**memory → rules → skill → agent の昇格順**で、変更コストの小さい側に倒す
- `target` が明記された insight はそれに従う (昇格判定は target 不明・横断パターンの時のみ)
- **memory 反映は PR 不要**: 対象 project の memory に直接 write し、報告のみ。memory 反映で完結した insight は `status: applied` (反映先 memory を併記)

### Step 5: 改善実装

- **作業は worktree で行う** (`git worktree add -b <branch> <path> <base>`)。main checkout の branch を切り替えない — 稼働 harness (`~/.claude/*` → main checkout working tree の symlink) が別 session で使用中のため、checkout 切替は稼働中の全 session の挙動を変える。merge 後は main checkout で `git pull` して master に追従する
- ja SoT (`claude/ja/...`) を編集 → en mirror (`claude/...`) は opus subagent へ翻訳委譲する (docs = opus 規約)。mirror を持たないファイル (`rules/` / `CLAUDE.md`) は単一編集
- proposal が undecided / user 判断を要する (複数案併記・status 体系への介入・外部 account・権限拡大 等) → 実装せず `status: deferred` (reason 付き) で「要判断一覧」へ

### Step 6: ship (draft PR)

- `commit-push-branch` skill を **loop-mode 明示**で呼ぶ: branch 作成 + cluster ごとの commit + push + draft PR 作成
- PR body: insight (file 名) ↔ 変更の対応表 + 要判断一覧
- 根拠: CLAUDE.md「loop-mode」の例外規定 (improve-harness の harness 改善 draft PR)

### Step 7: 状態更新 + 報告

- PR に含めた insight: frontmatter に `status: proposed` + `pr: <URL>` を追記する。**status の追記は cluster の commit 直後に行い、PR 作成を待たない** (`pr:` のみ PR 作成後に追記) — 中断時に「どこまで適用したか」を commit と独立に辿れるようにする
- **全 insight の処遇表を強制出力する** (黙った skip 禁止):

```
## improve-harness 結果

| insight | 処遇 | 反映先 / 理由 |
|---|---|---|
| 20260714-work-intake-skip-idempotency.md | proposed | work-intake references (PR #NN) |
| 20260713-ready-flag-dual-representation.md | applied | 反映済み確認 (rules/spec-contract.md) |
| 20260714-atlas-migrate-lint-pro-gated.md | deferred | 対象外 (他 repo)。対象 project 側での ticket 化を提案 |

## 要判断 (人間へ)
- <undecided な proposal の要約 + 判断してほしい点>
```

## 中断からの resume

run が異常終了 (API stall 等) した場合、ゼロからやり直さず未完了 step を特定して継続する。進捗の判定基準は次の 2 つだけを使う:

1. **`git log origin/<default-branch>..HEAD` の commit 一覧** = 適用済 cluster。**local の `<default-branch>` を基準にしない** — stale だと merge 済 commit を拾って成果が過大に見える (必ず `git fetch` 後に `origin/` 基準で数える)
2. **insight frontmatter の `status`** = 処理済マークの有無。1 件も付いていなければ Step 7 の状態更新が未実行

再開手順: 作業 branch (と worktree) が残っていれば再利用し、上記 2 点の差分から未適用の insight を特定 → Step 5 以降を続行する。push 済 commit は squash / 書き換えせず積み増す (force push 禁止)。draft PR が既に存在する場合は新規作成せず body を編集して追補する。

## status lifecycle (insight frontmatter)

| status | 意味 |
|---|---|
| (なし) | 未処理 |
| `applied` | 既反映を照合で確認、または memory 反映で完結 (PR 不要。memory の場合は反映先を併記) |
| `proposed` | 改善 draft PR に含めた (`pr:` 併記) |
| `deferred` | 要判断・対象外・別 work 割当 (`reason:` 併記) |

## 補助入力 (optional)

session JSONL の集計 (観点 skip 傾向・token 消費等) は user が明示要求した時のみ実施する (`claude-session-jsonl` skill の recipe を使う)。default 入力は insights のみ。

## 障害時

- dotfiles に無関係な未 commit 変更がある場合: 触らず、改善 commit に含めない (明示 add — commit-push-branch の規約)
- push / draft PR 作成が deny された場合: local commit まで保全し、branch 名を報告して停止する
- memory write が deny された場合: 当該 insight を `status: deferred` (reason: write 拒否) にして要判断一覧へ回す

## 鉄則

1. **全 insight の処遇を表で強制出力** — 黙った skip 禁止
2. **draft PR まで** — merge / 本 PR 化 / master 直 push はしない
3. **設計判断をしない** — 複数案・undecided は deferred で人間へ
4. **PUBLIC repo の PR に内部情報を書かない** — 内部 URL / ticket 本文を転記しない。insight は file 名で参照する
5. **insights 原本の本文を書き換えない** — frontmatter への status 追記のみ (本文は retrospect の成果物)
6. **現状照合を skip しない** — 既反映の insight から差分を作らない
