---
name: pr-follow-loop
description: /loop で回す「自分が author の open PR を見届ける」driver skill。1 tick = 自分の open PR を poll → 各 PR の段階を 1 歩進める（bot review 指摘の triage 提示 / human approve の watch / merge 後の自動掃除）→ 通知 → ScheduleWakeup で self-pace。dev-loop（PR を作る）/ review-loop（他人の PR をレビューする）の兄弟で、本 skill は自分が作った PR のその後を追う。
when_to_use: /loop 経由で自 author の open PR を見届ける時。「pr-follow-loop の tick を実行して」「PR 見届け loop 回して」。
disallowed-tools: AskUserQuestion
---

> **Source of truth:** 本ファイル（日本語）。更新時は本ファイルを先に直し、英訳（`claude/skills/pr-follow-loop/SKILL.md`）に反映する。

# pr-follow-loop

PR 見届けの driver（dev-loop / review-loop の兄弟）。1 tick = 1 poll + 1 PR を最大 1 歩。**時刻取得・通知 3 区分・wakeup 基準値・3 連続 breaker・tick 報告の共通規定は `~/.claude/skills/dev-loop/references/loop-driver-common.md` が SoT** — 本文で再掲しない。

三兄弟の棲み分け:
- **dev-loop** = 自分が PR を「作る」（work-intake → dev-cycle → draft PR）
- **review-loop** = 他人の PR を「レビューする」（review-requested:@me → 中立コメント）
- **pr-follow-loop**（本 skill）= 自分が author の PR を「見届ける」（open 後の bot 指摘対応 → approve 待ち → merge 後の掃除）

## 適用条件

- /loop 起動（dynamic pacing）を前提（手動単発 tick も可）
- 対象 repo の cwd / `gh` 認証済の local session
- **設定は hardcode しない**: triage 対象の bot reviewer（例: CodeRabbit）/ merge をブロックする必須 human reviewer / 対象 repo は、project の reference memory（MEMORY.md）から取得する。未登録なら「reference memory 未登録」と明示し、user に確認してから登録・継続。skill 本体に repo 名 / bot 名 / メンバー名を焼かない

## 手順（1 tick）

### Step 1: precondition check

- git repo 内 / `gh auth status` が通ること

### Step 2: poll（機械的）

```bash
gh pr list --author @me --state open \
  --json number,headRefOid,title,isDraft,url,createdAt
```

- 対象 = **自分が author の open PR**（draft 含む）。段階 a / b はこの list から進める
- merge 済 PR は `--state open` に出ないため、掃除（段階 c）の起点は別に持つ: **local の `.claude/worktrees/` 配下 worktree を列挙し、その branch の PR が merge 済か**を `gh pr list --author @me --state merged` / `gh pr view <branch>` で突き合わせる（stateless、cross-tick state を持たない）
- open PR も merge 済 worktree も無ければ Step 4（idle）へ

### Step 3: 段階判定と 1 歩（idempotency marker `<!-- pr-follow: <head-sha> -->`）

poll で拾った PR から 1 件選び（oldest created 優先）、現在の段階に応じて **1 歩だけ**進める:

#### a. bot 新指摘あり（現 head sha に未 triage の bot review）

- bot reviewer の review / inline comment を取得し、**各指摘を repo 規約（`.claude/rules/`）に照らして assess**: 妥当（fix 推奨）/ 誤検知（false-positive）/ 規約衝突・YAGNI（decline 推奨）を、severity と 1 行理由付きで判定
- **triage サマリ（各指摘 → verdict + 理由 + 推奨アクション）を提示し user に通知**。marker を記録して当該 head sha を triaged 扱いに
- **loop はここまで**: 修正の適用（commit+push）・decline 返信は **user 承認後に対話で実施**（loop が独断で fix / decline しない）。設計判断・規約衝突は必ず escalation として明示
- 判定に fresh context が要る規模なら `reviewer` を subagent で spawn 可（ただし本 skill の役割は triage の提示までで、適用はしない）

#### b. approve 待ち（未 triage 指摘なし・必須 reviewer 未 approve）

- 近リアルタイム通知のため、当該 PR の review verdict（APPROVED / CHANGES_REQUESTED）を watch する Monitor を張る（既存なら重複起動しない。TaskList で確認）
- verdict を検知したら `PushNotification` で通知（APPROVED だけでなく CHANGES_REQUESTED も拾う＝無言で待ち続けない）

#### c. merged（`.claude/worktrees/` の worktree に対応する PR が MERGED）

- 起点は Step 2 の突き合わせ: local worktree が残っているのに対応 PR が merge 済のものを対象にする
- **自動掃除**（事後報告）:
  1. 対象 worktree の `git status --porcelain` が空（clean）であることを確認。**dirty なら掃除せず escalation**（uncommitted 変更の喪失を防ぐ）
  2. clean なら `git worktree remove <path>` + **merge 済 local branch を削除**（`git branch -d`。`-D` と `--force` 系は人間実行に残す）
  3. **remote branch と他の worktree は触らない**（merge 時の GitHub auto-delete に委ねる。remote 削除は outward action で本 skill の範囲外）
- **掃除 command が permission classifier に deny された場合は迂回しない**: `--force` を含む複合 command や `git branch -D` は deny され得る。deny を受けたら残りの掃除を中止し、**未実行の command をそのまま人間に提示して終わる**。receipt には「deny により未実行」を明記する（消滅の機械確認が取れないものを「掃除完了」と報告しない）
  - 掃除に必要な最小 permission（`Bash(git worktree remove:*)` / `Bash(git branch -d:*)` 等）を settings に追加するか否かは**人間の判断事項**。skill 側から settings を書き換えない
- 掃除結果を通知（受領確認: worktree list から消滅・branch list から消滅を機械確認）

### Step 4: self-pacing（`ScheduleWakeup`）

- 基準値は loop-driver-common（1 歩進んだ → drain / 該当なし → idle / error → 900s）
- 固有: approve 待ちに移行 → 1200-1800s（Monitor が主 signal、wakeup は fallback heartbeat）
- breaker の対象 = tick の error。リセットは成功

### Step 5: tick report（強制出力）

```
## pr-follow-loop tick report
- time: <現地時刻> — previous tick: <前 report の時刻 / unknown>
- poll: <N> PR（自分 author, open）
- action: [none / PR #<n> <stage: bot-triage 提示 / approve-watch 起動 / cleanup 完了>] — receipts: <triage 通知 / Monitor task id / 掃除後の worktree・branch 消滅確認>
- notification: [sent / skipped (terminal active — normal) / not delivered / n/a]
- error streak: <n>/3
- next wakeup: <秒>（~<HH:MM> / <理由>）
```

## 鉄則

1. **approve / request-changes / merge は人間のみ** — loop は GitHub の review state を操作しない
2. **bot 指摘は triage の提示まで** — 修正適用・decline 返信は user 承認後に対話で実施。loop が独断で fix / decline しない
3. **掃除は clean 確認必須** — dirty worktree は掃除せず escalation。掃除対象は自 worktree + merge 済 local branch のみ（remote / 他 worktree は不変）。deny された掃除 command は迂回せず人間に提示する
4. **設定を hardcode しない** — bot 名 / 必須 reviewer / repo は reference memory から取得
5. **安全装置を緩めない** — hooks / permission deny / least privilege は loop でも一切緩めない
6. **共通規定（receipts 検証 / breaker / tick 報告 / 停止権限）は loop-driver-common に従う**
