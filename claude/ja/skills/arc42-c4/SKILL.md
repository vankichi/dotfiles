---
name: arc42-c4
description: Deprecated — 廃止済み。arc42 は house 規約から外した。C4 の規約は `diataxis-docs` の references/c4.md が SoT。
when_to_use: 使わない。architecture 図を書く / review する時は `diataxis-docs` を invoke する。
---

# arc42-c4 (廃止)

**本 skill は廃止した。C4 の house 規約は `diataxis-docs/references/c4.md` が SoT。**

## なぜ arc42 を外したか

arc42 の §1-12 は 1 doc の中に need の異なる material を同居させる template (§7 Deployment = 運用の work、§12 Glossary = lookup の reference、§4 Solution Strategy = 理解の explanation)。doc を読者の need で分ける Diátaxis の中核と衝突するため、house 規約から外した。

C4 は doc template を規定せず abstraction level と図の作法だけを与えるため Diátaxis と直交する。C4 は残し、`diataxis-docs` の `docs/architecture/` を C4 の level で構造化する。

arc42 §1-12 ↔ C4 mapping と section 判断の旧規約は git 履歴を参照する。
