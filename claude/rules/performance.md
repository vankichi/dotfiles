---
paths:
  - "**/*.{go,rs,py,rb,ts,tsx,js,jsx,java,kt,php,sql,c,cc,cpp,h,hpp,proto}"
---

# Performance 規約 (言語非依存)

「とりあえず動く」で止めず、計算量・メモリ・I/O・レイテンシを設計時点で意識する。明らかに高コストな選択を default にしない。言語固有イディオム (`errgroup` / `asyncio` 等) は各言語 skill 側。

## 計算量 / アルゴリズム

- ループ内のループ / ループ内 I/O / ループ内 allocation は意識的に flag。N が小さくて問題ないなら根拠を明示
- O(N²) 以上を書く場合、入力サイズの上限と根拠を 1 行残す
- 繰り返す線形検索は hash set / map 化を検討。既存コードの計算量を悪化させない
- データ構造は順序 / 一意性 / lookup・insert 頻度で選ぶ

## メモリ / allocation

- 大きな collection / buffer は容量ヒント付きで事前確保
- 不要な copy / 型変換 / serialize ↔ deserialize を入れない
- streaming で処理できるもの (file / HTTP body / DB query / log) を全部読み込まない。巨大データはチャンク処理

## I/O / network

- N+1 query を避ける (bulk / batch / join / dataloader 相当)
- timeout は必ず設定 (デフォルト無限の client は明示的に上書き)
- リトライは 回数 / 対象エラー / backoff / idempotency を明示。rate limit / circuit breaker を default で意識
- 独立 I/O は並列化 + 並列度上限。依存 I/O は直列
- 必要なフィールドだけ取得 (over-fetch / `SELECT *` 回避)。pagination は cursor 系を default

## コンカレンシー

- cancellation / timeout / tracing は最深部まで伝播させる
- 起動した並行タスクは必ず終了経路を持つ (leak を作らない)
- 共有状態は immutable / 排他制御 / message passing の 3 択で設計。read-modify-write / check-then-act は atomic / lock / CAS で守る

## キャッシュ / メモ化

- 同じ計算・I/O を 1 リクエスト内で繰り返さない (request-scoped cache)
- process-scoped cache は TTL / 無効化戦略 / 容量上限 / eviction を必ず明示
- 分散環境では stampede / stale read を意識
- LLM / API client は provider のキャッシュ機能を default で組み込む (Claude なら prompt caching → `claude-api` skill)

## レイテンシ / スループット

- p50 / p95 / p99 のどれを最適化するか最初に決める
- critical path にブロッキング I/O / 重い計算を置かない (background へ)
- payload サイズ (compression / 不要フィールド削除) もレイテンシ要素

## 計測してから最適化

- 修正前に計測 (profiler / benchmark / trace)。憶測で書き換えない
- 「速くなった」は before / after の数値で示す。ボトルネック特定前の micro-optimization に走らない

## Observability

- 重要処理は metrics + logs + traces の 3 軸。高 cardinality label を metrics に入れない。log は構造化 default

## trade-off は user 判断 (比較形式で提示)

可読性 vs パフォーマンス / メモリ vs CPU / レイテンシ vs スループット / 整合性 vs 可用性 / 正確性 vs 速度
