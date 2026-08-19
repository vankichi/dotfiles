# 監査 (既存 docs の Diátaxis 適合診断)

既存 docs を診断し、再配置と改善を**提案**する。実 file の移動は user 承認後。

**空の 4 section を先に作らない** — Diátaxis の構造は改善の結果として現れるもので、先に枠を作って埋める作業ではない。

## 手順

### 1. 棚卸し

```bash
find docs -name '*.md' | sort
wc -l $(find docs -name '*.md') | sort -n | tail -20   # 巨大 doc = 種別混在の候補
```

全 file を表に落とす。**件数を数えて報告する** (「概ね」「多数」と書かない)。

### 2. type 判定

file ごとに compass を当てる (SKILL.md §3)。判定は中身で行い、置き場所や file 名で決めない。

| 兆候 | 実際の type |
|---|---|
| 手順があり、読者が初学者向けに一本道 | tutorial |
| 手順があり、条件分岐があり、目的が明確 | how-to |
| 表・一覧が主体で手順が無い | reference |
| なぜ / 選択肢 / 経緯が主体 | architecture |
| 上記が 1 file に 2 つ以上ある | **分割候補** |

### 3. 混入検出

```bash
grep -nE 'なぜ|理由は|とは|または|お好みで' docs/tutorial/*.md          # tutorial への説明・選択肢
grep -nE '学び|理解し|仕組み|背景'          docs/how-to/**/*.md         # how-to への教育
grep -nE 'まず|次に|してください|推奨|べき'  docs/reference/*.md         # reference への手順・意見
grep -nE '^[0-9]+\. |してください'          docs/architecture/*.md      # architecture への手順
grep -rn 'TBD\|TODO\|未定'                  docs/                       # 未確定の放置
```

grep は候補出し。1 行の最小説明など許容範囲は判定で落とす。

### 4. C4 図の点検 (architecture)

`c4.md` の checklist を当てる。頻出は level 混在 / label 無しの線 / legend 欠落 / Container 図への deployment 混入。

### 5. 再配置の提案

file ごとに 1 行で出す。

| 現 path | 判定 type | 移行先 | 備考 |
|---|---|---|---|
| `docs/design/foo.md` | explanation + reference 混在 | `docs/architecture/c2-container.md` + `docs/reference/foo.md` | 表 3 つを reference に分離 |

提案には次を必ず添える:

- **link 影響** — `grep -rn '<旧 path>' . --include='*.md' --include='*.go'` の結果件数
- **doc 台帳の更新** — 対象 repo の CLAUDE.md ドキュメント構成 section / `docs/index.md`
- **決定記録の扱い** — 構成変更が既存 ADR の決定を覆す場合、**ADR は書き換えず supersede する新 ADR の起票が必要** (起票自体は human の判断)

### 6. 1 回 1 改善

大改造を提案しない。「いま目の前にある 1 file を 1 段良くする」を繰り返す形に分解する。各改善は単独で link 整合が取れ、単独で commit できること。

## 旧構成からの移行対応表

種別ベースの構成からの読み替え。

| 旧 | 新 |
|---|---|
| `docs/readme/getting-started.md` | `docs/tutorial/<topic>.md` (学習) または `docs/how-to/<goal>.md` (作業) |
| `docs/readme/user-manual.md` | 大半は how-to に分割。仕様表は reference |
| `docs/runbook/*.md` | `docs/how-to/runbook/*.md` |
| `docs/api/*.md` | 廃止。schema を SoT にし `docs/reference/` から link |
| `docs/adr/*.md` | `docs/architecture/adr/*.md` (番号は維持) |
| `docs/design/<top>.md` | C4 level 別に解体 → `c1-context.md` / `c2-container.md` / `dynamic-*.md` / `deployment-<env>.md` |
| `docs/design/subsystems/*.md` | `docs/architecture/c3-<container>.md` |
| `docs/design/crosscutting/*.md` | why は `docs/architecture/<topic>.md`、運用手順は `docs/how-to/` |
| `docs/plan/*.md` | docs 外 (ticket / Wiki) |
| arc42 §12 Glossary 相当 | `docs/reference/glossary.md` |
| arc42 §10 Quality Requirements 相当 | `docs/architecture/<topic>.md` (SLO は支援境界 doc に寄せる) |

## 報告形式

- 棚卸し件数 (実測)
- type 別の内訳と分割候補
- 混入検出のヒット件数と、判定後に残った実問題
- 再配置提案の表
- 次の 1 改善の提案 (1 つだけ)
