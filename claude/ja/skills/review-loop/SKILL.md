---
name: review-loop
description: /loop で回す PR review の driver skill。1 tick = reviewer assign された open PR を poll → 未 review の head sha を 1 件選択 → reviewer の統合 review → findings を中立 comment として投稿 (approve / merge はしない) → 通知 → ScheduleWakeup で self-pacing。「review-loop の tick を実行して」「review loop 回して」等で使う (通常は /loop 経由)。review の中身は reviewer が SoT — 本 skill は駆動のみ。
---

# review-loop

PR review の driver (dev-loop の兄弟)。1 tick = 1 poll + 最大 1 review。**時刻取得・通知 3 区分・wakeup 基準値・3 連続 breaker・tick 報告の共通規定は `~/.claude/skills/dev-loop/references/loop-driver-common.md` が SoT** — 本文で再掲しない。

## 適用条件

- /loop (dynamic pacing) からの起動が前提 (単発 tick の手動実行も可)
- 対象 repo の cwd / `gh` 認証済みの local session

## 手順 (1 tick)

### Step 1: 前提確認

- git repo 内であること / `gh auth status` が通ること

### Step 2: poll (機械実行)

```bash
gh pr list --state open --search "review-requested:@me" \
  --json number,headRefOid,title,isDraft,url,createdAt
```

- **自分に review request が来ている open PR** が対象 (draft 含む)。0 件なら Step 6 (idle) へ

### Step 3: idempotency filter (機械実行)

- 各 PR の comment を確認し、本 skill の marker **`<!-- review-loop: <head-sha> -->`** を探す
- **現 head sha (`headRefOid`) が marker に一致する PR は skip** — 新 push で sha が変わった時だけ再 review する
- 未 review の PR から **1 件**選択する (作成が古い順)。全件 skip なら Step 6 (idle) へ

### Step 4: 統合 review (`reviewer`)

- `reviewer` を**通常の Agent tool で同期 spawn する** (teams 不使用)
- 渡すもの: PR の diff 範囲 (base..head) / spec = **PR body + 本文が参照する ticket (あれば)** / repo 規約・設計 docs の path 一覧 (CLAUDE.md / rules / lint 設定 / docs 内設計文書を glob) / 簡易影響分類 (`gh pr diff <n> --stat` + diff 本体から `~/.claude/rules/impact-scope.md`「簡易判定」に従って分類する。impact-C は correctness / test-adversarial を重点指定)
- state file 相当は渡さない (standalone review — 実装 context を持たせない)

### Step 5: comment 投稿 (receipts 検証まで)

- verdict + findings 表 + 観点実施状況を 1 本の comment に整形し、**冒頭に marker** を付けて投稿する:

```bash
gh pr comment <number> --body '<!-- review-loop: <head-sha> -->
## 統合 review (review-loop)
verdict: <approve / approve-with-notes / fix-required / escalation>
<findings 表 / 観点実施状況 / 総評>'
```

- 投稿後に comment URL を取得して **receipt として実在確認**する
- **approve / request-changes / merge / GitHub の review state は使わない** — 中立 comment のみ (merge 判断は人間)
- secret / 内部 URL / code の丸ごと転記を comment に含めない (findings は file:line 参照)

### Step 6: 通知 + self-pacing

- **全 review 完了ごとに通知**: `PushNotification`「PR #<n> review 完了: <verdict>」
- wakeup は loop-driver-common の基準値どおり (review 完了 → drain / 対象なし → idle / エラー → 900s)。breaker の対象 = review の失敗、リセットは成功

### Step 7: tick の報告 (強制出力)

```
## review-loop tick 報告
- 時刻: <現在時刻 (現地)> — 前回 tick: <前回報告の時刻 / 不明>
- poll: 対象 <N> 件 (うち review 済み skip <M> 件)
- review: [なし / PR #<n> <verdict>] — receipts: <comment URL>
- 通知: [送信 / skip (terminal active — 正常) / 未達 / 対象なし]
- エラー連続: <n>/3
- 次 wakeup: <秒> (~<HH:MM> 頃 / <理由>)
```

## 鉄則

1. **approve / request-changes / merge をしない** — 中立 comment のみ
2. **同一 head sha に再 comment しない** — marker 照合 (Step 3) を skip しない
3. **PR 本文・code を comment に丸ごと転記しない**
4. **共通規定 (receipts 検証 / breaker / tick 報告 / 停止権限) は loop-driver-common に従う**
