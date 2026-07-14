# dependency — 依存 / supply chain

skip 可: 依存ファイル (go.mod / go.sum / package.json / lock 系 / import 行) の diff が 0。

- **新規依存の検出**: go.mod / package.json / import 行の追加を列挙。**新規依存は user 承認必須** (CLAUDE.md「行動原則」)。loop-mode では検出 = 即 escalation (自動で追加して進まない)
- **version 更新**: 既存依存の version 変更は意図的か (指示外の lock file 変動は flag)
- **supply chain**: 新規依存の名前が typosquat でないか (公式 org / 高頻度利用の実績を確認)、install script を持つ package でないか
- **間接依存の膨張**: 1 つの新規依存が大量の間接依存を引き込んでいないか (`go mod graph` / lock diff の規模)
- **licence**: 新規依存の licence が repo の方針と矛盾しないか (不明なら flag)
