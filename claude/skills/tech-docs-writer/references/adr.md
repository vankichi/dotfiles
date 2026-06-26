# ADR / Design Doc テンプレート (MADR v3 準拠)

ADRは「決定の記録」、Design Docは「提案〜決定のプロセス」を書く。テンプレートは共通で、Design Docの場合は `Status: Proposed` で書き始め、合意後に `Accepted` に更新する。

## 必須ヒアリング項目

- 決定のタイトル (例: 「ベクトル検索エンジンにValdを採用する」)
- Status (`Proposed` / `Accepted` / `Rejected` / `Deprecated` / `Superseded by [ADR-xxxx]`)
- 意思決定者 (個人名/チーム名)
- 背景 (なぜ今この決定が必要か)
- 検討した選択肢 (最低2つ以上。1つしかないなら"決定"ではない)
- 選定基準 (パフォーマンス/運用コスト/既存スタックとの整合性 など)
- 予期される帰結 (ポジティブ/ネガティブ両方)

必須項目が埋まらない場合は作成しない。特に「検討した選択肢」が1つしかない場合は、ADRではなく実装メモに分類すべきかを確認する。

## テンプレート本文

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

## 書き方のコツ

1. Context は"事実"を書く。「良いライブラリがない」ではなく「現行の X は Y の機能をサポートしていない」のように検証可能な形で。
2. Consequences は両面書く。Good だけ並ぶADRは疑わしい。Bad が思いつかないなら決定の影響範囲を理解できていない可能性がある。
3. Design Doc 用途では "Open Questions" セクションを `## More Information` の前に追加する。合意取得前の論点を可視化するため。
4. Mermaid図は Context か Decision Outcome に配置する。Before/After のアーキテクチャ図が特に有効。

## ファイル名と連番

- パス: `docs/adr/NNNN-<kebab-case-slug>.md`
- 連番: `docs/adr/` 配下の既存最大番号 + 1 (ゼロ埋め4桁)
- slug: タイトルを英語kebab-caseに変換 (例: `0012-adopt-vald-for-vector-search.md`)

## 参考

- MADR 公式: https://adr.github.io/madr/
- GitHub: https://github.com/adr/madr
