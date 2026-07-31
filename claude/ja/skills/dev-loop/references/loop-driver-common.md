# loop driver 共通規定 (dev-loop / review-loop / pr-follow-loop)

/loop で回す driver skill 3 種の共通規定。各 skill はここを参照し、本文で再掲しない。**loop の生死は user の /loop 操作が管理し、skill は 1 tick の中身だけを規定する。**

## 時刻

- tick 冒頭で `date '+%Y-%m-%d %H:%M %Z'` を実行して現地時刻を取得する (tick 報告用)。時刻を推測で書かない

## 通知の 3 区分 (tick 報告に必ず記す)

| 区分 | 意味 | 扱い |
|---|---|---|
| 送信 | PushNotification が発行された | 正常 |
| skip (terminal active) | user が terminal で active なため tool が意図的に抑止 | **正常** (通知は無人時のみ配達される仕様) |
| 未達 | tool 不可・エラー | **異常** — 沈黙せず報告する |

通知・完了報告は **receipts (PR URL / comment URL / 消滅確認等) の実在を機械確認してから**行う。subagent の自己申告をそのまま転送しない。

## self-pacing の基準値 (`ScheduleWakeup`)

| 状況 | 次 wakeup |
|---|---|
| 1 歩進んだ (drain — 続きを即消化) | 60-120s |
| 対象なし (idle) | 1200-1800s |
| エラー後の再試行 | 900s |
| 実行中の外部処理の完了待ち | 300s |

skill 固有の行 (Notion 不達等) は各 skill 側にのみ書く。

## 3 連続 breaker

失敗 (escalation / error) が **3 連続**したら `ScheduleWakeup` を stop し、「loop 停止 (3 連続)」を**通知してから**終了する (無言で止めない)。成功でカウントをリセット。恒久停止の判断は user の /loop 操作のみ。

## tick 報告

毎 tick、報告 template の**全項目を省略せず出力する**。共通 field: 時刻 (+ 前回 tick 時刻) / poll 結果 / action + receipts / 通知区分 / 連続カウント n/3 / 次 wakeup 秒 (~HH:MM、理由)。
