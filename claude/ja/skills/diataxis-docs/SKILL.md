---
name: diataxis-docs
description: Diátaxis の 4 type (tutorial / how-to / reference / architecture=explanation) で技術ドキュメントを作成・監査する。Platform (IDP) の利用者向け docs を主対象とし、ADR / runbook / DB schema も 4 type に配置する。architecture は C4 で構造化する。
when_to_use: doc を書く / 直す / 置き場所に迷った時。「ドキュメント書いて」「ADR 起票して」「runbook 作って」「onboarding 手順を書いて」「docs を整理して」。既存 docs の Diátaxis 監査にも使う。
---

# diataxis-docs

技術ドキュメントを **読者の need** で 4 分割する。判定は compass (§3)、置き場所は §2、書き方は type 別 reference。

## 1. 適用範囲

本 skill が扱うのは repo の `docs/` 配下の技術ドキュメント全て。ADR / runbook / DB schema も 4 type のどれかに配置する (種別ごとの dir は作らない)。

**arc42 は採らない / C4 は採る** — arc42 の §1-12 は 1 doc の中に need の異なる material を同居させる template (§7 Deployment=運用の work、§12 Glossary=lookup の reference、§4 Solution Strategy=理解の explanation) であり、Diátaxis の「4 type を混ぜない」と正面から衝突する。C4 は doc template を規定せず abstraction level と図の作法だけを与えるため直交する。この判断は再議論しない。

設計そのものの review は `api-design-review` に委譲する (本 skill は doc の形を扱う)。

## 2. 配置・命名規約

```
docs/
  index.md                    # 入口。4 type への導線
  tutorial/                   # 学習 (learning-oriented)
  how-to/                     # 作業手順 (goal-oriented)
    runbook/                  # 障害対応・運用スクリプト
  reference/                  # 事実 (information-oriented)。API 仕様は除く
  architecture/               # = explanation (understanding-oriented)。C4 で構造化
    landscape.md              # System Landscape
    c1-context.md             # System Context
    c2-container.md           # Container
    c3-<container>.md         # Component (価値がある container のみ)
    dynamic-<feature>.md      # Dynamic (複雑な協調のみ)
    deployment-<env>.md       # Deployment (環境ごとに 1 枚)
    adr/NNNN-<slug>.md        # 決定の immutable record
    <topic>.md                # 支援境界 / SLO / paved road など C4 に載らない why
```

対象 repo の CLAUDE.md や既存 docs 構成に別の規約があればそちらが優先 (global は既定値)。

| 項目 | 規約 |
|---|---|
| frontmatter | `title` / `description` を必須。Starlight 等への移行時に後付けしないため |
| tutorial の title | 「はじめての〜」「〜を動かすまで」 |
| how-to の title | 動詞終止で目的を書く (「〜をデプロイする」)。「〜について」「〜の設定」は不可 |
| reference の title | 名詞 (「環境変数一覧」「DB スキーマ」) |
| architecture の title | 「〜について」を前置できる形 (「認証方式について」) |
| 図 | Mermaid code fence。C4 図の記法は `references/c4.md` |
| API 仕様 | **docs に本文を書かない**。schema (proto / OpenAPI) が SoT で `docs/reference/` からは link のみ |

## 3. type 判定 (compass)

2 問だけ答える。**「読者はいま work か study か」が唯一の tie-break**。

| content が | 読者の need が | type |
|---|---|---|
| action (手を動かす) | acquisition (学ぶ) | **tutorial** |
| action (手を動かす) | application (仕事する) | **how-to** |
| cognition (知る) | application (仕事する) | **reference** |
| cognition (知る) | acquisition (学ぶ) | **architecture** (explanation) |

基本 / 応用の別では分けない (基本的な how-to も高度な tutorial も存在する)。

**旧構成からの読み替え**

| 旧 (種別ベース) | type | 配置 |
|---|---|---|
| README / 入口 | index | `docs/index.md` |
| セットアップ / onboarding | tutorial | `docs/tutorial/<topic>.md` |
| Runbook | how-to | `docs/how-to/runbook/<alert>.md` |
| 運用手順・作業手順 | how-to | `docs/how-to/<goal>.md` |
| API 仕様 (Markdown) | 廃止 | schema が SoT。`docs/reference/` から link |
| DB schema / 環境変数 / CLI | reference | `docs/reference/<topic>.md` |
| ADR | explanation | `docs/architecture/adr/NNNN-<slug>.md` |
| system design (arc42) | explanation | `docs/architecture/` の C4 level 別 file へ解体 |
| 実装計画 / PoC 計画 | docs 外 | ticket / Wiki へ |

**ADR の特例** — ADR は決定時点の immutable record、explanation は現在の理解。ADR は in-place 改訂せず supersede で積む。だから `adr/` に隔離する。

## 4. IDP doc 台帳

Platform (IDP) で最低限そろえる doc。欠けを見つけたら起票を提案する。

| 系統 | type | doc の例 | 読者 |
|---|---|---|---|
| golden path onboarding | tutorial | 「はじめての service デプロイ」(雛形生成 → CI 通過 → 疎通まで) | 利用者 |
| 日常作業 | how-to | secret を追加する / スケール設定を変える / ログを引く | 利用者 |
| paved road からの逸脱 | how-to | 標準外の設定を入れる手順と申請 | 利用者 |
| 障害切り分け | how-to (runbook) | alert 別の対応手順 | platform team |
| self-service の入口 | reference | scaffolder template 一覧 / catalog の必須 field / CLI | 利用者 |
| 環境の事実 | reference | 環境変数 / quota / DB schema / endpoint 一覧 | 利用者 |
| platform の全体像 | architecture | landscape / context / container | 双方 |
| 支援境界 | architecture | どこまでが platform の責任か / SLO / エスカレーション先 | 双方 |
| 設計の記録 | architecture (adr) | 技術選定と却下案 | platform team |

## 5. 起票フロー

1. §3 で type を判定する。判定できない場合は「読者は work か study か」に戻る
2. 該当する reference を Read — tutorial → `references/tutorial.md` / how-to → `references/how-to.md` / reference → `references/reference.md` / architecture → `references/architecture.md` (C4 図を描くなら `references/c4.md` も)
3. 不足情報を `AskUserQuestion` で確認する。曖昧なまま書き始めない。未確定は `TBD` と明記する
4. 執筆する (§7 の文体規約)
5. §6 の混入 self-check を grep で回す
6. `docs/<type>/` に保存する
7. **`docs/index.md` と対象 repo の CLAUDE.md のドキュメント構成 section に登録する** (登録しない doc は発見されない)
8. 保存 path / 選んだ type と理由 / 残 TBD を報告する

## 6. 混入禁止 (boundary)

type を跨ぐ材料が入ると両方が壊れる。**link で繋ぐ**。

| type | 入れてはいけないもの | 検出 |
|---|---|---|
| tutorial | 理由の説明 / 選択肢の提示 / 網羅的な option 表 | `grep -nE 'なぜ\|理由は\|とは\|または\|お好みで\|オプション' docs/tutorial/*.md` |
| how-to | 学習目的の寄り道 / 概念の解説 / 全 option の列挙 | `grep -nE '学び\|理解し\|仕組み\|背景\|なぜ' docs/how-to/**/*.md` |
| reference | 手順 / 推奨 / 意見 / 導入の物語 | `grep -nE 'まず\|次に\|してください\|しましょう\|推奨\|べき' docs/reference/*.md` |
| architecture | 実行手順 / 網羅的な仕様表 | `grep -nE '^[0-9]+\. \|してください\|\$ ' docs/architecture/*.md` |

grep は候補出しであり判定ではない。tutorial の「なぜ HTTPS か」1 行のような最小説明は許容 (深掘りは architecture に link)。

## 7. 文体規約

- 日本語。list / 表 / 見出し・要約行は**体言止め**
- **tutorial のみ二人称の指示文** (「〜します」「〜が表示されます」)。体言止めにしない
- reference は中立記述で言い切る。散文が要る箇所 (architecture の背景説明) は「である / する」
- 同一 list 内で体言止めと敬体を混ぜない
- 1 項目 1 行、最大 2 行
- **分量は主題に合わせる**。filler section / 重複要約 / boilerplate で嵩上げしない
- secret (token / 接続文字列 / 個人情報) を書かない。検出したら `<REDACTED>` に置換して報告

## 8. 監査モード

既存 docs の Diátaxis 適合を診断し、再配置を提案する場合は `references/audit.md` を Read。空の 4 section を先に作る移行は行わない (1 回 1 改善で内側から形を変える)。
