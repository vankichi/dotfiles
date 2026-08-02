---
name: tech-docs-writer
description: Creates internal technical documentation (ADR / Design Doc / API spec / README / Runbook / system design document) as Japanese Markdown and saves it under docs/{adr,api,readme,runbook,design}/. Always use for 「設計ドキュメント書いて」「ADR 起こして」「API 仕様書」「Runbook 作成」「アーキテクチャ設計」 and similar requests.
when_to_use: When writing an ADR / Design Doc / API spec / README / Runbook. 「ドキュメント書いて」「ADR 起票して」「runbook 作って」.
---

> **Source of truth:** `claude/ja/skills/tech-docs-writer/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# Technical Documentation Writing Skill

Creates internal technical documentation for developers as Japanese Markdown.
Produces the appropriate template according to the de facto standard for each of the 5 document types.

| Type | Standard | Save Location |
|------|---------|--------|
| ADR / Design Doc (single decision) | MADR v3 | `docs/adr/NNNN-<slug>.md` |
| API spec | OpenAPI 3.1 concepts | `docs/api/<resource>.md` |
| README / Guide | Diataxis | `docs/readme/<topic>.md` or root `README.md` |
| Runbook | Google SRE Playbook | `docs/runbook/<alert-or-topic>.md` |
| System design document | arc42 + C4 + MADR | `docs/design/<system-name>.md` |

## 1. Invocation and type determination

Determine the type from the user's utterance or context. When ambiguous, always confirm before creating anything (never guess and create).

| Input Signal | Type |
|------------|------|
| 「決定記録」「ADR」「なぜこの技術選定」「トレードオフ」 (single decision) | ADR / Design Doc |
| 「API仕様」「エンドポイント」「OpenAPI」「REST/gRPC」「リクエスト/レスポンス」 | API spec |
| 「README」「セットアップ」「使い方」「クイックスタート」 | README / Guide |
| 「Runbook」「Playbook」「障害対応」「オンコール」「アラート対応」 | Runbook |
| 「システム設計書」「アーキテクチャ設計」「arc42」「全体設計」「システム全体の設計」 | System design document |

### Distinguishing ADR from a system design document

| Target | Applicable Type |
|------|---------|
| A single decision (「Xを採用する/しない」) | ADR |
| A design that gives an overview of the entire system/subsystem (purpose / components / dynamic behavior / NFR / deployment) | System design document |

When in doubt, decide based on whether the focus is on 「決定事項」 (a decided matter) or 「全体像」 (the big picture).

## 2. Required interview items

Never start writing while the spec is ambiguous. Confirm missing information with `AskUserQuestion`.

Common: title / assumed background of the target audience / related PRs and issues / existence of the save directory

Per-type confirmation items are documented in the corresponding reference file:

- ADR / Design Doc → `references/adr.md`
- API spec → `references/api.md`
- README / Guide → `references/readme.md`
- Runbook → `references/runbook.md`
- System design document → `references/system-design.md`

Once the type is decided, Read the corresponding reference file. Each reference contains the template body and writing tips.

## 3. Extracting information by input source

When in 「コード/差分から自動生成」 (auto-generate from code/diff) mode, use the following.

### Git diff / PR
```bash
git log --oneline -20
git diff <base>..<head>
gh pr view <number> --json title,body,commits,files
```
Trace the rationale behind decisions at the commit granularity, and reflect it in the ADR's Context and Considered Options.

### Go code (godoc / comments)
- Treat package comments and doc comments on exported symbols as the primary source of information
- Interface definitions → extraction of API contracts / design boundaries
- `//go:generate` directives are hints indicating implementation intent

### Kubernetes manifests / Helm
- `Deployment`/`StatefulSet` resource requirements and probe settings → preconditions for the Runbook
- Public parameters in `values.yaml` → configuration guide for the README
- Alert rules (`PrometheusRule`) → starting point for the Runbook's Symptom section

## 4. Document creation flow

1. Determine the type (§1) and gather the required items (§2)
2. Read the corresponding `references/<type>.md`
3. If a code source is specified, extract information per §3
4. Draft in Japanese following the template
5. **For ADR / Design Doc / system design documents, always invoke the `api-design-review` skill once the draft is complete** and check coverage across the 6 perspectives (client abstraction / both sides of the ACL / forward-compat / edge cases / SoT consistency / memory conventions). Reflect any detected gaps in the draft before saving. For API spec / README / Runbook, it is sufficient to pass the same 6 perspectives at a lightweight level (invoking the skill is optional)
6. Save the file: write it out to `docs/<type>/<filename>.md`
   - ADRs use sequential numbers `0001-`, `0002-` … (existing max number + 1)
   - System design documents go to `docs/design/<system-name>.md`
   - Create the directory if it does not exist yet
7. Actively use Mermaid wherever a diagram would help (sequence diagrams / flowcharts / C4)

## 5. Style rules

- For list items, table cells, and summary lines, prefer noun-ending phrasing (体言止め — ending on a noun rather than closing with a verb)
  - Bad example: 「P99レイテンシが100ms以下であること」「監視ダッシュボードを確認する」
  - Good example: 「P99レイテンシ100ms以下」「監視ダッシュボードの確認」
- Where prose is required (Context / background / commentary), the plain declarative style (である/する form) is fine
- Do not mix noun-ending phrasing and plain declarative style within the same bullet list
- Keep bullet points short (in principle, 1 item per line, 2 lines maximum)
- **Match the length to the subject matter**: stop once the substance is covered. Don't pad with filler sections, duplicated summaries, or boilerplate

## 6. Quality checklist (self-review after writing)

- [ ] The title conveys the gist at a glance (avoid vague titles like "新機能の対応" / "handling the new feature")
- [ ] The reader (an internal developer) can reach the conclusion without prior background knowledge
- [ ] Lists and tables consistently use noun-ending phrasing (§5 Style rules)
- [ ] Speculation or unconfirmed matters are not written as if they were 「決定事項」 (already decided) — mark unclear points explicitly as `TBD`
- [ ] No sensitive information (personal data / credentials / secret values other than internal URLs) has been accidentally pasted in
- [ ] Even outside ADRs, what has been decided and what has not been decided are clearly separated
- [ ] The end of the file has a changelog or related links
- [ ] For ADR / Design Doc / system design documents, the `api-design-review` skill has been passed (§4 step 5), and any detected gaps have been reflected

## 7. Things not to do (project norms)

- Do not start writing while the spec is still ambiguous. Always ask the user for missing information.
- Do not decide things by guesswork. Mark unresolved matters as `TBD`.
- Do not output secret information. If a password / token / personal data is detected, replace that portion with `<REDACTED>`.

## Reporting to the user after output

After creation, report the following concisely:
- The saved file path (`computer://` link)
- The chosen type and its rationale
- The list of remaining `TBD` items (if any)
