# performance — 計算量 / I/O パターンの静的検査

skip 可: code diff が 0。profile は取らず、静的に疑い箇所を flag するレベル (詳細な基準は `~/.claude/rules/performance.md` を参照)。

- **計算量**: 追加した loop の nest が入力サイズに対して O(n²) 以上になっていないか / 既存の O(n) 経路を O(n²) に劣化させていないか
- **I/O パターン**: loop 内での逐次 I/O (N+1 query / 1 件ずつの API call / file open) — batch 化・事前 fetch できないか
- **hot path allocation**: 頻繁に呼ばれる経路での不要な alloc (loop 内の slice/map 生成、string 連結、`fmt.Sprintf`) / `strings.Builder` や事前 capacity 指定の検討
- **不要な同期**: 粗すぎる lock 範囲 / channel の不要な同期待ち / 並列化できる独立処理の直列実行
- **劣化の検出**: 変更が既存の性能特性 (量・頻度の前提) を変える場合、spec の制約セクションと突き合わせる (目標なしなら flag のみ)
