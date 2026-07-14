# conventions — memory 規約整合 + forbidden tokens

skip 可: なし (常時実施)。

## memory 規約整合

Phase 1 で把握した関連 memory に対して、編集差分が違反していないか check:

- 用語規約 (memory の用語規約に準拠)
- 文書スタイル (前提節を立てない、prototype 期の緩和)
- コメント言語 (`*.go` / Makefile / proto / shell の英語)
- コメント内に Phase / ticket ID 表記の混入
- commit message スタイル (短く、変更内容のみ)

## cross-reference / forbidden tokens grep

変更 file 全体に grep:

- **一時情報の混入**: `ticket`, `in a later`, `future ticket`, `see (commit|PR) #`, ticket ID 形式 (`#?\d+`, `[A-Z]+-\d+`)。検査 pattern の literal は project の `MEMORY.md` feedback から取得、skill 側 hardcode しない
- **cross-reference 実在確認**: コメント内 section 参照 (`§[0-9]+\.[0-9]+` 等) の引用語彙が原文と一致しているか
- **推測 mapping**: 原文に書かれていない対応関係をコメントで補完していないか (原文 literal の範囲だけ)
