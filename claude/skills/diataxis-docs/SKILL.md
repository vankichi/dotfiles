---
name: diataxis-docs
description: Creates and audits technical documentation using the four Diátaxis types (tutorial / how-to / reference / architecture=explanation). Primarily targets user-facing docs for a Platform (IDP); ADRs, runbooks, and DB schemas are also placed into the four types. The architecture type is structured with C4.
when_to_use: When writing or fixing a doc, or when unsure where it belongs. 「ドキュメント書いて」「ADR 起票して」「runbook 作って」「onboarding 手順を書いて」「docs を整理して」. Also used to audit existing docs against Diátaxis.
---

> **Source of truth:** `claude/ja/skills/diataxis-docs/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# diataxis-docs

Split technical documentation four ways by **reader need**. Determine the type with the compass (§3), the location from §2, and the writing style from the per-type reference.

## 1. Scope

This skill covers all technical documentation under a repo's `docs/`. ADRs, runbooks, and DB schemas are also placed into one of the four types (do not create per-genre directories).

**arc42 is not adopted / C4 is** — arc42's §1-12 is a template that makes material serving different needs coexist in a single doc (§7 Deployment = the work of operations, §12 Glossary = lookup reference, §4 Solution Strategy = explanation for understanding), which collides head-on with Diátaxis's "don't mix the four types". C4 prescribes no doc template and only supplies abstraction levels and diagram conventions, so it is orthogonal. Do not re-litigate this decision.

Review of the design itself is delegated to `api-design-review` (this skill deals with the shape of docs).

## 2. Placement and naming conventions

```
docs/
  index.md                    # Entry point. Routes to the four types
  tutorial/                   # learning-oriented
  how-to/                     # goal-oriented
    runbook/                  # Incident response / operational scripts
  reference/                  # information-oriented. Excludes API specs
  architecture/               # = explanation (understanding-oriented). Structured with C4
    landscape.md              # System Landscape
    c1-context.md             # System Context
    c2-container.md           # Container
    c3-<container>.md         # Component (only for containers where it adds value)
    dynamic-<feature>.md      # Dynamic (only for complex collaborations)
    deployment-<env>.md       # Deployment (one per environment)
    adr/NNNN-<slug>.md        # Immutable record of a decision
    <topic>.md                # Support boundary / SLO / paved road — the "why" that C4 can't carry
```

If the target repo's CLAUDE.md or existing docs structure defines a different convention, that one wins (global is the default).

| Item | Convention |
|---|---|
| frontmatter | `title` / `description` required. Avoids retrofitting when migrating to Starlight etc. |
| tutorial title | 「はじめての〜」「〜を動かすまで」 |
| how-to title | End with a verb stating the goal (「〜をデプロイする」). 「〜について」「〜の設定」 are not allowed |
| reference title | A noun (「環境変数一覧」「DB スキーマ」) |
| architecture title | A form that can be prefixed with 「〜について」 (「認証方式について」) |
| Diagrams | Mermaid code fence. C4 diagram conventions live in `references/c4.md` |
| API spec | **Do not write the body in docs.** The schema (proto / OpenAPI) is the SoT; `docs/reference/` only links to it |

## 3. Type determination (the compass)

Answer only two questions. **"Is the reader at work or at study right now?" is the sole tie-break.**

| If the content… | …and the reader's need is… | type |
|---|---|---|
| action (doing) | acquisition (learning) | **tutorial** |
| action (doing) | application (working) | **how-to** |
| cognition (knowing) | application (working) | **reference** |
| cognition (knowing) | acquisition (learning) | **architecture** (explanation) |

Do not split by basic vs advanced (basic how-to guides and advanced tutorials both exist).

**Reading across from the old structure**

| Old (genre-based) | type | Location |
|---|---|---|
| README / entry point | index | `docs/index.md` |
| Setup / onboarding | tutorial | `docs/tutorial/<topic>.md` |
| Runbook | how-to | `docs/how-to/runbook/<alert>.md` |
| Operational / work procedures | how-to | `docs/how-to/<goal>.md` |
| API spec (Markdown) | abolished | The schema is the SoT. Link from `docs/reference/` |
| DB schema / env vars / CLI | reference | `docs/reference/<topic>.md` |
| ADR | explanation | `docs/architecture/adr/NNNN-<slug>.md` |
| System design (arc42) | explanation | Broken up into per-C4-level files under `docs/architecture/` |
| Implementation / PoC plans | outside docs | Move to a ticket / Wiki |

**The ADR exception** — an ADR is an immutable record as of the moment of decision; explanation is the present understanding. Do not revise an ADR in place; stack a superseding one. That is why `adr/` is isolated.

## 4. The IDP doc inventory

The minimum set of docs to have for a Platform (IDP). When you find a gap, propose creating it.

| Category | type | Example doc | Reader |
|---|---|---|---|
| Golden path onboarding | tutorial | 「はじめての service デプロイ」 (scaffold → CI passes → traffic works) | Platform user |
| Everyday work | how-to | Add a secret / change scaling settings / pull logs | Platform user |
| Departing from the paved road | how-to | Procedure and request flow for non-standard settings | Platform user |
| Incident triage | how-to (runbook) | Per-alert response procedures | Platform team |
| Entry to self-service | reference | Scaffolder template list / required catalog fields / CLI | Platform user |
| Facts about the environment | reference | Env vars / quotas / DB schema / endpoint list | Platform user |
| The platform's big picture | architecture | landscape / context / container | Both |
| Support boundary | architecture | Where the platform's responsibility ends / SLOs / escalation targets | Both |
| Record of decisions | architecture (adr) | Technology selections and rejected options | Platform team |

## 5. Authoring flow

1. Determine the type per §3. If you can't, fall back to "is the reader at work or at study?"
2. Read the corresponding reference — tutorial → `references/tutorial.md` / how-to → `references/how-to.md` / reference → `references/reference.md` / architecture → `references/architecture.md` (also `references/c4.md` when drawing C4 diagrams)
3. Confirm missing information with `AskUserQuestion`. Do not start writing while things are vague. Mark undecided items explicitly as `TBD`
4. Write it (style rules in §7)
5. Run the contamination self-check in §6 with grep
6. Save under `docs/<type>/`
7. **Register it in `docs/index.md` and in the documentation-structure section of the target repo's CLAUDE.md** (an unregistered doc never gets found)
8. Report the saved path, the chosen type and why, and any remaining TBDs

## 6. Contamination boundaries

Material that crosses types breaks both of them. **Connect with links instead.**

| type | Must not contain | Detection |
|---|---|---|
| tutorial | Explanations of why / presented options / exhaustive option tables | `grep -nE 'なぜ\|理由は\|とは\|または\|お好みで\|オプション' docs/tutorial/*.md` |
| how-to | Detours for learning / conceptual explanation / enumeration of all options | `grep -nE '学び\|理解し\|仕組み\|背景\|なぜ' docs/how-to/**/*.md` |
| reference | Procedures / recommendations / opinions / introductory narrative | `grep -nE 'まず\|次に\|してください\|しましょう\|推奨\|べき' docs/reference/*.md` |
| architecture | Execution procedures / exhaustive spec tables | `grep -nE '^[0-9]+\. \|してください\|\$ ' docs/architecture/*.md` |

grep produces candidates, not verdicts. A single minimal line such as "we use HTTPS here because it's safer" in a tutorial is acceptable (link to architecture for the depth).

## 7. Style rules

- Japanese. Lists, tables, headings, and summary lines use **noun-ending phrasing** (体言止め)
- **Only tutorials use second-person instructions** (「〜します」「〜が表示されます」). Do not use noun-ending phrasing there
- Reference states facts neutrally and definitively. Where prose is required (background in architecture), the plain declarative style (である / する) is fine
- Do not mix noun-ending phrasing and the polite style within the same list
- One item per line, two lines maximum
- **Match the length to the subject matter.** Don't pad with filler sections, duplicated summaries, or boilerplate
- Never write secrets (tokens / connection strings / personal data). If detected, replace with `<REDACTED>` and report

## 8. Audit mode

To diagnose how well existing docs conform to Diátaxis and propose relocations, Read `references/audit.md`. Do not perform a migration that creates four empty sections up front (change the shape from the inside, one improvement at a time).
