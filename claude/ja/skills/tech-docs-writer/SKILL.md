---
name: tech-docs-writer
description: Deprecated — 廃止済み。技術ドキュメントの作成は `diataxis-docs` skill を使う。本 file は旧構成からの移行対応表のみを残す。
when_to_use: 使わない。doc を書く / 直す時は `diataxis-docs` を invoke する。
---

# tech-docs-writer (廃止)

**本 skill は廃止した。`diataxis-docs` を使う。**

doc 種別 (ADR / API 仕様 / README / Runbook / システム設計書) で束ねる構成をやめ、Diátaxis の 4 type (読者の need) で分ける構成に移行した。理由は `diataxis-docs/SKILL.md` §1。

## 移行対応表

| 旧 (本 skill) | 新 (`diataxis-docs`) |
|---|---|
| README / 入口 | `docs/index.md` |
| セットアップ / onboarding | tutorial → `docs/tutorial/<topic>.md` |
| Runbook | how-to → `docs/how-to/runbook/<alert>.md` |
| 運用手順・作業手順 | how-to → `docs/how-to/<goal>.md` |
| API 仕様 (Markdown) | 廃止。schema (proto / OpenAPI) を SoT とし `docs/reference/` から link |
| DB schema / 環境変数 / CLI | reference → `docs/reference/<topic>.md` |
| ADR (MADR v3) | explanation → `docs/architecture/adr/NNNN-<slug>.md` |
| システム設計書 (arc42 + C4) | explanation → `docs/architecture/` の C4 level 別 file (arc42 の section 体系は破棄) |

旧 template 本文 (`references/{adr,api,readme,runbook,system-design}.md`) は削除した。内容は `diataxis-docs/references/` に type 別で収容済み。過去版は git 履歴を参照する。
