# 反映先の昇格基準 (memory → rules → skill → agent)

improve-harness Step 4 の判定基準。**変更コストの小さい順に検討し、最初に条件を満たした先へ反映する**。
`target` が明記された insight はこの表より優先してそれに従う。

| 反映先 | 条件 (これで足りるなら昇格しない) | 例 | 変更手段 |
|---|---|---|---|
| memory | project 固有の事実・環境の癖で、手順化するほどの一般性がない。次 session が知っていれば十分 | 「repo X は ja が SoT」/ deny された command の代替 recipe | 対象 project の memory に直接 write (PR 不要) |
| rules/ | repo 横断の行動原則・contract の 1-2 行規範。どの skill / agent からも参照され得る | ready flag の SoT 規定 / 検証原則への追記 | dotfiles PR (ja 単一、mirror なし) |
| skill | 特定 skill の手順・checklist・発火条件の gap。再現性を手順として固定したい | work-intake の skip idempotency / retrospect の記録先規定 | dotfiles PR (ja SoT + en mirror) |
| agent | agent 定義の挙動・model routing・tool 制約の規定 | dev-cycle の worktree 自己回復規定 | dotfiles PR (ja SoT + en mirror) |

## 判定の目安

- **一般性**: 1 project 限り → memory。repo 横断 → rules 以上
- **形**: 事実の記憶で足りる → memory。原則 1-2 行 → rules。手順・checklist が要る → skill / agent
- **強制力**: 「知っていれば良い」→ memory / rules。「必ずこの手順で実行」→ skill / agent
- 迷ったら小さい側へ。skill への焼き付けは同種 insight が 2 件以上溜まってからでも遅くない

## アンチパターン

- 1 回きりの事象を skill の恒久手順に焼き付ける (rot の元)
- memory で足りる内容を rules/ に書いて全 session の context を太らせる
- 同じ規範を複数 skill に重複記載する (rules/ に 1 箇所書いて参照させる)
- 昇格判定を理由に proposal を書き換える (内容の再設計は人間の領分)
