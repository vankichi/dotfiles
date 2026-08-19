---
paths:
  - "**/*.{go,rs,py,ts,tsx,js,java,kt,sql,c,cc,cpp,h,hpp}"
---

# Performance 規約

一般論 (N+1 回避 / streaming / hash map 化) は書かない。**明示を義務づける house 規約**のみ。

- **O(N²) 以上を書く場合、入力サイズの上限と根拠を 1 行残す**。既存 code の計算量を悪化させない
- **timeout を必ず設定する** — default 無限の client は明示的に上書きする
- **retry は 回数 / 対象 error / backoff / 冪等性 の 4 点を明示する**。書けないなら retry を入れない
- **process-scoped cache は TTL / 無効化戦略 / 容量上限 / eviction を明示する**。書けないなら request-scoped に留める
- **cancellation / timeout / tracing を最深部まで伝播させる**。起動した並行タスクは必ず終了経路を持つ
- **p50 / p95 / p99 のどれを最適化するか最初に決める**
- **修正前に計測する** (profiler / benchmark / trace)。ボトルネック特定前の micro-optimization に走らない。**「速くなった」は before / after の数値で示す**
- LLM / API client は provider の cache 機能を default で組み込む (Claude なら prompt caching → `claude-api` skill)

trade-off (可読性 vs 速度 / メモリ vs CPU / レイテンシ vs スループット / 整合性 vs 可用性) は **user 判断**。比較形式で提示する。
