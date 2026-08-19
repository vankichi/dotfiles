# architecture (= Diátaxis explanation, understanding-oriented)

読者は**作業から離れて**理解しようとしている。答えるのは「なぜ」「どういうことか」。手順も網羅仕様も置かない。

C4 図を描く時は `c4.md` を Read。本 file は explanation としての書き方・ADR・概念解説を扱う。

## 原則

| 原則 | 具体 |
|---|---|
| about として書く | title に「〜について」を前置できる形にする。話題の周りを回る |
| 繋ぐ | 他の doc / 他の system / 歴史との関係を書く。理解は連結から生まれる |
| trade-off を書く | 採らなかった案とその理由。制約。将来の縛り |
| 意見を許す | 「〜の方が良い、なぜなら」は explanation では許容される (reference では不可) |
| 境界を切る | 話題が無限に広がるので、扱う範囲を冒頭で宣言する |
| 手順と仕様を入れない | 手順は how-to、網羅仕様は reference へ link |

## template: 概念解説 (`docs/architecture/<topic>.md`)

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

IDP では次が典型: 支援境界 (platform の責任範囲) / SLO と保証水準 / paved road の思想 / マルチテナンシーと権限モデル / コスト配賦。

## template: ADR (MADR v3, `docs/architecture/adr/NNNN-<slug>.md`)

**ADR は決定時点の immutable record**。後から書き換えない。方針が変わったら新 ADR を起こし、旧 ADR の Status を `Superseded by ADR-NNNN` にする (この 1 行だけは追記可)。

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

連番は既存の最大値 +1。ADR を切る基準は「覆すのに高くつく」「意見が割れた」「将来を縛る」決定。

## checklist

- [ ] 冒頭に扱う範囲の宣言がある
- [ ] 手順 (番号付きの実行手順 / コマンド列) が入っていない
- [ ] 網羅的な仕様表が入っていない (reference へ link)
- [ ] 採らなかった案とその理由がある
- [ ] 決定事項と未決事項が区別されている (未決は `TBD`)
- [ ] ADR: Status / Date / Deciders / Consequences / Confirmation が埋まっている
- [ ] ADR: 過去の ADR を書き換えていない (supersede で積んでいる)
- [ ] 図がある場合は `c4.md` の checklist を通過

## よくある失敗

| 失敗 | なぜ悪いか |
|---|---|
| 全 option を表で網羅する | reference の混入。architecture が読み物でなくなる |
| 手順を書き始める | how-to の混入。読者は作業していない |
| 既存 ADR を現状に合わせて書き換える | 決定の履歴が消え、なぜ今の形かを辿れなくなる |
| 範囲を宣言せず書き始める | 際限なく広がり、書き終わらない |
| C4 図を貼っただけで why が無い | 図は reference 的。explanation は繋ぎと理由を要求する |
