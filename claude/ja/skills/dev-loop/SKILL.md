---
name: dev-loop
description: /loop で回す dev loop の driver skill。1 tick = work-intake poll → (work item があれば) dev-cycle を直列実行 → receipts 検証済みの完了 / escalation 通知 → ScheduleWakeup で次 tick の self-pacing。「dev-loop の tick を実行して」「dev loop 回して」等で使う (通常は /loop 経由)。cycle の中身は dev-cycle が SoT — 本 skill は駆動のみ。
---

# dev-loop

Dev loop の driver。**loop の生死は user の /loop 操作が管理し、本 skill は 1 tick の中身を規定する**。1 tick = 1 poll + 最大 1 cycle。

## 適用条件

- /loop (dynamic pacing) からの起動が前提 (単発 tick の手動実行も可)
- 対象 repo の cwd / Notion MCP が使える local session (interactive auth のため headless 不可)

## 手順 (1 tick)

### Step 1: 前提確認

- `date '+%Y-%m-%d %H:%M %Z'` を実行して現在時刻 (現地) を取得する — tick 報告の時刻欄用。時刻を推測で書かない
- git repo 内であること
- **直列 guard**: per-project plans dir の state file 群を確認し、active な cycle (Current state が全工程完了 / escalation 停止を示していない state file) が存在しないこと。存在するなら本 tick は cycle を起動せず Step 5 へ (300s wakeup — 実行中 cycle の完了待ち)
- Notion 到達性は work-intake に委ねる (不達なら Step 2 が異常終了 → 「Notion 不達」を通知して 1800s wakeup)

### Step 2: poll (`work-intake`)

- `work-intake` skill を起動する
- 該当なし (work item 0 件) → Step 5 (idle 間隔)
- work item が返ったら Step 3 へ

### Step 3: cycle (`dev-cycle` 直列実行)

- `dev-cycle` を**通常の Agent tool で spawn する — teams を使わない** (flat roster 下では nested spawn 不可で review fan-out が inline 縮退するため。通常 spawn の nested fan-out は実証済み)
- **同期起動 (`run_in_background: false`)** — 完了まで待つ。1 tick 最大 1 cycle、並列起動しない
- prompt には work item 全文を渡す (dev-cycle 側で loop-mode と判定される)
- **cycle 完了後に自分の cwd を確認する**: dev-cycle subagent が `EnterWorktree` すると呼び出し側 (本 skill) の shell cwd も worktree 配下へ移動・固定される (`cd` で戻しても `Shell cwd was reset to ...` で戻される)。cwd が worktree 配下なら `ExitWorktree(action: keep)` で復帰する — **worktree は残るので掃除ではなく cwd 復帰**。以後の poll / 通知が worktree 側の path 解決 (per-project plans dir 等) にならないようにする

### Step 4: 通知 (receipts の実在検証後)

dev-cycle の報告から receipts を取り、**実在を機械確認してから** `PushNotification` で通知する:

| 結果 | 検証 | 通知 |
|---|---|---|
| 完走 | PR URL を `gh pr view` で確認 | 「<ticket-id>: draft PR <URL>」 |
| escalation | ticket コメント / WIP branch (`git ls-remote`) を確認 | 「<ticket-id>: escalation (<停止理由 1 行>)」 |
| receipts が実在しない | — | 「<ticket-id>: 報告と実態の乖離を検出」+ escalation 扱いでカウント |

- 通知結果は **3 区分**で扱い、tick 報告に必ず記す: **送信** (発行された) / **skip (terminal active)** = user が terminal で active なため tool が意図的に抑止 — **正常** (通知は無人時のみ配達される仕様) / **未達** (tool 不可・エラー — 異常。沈黙しない)

### Step 5: self-pacing (`ScheduleWakeup`)

| 直前の結果 | 次 wakeup | 理由 |
|---|---|---|
| cycle 完走 | 60-120s | drain — 続きの ready をすぐ消化 |
| 空 queue (該当なし) | 1200-1800s | idle (20-30 分) |
| escalation | 1200-1800s | 通常継続 (対象 ticket は InProgress で再 pick されない) |
| 直列 guard hit | 300s | 実行中 cycle の完了待ち |
| Notion 不達 | 1800s | 復旧待ち |

- **連続 escalation breaker**: escalation (乖離検出を含む) が **3 連続**したら wakeup を止め (`ScheduleWakeup` stop)、「loop 停止 (escalation 3 連続)」を通知して終了する。連続カウントは cycle 完走でリセット

### Step 6: tick の報告 (強制出力)

```
## dev-loop tick 報告
- 時刻: <現在時刻 (現地)> — 前回 tick: <前回報告の時刻 / 不明>
- poll: [該当なし / <ticket-id> を選択]
- cycle: [未実行 / 完走 (PR <URL>) / escalation (<理由>)] — receipts: <検証済み一覧>
- escalation 連続: <n>/3
- 通知: [送信 / skip (terminal active — 正常) / 未達 / 対象なし]
- 次 wakeup: <秒> (~<HH:MM> 頃 / <理由>)
```

## 鉄則

1. **並列 cycle を起動しない** — 直列 guard を skip しない
2. **通知は receipts の実在検証後** — dev-cycle の自己申告をそのまま転送しない
3. **escalation で loop を止めない** — 例外は 3 連続 breaker のみ
4. **loop の恒久停止は user の /loop 操作** — breaker 発動時も「停止した」通知を必ず送る
5. **tick 報告を省略しない** — 全項目を毎 tick 出力する
