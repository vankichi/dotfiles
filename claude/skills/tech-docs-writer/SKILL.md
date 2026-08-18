---
name: tech-docs-writer
description: Deprecated — retired. Use the `diataxis-docs` skill to author technical documentation. This file keeps only the migration map from the old structure.
when_to_use: Do not use. Invoke `diataxis-docs` when writing or fixing a doc.
---

> **Source of truth:** `claude/ja/skills/tech-docs-writer/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# tech-docs-writer (retired)

**This skill has been retired. Use `diataxis-docs`.**

The structure that bundled docs by genre (ADR / API spec / README / Runbook / system design document) was dropped in favour of splitting by the four Diátaxis types (reader need). The reasoning is in `diataxis-docs/SKILL.md` §1.

## Migration map

| Old (this skill) | New (`diataxis-docs`) |
|---|---|
| README / entry point | `docs/index.md` |
| Setup / onboarding | tutorial → `docs/tutorial/<topic>.md` |
| Runbook | how-to → `docs/how-to/runbook/<alert>.md` |
| Operational / work procedures | how-to → `docs/how-to/<goal>.md` |
| API spec (Markdown) | Abolished. The schema (proto / OpenAPI) is the SoT; link from `docs/reference/` |
| DB schema / env vars / CLI | reference → `docs/reference/<topic>.md` |
| ADR (MADR v3) | explanation → `docs/architecture/adr/NNNN-<slug>.md` |
| System design document (arc42 + C4) | explanation → per-C4-level files under `docs/architecture/` (arc42's section system is discarded) |

The old template bodies (`references/{adr,api,readme,runbook,system-design}.md`) were deleted. Their content now lives per type under `diataxis-docs/references/`. See the git history for the previous versions.
