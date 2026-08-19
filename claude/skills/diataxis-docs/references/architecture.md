# architecture (= Diátaxis explanation, understanding-oriented)

The reader is **away from the work**, trying to understand. What you answer is "why" and "what this really is". No procedures, no exhaustive specs.

When drawing C4 diagrams, Read `c4.md`. This file covers writing as explanation, ADRs, and conceptual guides.

## Principles

| Principle | Concretely |
|---|---|
| Write it as "about" | Make the title something you can prefix with 「〜について」. Circle around the topic |
| Make connections | Write the relationships to other docs, other systems, and history. Understanding comes from connecting |
| Write the trade-offs | The options not taken and why. The constraints. What it locks in for the future |
| Allow opinion | 「〜の方が良い、なぜなら」 is acceptable in explanation (not in reference) |
| Bound the topic | The subject expands without limit, so declare the scope you cover at the top |
| No procedures, no specs | Procedures link to how-to, exhaustive specs link to reference |

## template: conceptual guide (`docs/architecture/<topic>.md`)

````markdown
---
title: <トピック>について
description: <トピック>の背景・選択肢・現在の方針
---

# <トピック>について

本 doc が扱う範囲: <境界を 1 文>。手順は [<how-to>](../how-to/<goal>.md)、値の一覧は [<reference>](../reference/<topic>.md)。

## なぜこれが要るか

<解決している問題 / 無かった場合に何が起きるか>

## どういう仕組みか

<機構の説明。図が要る場合は Mermaid。詳細な構造は c1/c2 図へ link>

## どう決めたか

| 案 | 採否 | 理由 |
|---|---|---|
| <案A> | 採用 | <理由> |
| <案B> | 却下 | <理由> |

決定の記録は [ADR-NNNN](adr/NNNN-<slug>.md)。

## 現在の制約と今後

- <制約>
- <将来変わり得る点>
````

Typical ones for an IDP: the support boundary (what the platform is responsible for) / SLOs and the level of guarantee / the philosophy of the paved road / multi-tenancy and the permission model / cost allocation.

## template: ADR (MADR v3, `docs/architecture/adr/NNNN-<slug>.md`)

**An ADR is an immutable record as of the moment of decision.** Never rewrite it later. When the direction changes, raise a new ADR and set the old one's Status to `Superseded by ADR-NNNN` (that single line is the only permitted addition).

````markdown
---
title: "ADR-NNNN: <決定のタイトル>"
description: <何を決めたか 1 行>
---

# ADR-NNNN: <決定のタイトル>

- **Status**: Proposed | Accepted | Deprecated | Superseded by ADR-NNNN
- **Date**: YYYY-MM-DD
- **Deciders**: <決定者>

## Context and Problem Statement

<なぜ決める必要があったか。制約と前提>

## Decision Drivers

- <判断基準> (優先順)

## Considered Options

1. <案A>
2. <案B>

## Decision Outcome

**Chosen option**: "<案X>"

<選んだ理由>

### Consequences

- Good: <得られるもの>
- Bad: <払うコスト / 将来の縛り>

### Confirmation

<決定どおり実装されたことをどう確認するか (test / lint / review 観点)>

## Pros and Cons of the Options

### <案A>

- Good: <利点>
- Bad: <欠点>

## More Information

- 関連 ADR / doc / PR
````

The sequence number is the existing maximum + 1. Cut an ADR when the decision is expensive to reverse, was contested, or constrains the future.

## checklist

- [ ] The opening declares the scope covered
- [ ] No procedures (numbered execution steps / command sequences)
- [ ] No exhaustive spec tables (linked to reference)
- [ ] The options not taken, and why, are present
- [ ] Decided and undecided matters are separated (undecided marked `TBD`)
- [ ] ADR: Status / Date / Deciders / Consequences / Confirmation are filled in
- [ ] ADR: past ADRs were not rewritten (stacked via supersede)
- [ ] If diagrams are present, they pass the `c4.md` checklist

## Common failures

| Failure | Why it's bad |
|---|---|
| Tabulating every option | Reference contamination. Architecture stops being readable |
| Starting to write a procedure | How-to contamination. The reader isn't working |
| Rewriting an existing ADR to match the present | The history of the decision disappears, and you can't trace why things are as they are |
| Writing without declaring the scope | It expands endlessly and never gets finished |
| Pasting a C4 diagram with no "why" | Diagrams are reference-ish. Explanation demands connections and reasons |
