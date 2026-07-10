# ADR / Design Doc Template (MADR v3 compliant)

> **Source of truth:** `claude/ja/skills/tech-docs-writer/references/adr.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

An ADR writes 「決定の記録」 (a record of the decision); a Design Doc writes 「提案〜決定のプロセス」 (the process from proposal to decision). The template is shared: for a Design Doc, start writing with `Status: Proposed`, then update it to `Accepted` once agreement is reached.

## Required interview items

- Decision title (e.g., 「ベクトル検索エンジンにValdを採用する」)
- Status (`Proposed` / `Accepted` / `Rejected` / `Deprecated` / `Superseded by [ADR-xxxx]`)
- Decision maker(s) (individual name / team name)
- Background (why this decision is needed now)
- Options considered (at least 2 — if there's only one, it isn't a "decision")
- Selection criteria (performance / operational cost / consistency with the existing stack, etc.)
- Expected consequences (both positive and negative)

Do not create the document if the required items cannot be filled in. In particular, if there is only one entry under 「検討した選択肢」 (options considered), confirm whether it should be classified as an implementation memo rather than an ADR.

## Template body

```markdown
# ADR-NNNN: <決定のタイトル>

- **Status**: <Proposed | Accepted | Rejected | Deprecated | Superseded by ADR-XXXX>
- **Date**: YYYY-MM-DD
- **Deciders**: <意思決定者名/チーム名>
- **Consulted**: <相談した人・チーム (任意)>
- **Informed**: <通知先 (任意)>

## Context and Problem Statement

<なぜこの決定が必要か。解きたい課題を1〜3段落で。背景の事実と制約を分けて書く。>

## Decision Drivers

体言止めで簡潔に。動詞で閉じない。

- <例: P99レイテンシ100ms以下>
- <例: Go SDKの公式提供>
- <例: Kubernetes上でのHA構成の容易さ>

## Considered Options

1. **<選択肢A>**
2. **<選択肢B>**
3. **<選択肢C>**

## Decision Outcome

**Chosen option**: "<選択肢X>"

理由: <選定基準に照らしてなぜこれを選んだか。2〜5文>

### Consequences

体言止めで簡潔に。

- Good: <例: P99レイテンシの大幅改善>
- Good: <例: 既存Goスタックとの統合容易性>
- Bad: <例: 新技術導入に伴う学習コスト>
- Bad: <例: 既存Elasticsearchからの移行作業>

### Confirmation

<決定が守られていることをどう検証するか。例: CIのベンチマーク、監視指標、コードレビュー時のチェック項目>

## Pros and Cons of the Options

### <選択肢A>

<概要1文>

- Good: <...>
- Good: <...>
- Neutral: <...>
- Bad: <...>

### <選択肢B>

<同上>

### <選択肢C>

<同上>

## More Information

<参考リンク、関連ADR、補足資料>
```

## Writing tips

1. Write "facts" in Context. Instead of phrasing it like 「良いライブラリがない」, write it in a verifiable form such as 「現行の X は Y の機能をサポートしていない」.
2. Write Consequences from both sides. An ADR that lists only Good items is suspicious. If you can't think of any Bad items, you may not have fully understood the decision's scope of impact.
3. For Design Doc use, add an "Open Questions" section before `## More Information`, to surface the points still under discussion before consensus is reached.
4. Place Mermaid diagrams in Context or Decision Outcome. Before/After architecture diagrams are especially effective.

## File name and sequence number

- Path: `docs/adr/NNNN-<kebab-case-slug>.md`
- Sequence number: existing max number under `docs/adr/` + 1 (zero-padded to 4 digits)
- Slug: convert the title to English kebab-case (e.g., `0012-adopt-vald-for-vector-search.md`)

## References

- MADR official site: https://adr.github.io/madr/
- GitHub: https://github.com/adr/madr
