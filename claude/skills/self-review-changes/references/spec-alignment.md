> **Source of truth:** `claude/ja/skills/self-review-changes/references/spec-alignment.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# spec-alignment — spec/DoD alignment + scope creep detection

Skippable: no corresponding spec / work item exists (e.g. minor directive-driven work).

## DoD alignment + scope creep (the main event when there is a work item)

1. **Reverse mapping**: map every change in the diff (per file) back to which section / DoD item of the spec it corresponds to
2. **Detecting unmet DoD**: whether each DoD item has a corresponding change + verification means. Enumerate unmet items
3. **Detecting scope creep**: a change that maps to no section = an out-of-scope change. Flag changes that touch non-goals as **critical** (in loop-mode, not auto-fixed but subject to escalation)

## spec literal alignment (when editing the spec doc itself)

When working with a spec (`docs/adr/*.md`, `docs/design/*.md`, OpenAPI, Proto):

1. Grep to enumerate the literals in the spec (type names / enums / fields / file names)
2. Grep to enumerate the same surface on the implementation side
3. Write out the **deviations** explicitly, and for each deviation present a "reason" and a remediation approach ((a) align with the spec / (b) update the spec / (c) separate ADR)

Don't use "it's fine, it's a prototype" as an implicit justification. Use the three-point set of explicit statement, approval, and record (CLAUDE.md's "conduct for changes").
