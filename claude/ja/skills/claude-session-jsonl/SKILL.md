---
name: claude-session-jsonl
description: Claude Code のセッションログ (~/.claude/projects/**/*.jsonl) のスキーマ参照と、token / cost / tool 集計 tool を作るレシピ。「Claude の使用状況を観測したい」「セッションログから集計」「ccusage 相当を作る」「JSONL の中身教えて」等で使う。言語別サンプル parser は references/ にある。
---

# claude-session-jsonl

Claude Code がローカルに残すセッションログ (JSONL) の構造を **正確に** 知っていることを前提にした集計 tool は何度も書きたくなる (ccwatch / ccusage / cclog / ccexport ...)。毎回手で `head -1 *.jsonl | jq` から始めると時間が溶けるので、確認済みのスキーマと典型的な落とし穴を 1 箇所に固める。

> **Snapshot**: 2026-04 時点 / Claude Code 2.1.x が書き出す JSONL を観測してまとめたもの。
> Claude Code がスキーマを更新したら (event type 増加、usage フィールド変更等) ここも更新。
> 単価表は Anthropic の公式ページが原本、ここはキャッシュ。

## いつ使うか

- 「Claude の使用状況を tool 化したい」
- 「セッション jsonl をパースして X を出したい」
- 「ccusage / ccwatch みたいなのを別言語で作りたい」
- 「context window 使用率を計算したい」

実装言語は問わない (Rust / TypeScript / Python が主)。本 skill はスキーマ説明 + 設計判断 + 各言語の最小 parser を提供する。**実装そのものは別の手段** (`/rust-bootstrap` → `/add-rust-crate` → 実装 / TS なら手作業) に渡す。

## ファイル配置

```
~/.claude/projects/<encoded-cwd>/<session-uuid>.jsonl
```

- **`<encoded-cwd>`** は `cwd` の `/` を `-` に置換した文字列。例: `/Users/foo/repo` → `-Users-foo-repo`
- **`<session-uuid>`** は v4 UUID (例: `ec65e22c-0dab-4eff-b119-c2e2cb02aa8a`)
- 1 ファイル = 1 セッション。`/clear` で新ファイル
- 同 cwd で複数セッションが共存しうる (古い + 進行中)
- ファイルは **append-only**。途中行の書き換えは原則ない (rotation は新 UUID 別ファイル化)

最新セッションを拾う = 「**最終更新時刻 (`mtime`) が一番新しい `*.jsonl`**」を取れば良い。

## スキーマ (event types)

各行は 1 つの JSON オブジェクト。`type` フィールドで分岐。

| `type` | 用途 | 集計に使う? |
|---|---|---|
| `assistant` | アシスタント発話 (token usage / tool 呼び出し / model 名がここ) | **YES (主役)** |
| `user` | ユーザ発話 / コマンド出力 (`/`-command の caveat 含む) | 必要なら |
| `system` | システムメッセージ (slash command の stdout 等) | 通常不要 |
| `attachment` | 添付/イベント (deferred tool delta 等) | 通常不要 |
| `file-history-snapshot` | ファイル履歴スナップショット (Edit のロールバック用) | 不要 |
| `last-prompt` | 最後の user prompt (再生成用キャッシュ) | 不要 |

**他の type が出ても無視する** (`#[serde(other)]` / catch-all) のが正解。Claude Code の更新で新 type が増えたとき壊れない。

## 集計に必須: `assistant` event

形 (一部省略):

```json
{
  "type": "assistant",
  "uuid": "997e63ff-e2c6-...",
  "parentUuid": "d6c11651-...",
  "sessionId": "ec65e22c-...",
  "timestamp": "2026-04-27T04:32:12.600Z",
  "message": {
    "id": "msg_018Znq...",
    "model": "claude-opus-4-7",
    "role": "assistant",
    "type": "message",
    "content": [
      { "type": "thinking",  "thinking": "...", "signature": "..." },
      { "type": "text",      "text": "hello" },
      { "type": "tool_use",  "name": "Bash", "input": { ... } }
    ],
    "usage": {
      "input_tokens": 6,
      "output_tokens": 1103,
      "cache_creation_input_tokens": 9667,
      "cache_read_input_tokens": 15206,
      "service_tier": "standard",
      "cache_creation": { "ephemeral_1h_input_tokens": 9667, "ephemeral_5m_input_tokens": 0 },
      "iterations": [ ... ]
    },
    "stop_reason": "end_turn"
  },
  "requestId": "req_011...",
  "cwd": "/Users/foo/repo",
  "version": "2.1.x",
  "gitBranch": "main"
}
```

### 重要フィールド

| パス | 型 | 用途 |
|---|---|---|
| `message.model` | string | 例: `claude-opus-4-7`, `claude-fable-5`, `claude-opus-5`, `claude-sonnet-5`, `claude-haiku-4-5-20251001`. 大文字小文字混在 (`[1m]` で 1M context variant)。usage が全 0 の `<synthetic>` 行も混在する (集計から除外) |
| `message.usage.input_tokens` | u64 | このターンで billable な新規 input |
| `message.usage.output_tokens` | u64 | アシスタント生成の output |
| `message.usage.cache_creation_input_tokens` | u64 | キャッシュ書き込み合計 (5min + 1hr) |
| `message.usage.cache_creation.ephemeral_5m_input_tokens` | u64 | 5min ephemeral 書き込み (1.25× input) |
| `message.usage.cache_creation.ephemeral_1h_input_tokens` | u64 | 1hr ephemeral 書き込み (**2.00× input**) |
| `message.usage.cache_read_input_tokens` | u64 | キャッシュヒット (最安, 0.10× input) |
| `message.content[].type` | string | `tool_use` / `text` / `thinking` ほか |
| `message.content[].name` | string | `tool_use` 限定。`Bash` / `Edit` / `Read` / `Grep` / `Write` / `Agent` / `WebFetch` 等 |
| `timestamp` | RFC3339 string | レイテンシ計算 / sliding window / active 検出 |

> ⚠ `cache_creation_input_tokens` (top-level 合計) と `cache_creation.{5m,1h}` (内訳) の両方が出る。**コスト計算には内訳を使うこと**。Claude Code の実セッションは現在ほぼ全部 1hr ephemeral で、この差は数十%以上のコスト誤差になる。

### 派生量 (頻出)

```
context_size       = input_tokens + cache_creation_input_tokens + cache_read_input_tokens
context_window     = 200_000 (default) | 1_000_000 (model 名に [1m] / -1m)
context_pct        = min(context_size / context_window, 1.0)
cache_hit_ratio    = cache_read_input_tokens / context_size
session_cost_usd   = sum over assistants of pricing(model).cost_usd(usage)
tokens_per_minute  = (input + output + cache_creation) / elapsed_secs * 60
cost_per_hour      = session_cost_usd / elapsed_secs * 3600
```

## モデル別単価 (USD per million tokens, 2026-07 時点 — claude-api skill で照合)

> ⚠ Anthropic のページで定期的に更新される値。SoT は claude-api skill (「LLM pricing は memory で答えない」trigger)。tool 化したらコメントで照合時点を残し、ハードコードを 1 箇所に集約 (例: `pricing.rs`) しておくこと。

| family | input | output | cache_w 5min (1.25×) | cache_w 1hr (2.00×) | cache_read (0.10×) |
|---|---:|---:|---:|---:|---:|
| Fable | 10.00 | 50.00 | 12.50 | 20.00 | 1.00 |
| Opus (4.6 以降 / 5) | 5.00 | 25.00 | 6.25 | 10.00 | 0.50 |
| Sonnet | 3.00 | 15.00 | 3.75 | 6.00 | 0.30 |
| Haiku | 1.00 | 5.00 | 1.25 | 2.00 | 0.10 |

Opus 4.5 以前の旧単価 ($15/$75) のログが混在する期間は family 判定だけでは過小計上になる — 厳密さが要る場合は model 名で世代を分ける。

cost 計算式:

```
cost = input × input_rate
     + output × output_rate
     + cache_5m × cache_w_5m_rate    # cache_creation.ephemeral_5m_input_tokens
     + cache_1h × cache_w_1h_rate    # cache_creation.ephemeral_1h_input_tokens
     + cache_read × cache_read_rate
```

`cache_creation` フィールドが欠けている古いログは「全部 5min」とみなしてフォールバックすると後方互換が取れる。

未知モデル名は **Sonnet にフォールバック** が無難 (中間値・現行 default tier)。

## 設計判断 — 落とし穴と推奨

1. **ファイル監視は poll-based + reopen + seek + read_to_end + remainder buffer**。`notify` crate は append-only ログには rotation/atomic-replace でハマるので避ける。`tokio::io::BufReader::lines()` over manually-seeked file も EOF 扱いが面倒で結局再 seek が要る。**自前 200ms ポーリング + `\n` で split が最もロバスト**。
2. **行は `\n` で確実に区切られる**。途中で UTF-8 codepoint が割れる心配は不要 (codepoint は完結状態で書き込まれる)。
3. **ファイル shrink (≒ rotation) で offset を 0 に reset**。`/clear` 等で新ファイル化されると別 UUID なので、watcher は「新しい mtime のファイルを再選択」する設計が良い (本 skill 範囲外)。
4. **`last-prompt` は最終 prompt のキャッシュ用**で集計には使わない (内容は user 発話と重複)。
5. **`thinking` ブロックの token 数は `output_tokens` に含まれている** (別カウントしない)。
6. **`iterations` 配列**は server-side の細分化情報。集計では一番外の `usage` を信用すれば十分。
7. **model 名の判定は `to_ascii_lowercase().contains("fable" | "opus" | "sonnet" | "haiku")`** で family を取る (fable を先に判定 — `claude-fable-5` は 2026-07 時点の log に実在)。完全一致は壊れる (`claude-opus-4-7`, `claude-opus-4-7[1m]`, `claude-3-opus-...` 等が混在)。fable は Opus より高単価の別 family — sonnet fallback に落とさず価格表の Fable 行を使う。
8. **encoded-cwd を逆引きする必要があるか?** ある (どのリポジトリのセッションか表示する場合)。`-` を `/` に戻すだけだが、もとの cwd に `-` が含まれていた場合は不可逆 — `assistant.cwd` が原本としてイベント内に入っているのでそちらを参照するのが安全。
9. **集計はセッション単位** が基本。「全セッション横断で today の累計コスト」を出したい場合は `<projects-dir>/**/*.jsonl` の各ファイル全行を読み、`timestamp` で当日フィルタ → usage 合算する (重め)。

## 最小 parser (言語別)

実装言語が決まったら **該当する reference だけ** Read する (全言語を読まない):

| 言語 | reference | 要点 |
|---|---|---|
| Rust | `references/parser-rust.md` | serde tagged enum + `#[serde(other)]` catch-all |
| TypeScript | `references/parser-typescript.md` | zod discriminatedUnion + catch-all |
| Python | `references/parser-python.md` | dict ベース + dataclass Usage |

## 動作確認用コマンド

```bash
# セッションファイル一覧 (最新順)
ls -lt ~/.claude/projects/*/  | head -20

# 最新ファイルの event type 分布
jq -r .type < $(ls -t ~/.claude/projects/*/*.jsonl | head -1) | sort | uniq -c

# 最新ファイルの usage を 1 行ずつ
jq -c 'select(.type=="assistant") | {model: .message.model, usage: .message.usage}' \
   < $(ls -t ~/.claude/projects/*/*.jsonl | head -1) | head -3

# 当日全セッションのモデル別 output_tokens 合計
jq -r 'select(.type=="assistant" and .timestamp > "'$(date -u +%Y-%m-%d)'") |
       [.message.model, .message.usage.output_tokens] | @tsv' \
       ~/.claude/projects/*/*.jsonl |
  awk -F'\t' '{m[$1]+=$2} END {for (k in m) printf "%-30s %d\n", k, m[k]}'
```

## 鉄則

1. **未知 type は捨てる**。Claude Code の更新で増えても壊さない設計を default にする
2. **`thinking` は output_tokens に含まれている**。二重カウントしない
3. **モデル名判定は substring で family を取る**。完全一致しない
4. **単価表は 1 箇所に集中**。「2026-04 時点」のコメント必須
5. **集計はファイル単位 → セッション単位**。複数日にまたがる解析でも `timestamp` フィルタを先にかける
6. **read-only**。本 skill のコードはセッションファイルを書き換えない (検証用 jq も読み取りのみ)

## アンチパターン

- **`notify` crate でログ tail**: rotation で取りこぼす
- **`type` を完全一致で enum 解釈**: 未知 type で panic / unwrap
- **`assistant` 以外の event の `usage` を読む**: そもそも存在しない
- **モデル名を完全一致で hash 引き**: バージョン suffix で全部 miss
- **`cache_*` を input_tokens に含める計算**: 単価が違う 4 種を混ぜると 5x 程度のずれが出る
- **encoded-cwd を逆引きで cwd 復元**: `-` の曖昧さで誤動作。`assistant.cwd` を読む
- **`read_to_string` でファイル丸ごと**: 大きなセッションでメモリ膨張。`BufReader` + line iter でストリーム
