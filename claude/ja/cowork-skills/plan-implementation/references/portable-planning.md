# 汎用版 実装計画観点 (repo に層規約 file が無い場合の fallback)

repo 側に `.claude/rules/layering.md` / `.claude/rules/review-checklist.md` が無いときだけ使う。使用時は「repo 固有の層規約なしで実施」と出力に明示する。

## 実装配置

- 依存方向を先に確定する (どの層がどの層を import するか)。方向が読めない場合は既存 file の import を 3 つ grep して推定し、推定であることを明示する
- 新規 symbol は**既存の同種 file の隣**に置く。新しい階層・新しい package を作る前に、既存の置き場所で足りない理由を書く
- 差し替え seam は必要になった時点で consumer 側に最小 interface で作る。使用箇所が 1 つの interface を先回りで作らない

## 依存順

- 参照される側を先に実装する (葉 → 利用側)
- 循環したら PR の切り方を変える (共有部分を先に独立させる)

## PR 分割

- 1 PR = 1 責務。行数の目安を超えたら切る (目安が repo に無ければ 800 行を暫定値として明示)
- 切り口: 層 / 責務 / 段階 (foundation → wiring) / file 種別
- 対応する doc の更新は同 PR に同居させる。同 PR で直せない乖離は issue に切って PR から link する
- 未参照の新規 file だけの PR (foundation only) は許容。stack 順序は依存の逆順にしない

## 着手手順の粒度

- 触る file を path で列挙する。1 file 1 行
- test を先に書く順序で並べる (失敗する test → 実装 → green)
- ハマりどころ: 過去に踏んだ制約 / vendor 固有の癖 / 生成物の再生成が要る箇所
- 手元確認コマンドは **repo の task 定義 file に実在するものだけ**。無い場合は「確認手段なし」と書く (作れとは書かない)
