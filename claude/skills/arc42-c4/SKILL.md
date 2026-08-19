---
name: arc42-c4
description: Deprecated — retired. arc42 was dropped from the house conventions. The C4 conventions live in `diataxis-docs`'s references/c4.md, which is their SoT.
when_to_use: Do not use. Invoke `diataxis-docs` when writing or reviewing architecture diagrams.
---

> **Source of truth:** `claude/ja/skills/arc42-c4/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# arc42-c4 (retired)

**This skill has been retired. The house conventions for C4 live in `diataxis-docs/references/c4.md`, which is their SoT.**

## Why arc42 was dropped

arc42's §1-12 is a template that makes material serving different needs coexist in a single doc (§7 Deployment = the work of operations, §12 Glossary = lookup reference, §4 Solution Strategy = explanation for understanding). That collides with the core of Diátaxis — splitting docs by reader need — so it was dropped from the house conventions.

C4 prescribes no doc template and only supplies abstraction levels and diagram conventions, so it is orthogonal to Diátaxis. C4 is kept, and `diataxis-docs` structures `docs/architecture/` by C4 level.

See the git history for the old arc42 §1-12 ↔ C4 mapping and the section-judgment conventions.
