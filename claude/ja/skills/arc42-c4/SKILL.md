---
name: arc42-c4
description: arc42 (§1-12) と C4 model (L1-L4) を組み合わせた architecture 設計ドキュメントの reference。どの diagram をどの section に置くか、top-level と subsystem の分割を扱う。手順 skill ではない。
when_to_use: arc42 / C4 で設計ドキュメントを書く / review する時。ADR / runbook / README との境界に迷った時。
---

# arc42-c4

arc42 (section 体系) と C4 (diagram 体系) は独立した規約であり、どちらの spec も「どの C4 diagram をどの arc42 section に置くか」を定めていない。**本 skill がその mapping を house standard として固定する** — doc ごとの揺れを排除するため。project 固有の doc map は project の top-level 設計ドキュメント側に置き、本 skill には書かない。

arc42 + C4 の設計ドキュメントを書く / review する場面、および ADR / runbook / README の境界を決める場面で参照する。`tech-docs-writer` には section 判断を、`api-design-review` には review 観点を供給する。

## arc42 §1-12

1 Introduction & Goals · 2 Constraints · 3 Context & Scope · 4 Solution Strategy · 5 Building Block View · 6 Runtime View · 7 Deployment View · 8 Crosscutting Concepts · 9 Architecture Decisions · 10 Quality Requirements · 11 Risks & Tech Debt · 12 Glossary

- **§5 vs §6 vs §7** (対象は同じ block、軸が違う): §5 = 静的構造 (「X は構成要素か」) · §6 = 時間軸の振る舞い (「use case Y で構成要素がどの順に対話するか」、洞察のある scenario のみ) · §7 = 物理配置 (「X はどの node で動くか」)。
- **§2 vs §4 vs §10** (同じ事実が 3 つ全てに現れ得る): §2 = 選べなかった制約 · §4 = 自ら下した根本的な選択 · §10 = 計測可能な品質 scenario。PostgreSQL の例: 「方針で必須」→ §2 / 「整合性のために選んだ」→ §4 / 「read が p95 50ms 未満」→ §10。§10 は手段ではなく目的を置く。§9 は ADR 全文ではなく decision の index を置く。

## arc42 × C4 mapping (house standard — 決定事項)

| C4 | arc42 |
|----|-------|
| L1 System Context | **§3** |
| L2 Container | **§5** (top level) |
| L3 Component | **§5** (下位 level / subsystem doc) |
| L4 Code | §5 の最深部、または省略 |
| dynamic diagram | **§6** |
| deployment diagram | **§7** |

番号付きの C4 4 levels は**全て静的**。runtime は §6、配置は §7 へ。**重複排除**: container の構造は §5、container と infra の対応は §7 — 相互参照で繋ぎ、同じものを 2 度貼らない。

## 複数 doc への分割 (top-level ⇄ subsystem)

折り目 = container 境界。**top-level doc** が L1 + L2 を持つ (subsystem の地図 / 引き継ぎの継ぎ目)。**subsystem doc** (container 1 つに 1 本) が L3 (+ 使うなら L4) を持つ。Container diagram が接合点: top-level が全 container を列挙し、各 subsystem doc は自分の container を指してから component へ展開する。subsystem doc は arc42 の **mini** subset でよい (§1-12 全部は top-level のみ)。

## 隣接規約との境界

arc42 = 設計時点の「構造 + 根拠」を長期保持するもの。読者層 / 更新頻度が違うものは別 doc に切り、arc42 からは **link のみ**張る。

| 規約 | 配置 | arc42 側の接点 |
|-----------|----------|------------------|
| MADR (ADR) | `docs/adr/NNNN-*.md` | **§9 は index のみ** (id / title / status / link)。根拠・代替案・帰結の全文は file 側 |
| Diataxis (README / guides) | `docs/readme/` | §8 から link |
| SRE Playbook (runbook) | `docs/runbook/` | §7 / §11 から link |

ADR を切る基準は、覆すのに costly な決定・意見が割れた決定・将来を縛る決定。

## よくある間違い

§5 に flow を書く / §7 に §5 の diagram を貼り直す · C4 の level を「runtime」扱いする (4 つとも静的) · 自由に選べた技術を §2 に入れる · §10 に計測可能な目的ではなく手段を書く · §9 に ADR 本文を書く · subsystem doc に L1 / L2 を重複させる · C4↔arc42 の mapping を「単なる慣習」として再議論する (上で固定済み)。

## 関連 skill

`tech-docs-writer` (doc を書く) · `api-design-review` (doc を review する) · `ddd-clean-architecture` (§5 / §8 の layer 境界)。
