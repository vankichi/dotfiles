# code-quality — 可読性 / 簡素化 / 規約準拠

skip 可: code diff が 0。bug 検出ではなく「より良い書き方」の観点 (`/simplify` 相当を loop 内で担う)。

- **重複 / reuse**: 追加した logic と同等の helper / util が repo 内に既存でないか grep。同型の処理を 2 箇所以上に書いていないか
- **簡素化**: 不要な中間変数 / 深い nest (early return で平坦化) / 過剰な抽象化 (1 実装しかない interface 等)
- **命名**: 挙動と名前の一致 / repo の既存語彙との一貫性 (`go-style` 参照)
- **altitude**: 関数内の抽象度が揃っているか (低レベル操作と高レベル判断の混在は分離)
- **規約準拠**: Go は `go-style` / `go-test`、層構造は `ddd-clean-architecture` の各 reference skill の基準に照らす (詳細はそちらが SoT)
- **コメント**: 「何をするか」の自明コメント / PR 向け説明コメントは削除対象。書くべきは「code に書けない制約」のみ
