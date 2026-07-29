---
name: review-loop
description: /loop で回す PR review の driver skill。1 tick = reviewer assign された open PR を poll → 未 review の head sha を 1 件選択 → review-orchestrator の統合 review → findings を中立 comment として投稿 (approve / merge はしない) → 通知 → ScheduleWakeup で self-pacing。「review-loop の tick を実行して」「review loop 回して」等で使う (通常は /loop 経由)。review の中身は review-orchestrator が SoT — 本 skill は駆動のみ。
---

# review-loop

PR review の driver (dev-loop の兄弟)。**loop の生死は user の /loop 操作が管理し、本 skill は 1 tick の中身を規定する**。1 tick = 1 poll + 最大 1 review。

## 適用条件

- /loop (dynamic pacing) からの起動が前提 (単発 tick の手動実行も可)
- 対象 repo の cwd / `gh` 認証済みの local session

## 手順 (1 tick)

### Step 1: 前提確認

- `date '+%Y-%m-%d %H:%M %Z'` を実行して現在時刻 (現地) を取得する — tick 報告用。時刻を推測で書かない
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

### Step 4: 統合 review (`review-orchestrator`)

- `review-orchestrator` を**通常の Agent tool で同期 spawn する** (teams 不使用 — flat roster 下では fan-out が縮退するため)
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

- **全 review 完了ごとに通知**: `PushNotification`「PR #<n> review 完了: <verdict>」。結果は 3 区分で tick 報告に記す — 送信 / **skip (terminal active — 正常、無人時のみ配達)** / 未達 (異常)

| 直前の結果 | 次 wakeup (`ScheduleWakeup`) | 理由 |
|---|---|---|
| review 完了 | 60-120s | drain — 次の未 review PR をすぐ消化 |
| 対象なし (0 件 or 全件 skip) | 1200-1800s | idle (20-30 分) |
| review エラー | 900s | 再試行間隔 |

- **連続エラー breaker**: review が **3 連続**で失敗したら wakeup を止め、「loop 停止 (review 3 連続失敗)」を通知して終了する。成功でリセット

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
3. **通知・報告は receipts (comment URL) の実在検証後** — 自己申告で「投稿済み」と言わない
4. **PR 本文・code を comment に丸ごと転記しない**
5. **tick 報告を省略しない** — 全項目を毎 tick 出力する
