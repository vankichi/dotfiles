# 汎用版 checklist (repo に観点 file が無い場合の fallback)

repo 側に `.claude/rules/spec-drift.md` / `.claude/rules/data-modeling.md` が無いときだけ使う。repo 固有の path / 識別子を含まない汎用形。使用時は「repo 固有の観点なしで実施」と出力に明示する。

## 乖離 5 分類

| # | 分類 | 検出手順 |
|---|---|---|
| D1 | spec 内部の矛盾 | entity (列 / field / endpoint / 順序 / failure mode) ごとに規範的記述を集め総当たりで突合。複数 section に登場する entity に集中する |
| D2 | spec ↔ 実装 | spec が挙げる識別子 (型 / 関数 / 列 / field / 環境変数 / task) を全て grep。hit しないものは「本当に新規」か「名前違い」のどちらかを判定して明示 |
| D3 | spec ↔ SoT doc | 変更領域の doc の確定度表記を doc 全体・section 単位の両方で読む。未確定 section に依存する spec は依存を名指しして確認を取る |
| D4 | 出典が repo に無い引用 | 全ての引用を path + 見出しに解決する。解決できない引用は根拠ではない (repo の literal に置換 or 削除) |
| D5 | 既存の見落とし | 「X を追加」を受け入れる前に、schema / API 定義 / error 定義 / 設定 file の既存面を grep する |

D1 の頻出パターン: 「挙動不変 / 既存 test はそのまま green」と同一 code path への新しい内部挙動指定の併存 / DoD の例表の期待値が設計本体の算法から出ない / non-goals が除外するものを DoD が要求。

doc 同士が矛盾する場合は doc 種別で順位を付けず、doc 自身の SoT 宣言を探して従う。宣言が無ければ人間へ escalate。

## data model 最小化

優先順位は **導出 > 既存列の意味を締める > 列を足す**。

- 新しい列をまず疑う。既存の状態 (timestamp / 行の存在 / 既存 enum) から導出できないか
- 重なる 2 本目の列を足す代わりに、既存列の意味を 1 つに締める
- 設計を不変条件 1 本に落とし、case ごとの挙動をそこから導出する
- 「既存データは消せない」を前提ではなく問いとして扱う。破壊的 migration の実行は人間判断で、dry-run / 影響範囲 / 戻し方が要る
- 却下した形と理由を記録する
