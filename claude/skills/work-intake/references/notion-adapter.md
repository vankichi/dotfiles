> **Source of truth:** `claude/ja/skills/work-intake/references/notion-adapter.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# Notion adapter (operational procedure for work-intake Step 2-4)

If a new source needs to be added in the future, create a `references/<source>-adapter.md` file alongside this one (SKILL.md should not need to change).

## Enumerating ready tickets (Step 2)

1. Use the DB info from the memory reference (DB name / URL / ready flag representation)
2. Use a Notion MCP search-type tool to fetch tickets from the target DB and filter down to ones matching the ready flag
   - Candidate tools: `notion-search` (search specifying the target DB) / `notion-query-database-view` / `notion-fetch` (fetch individually)
3. For each candidate, fetch the page body with `notion-fetch` and read the spec sections (purpose / scope & non-goals / design body / DoD / constraints / meta)

## Status update (Step 4)

- Change the status property to the "in progress" value from the memory reference using `notion-update-page`
- Immediately before changing it, re-confirm that the current value is still ready (a stand-in for optimistic locking. If it isn't, assume another process picked it up and move to the next candidate)

## Skip comment (Step 3)

- Post the reason for the deficiency using `notion-create-comment`. Format:

```
work-intake: skipped due to unmet spec contract
- <list only the deficient checklist items (item name + reason)>
Reference: rules/spec-contract.md
```

- **Re-comment suppression (idempotency)**: before posting, check existing comments with `notion-get-comments`; if a work-intake skip comment already exists and the spec body has not been updated since, do not comment again (only report the skip verdict). This prevents comments from piling up on every poll once this runs in a loop.
  - Determining "not updated since": compare the posted time of the latest work-intake skip comment (identified by its fixed leading prefix) with the page's `last_edited_time`; re-commenting is allowed only when the latter is newer. Since `last_edited_time` also moves on property changes, false positives fall on the re-comment side (conservative, acceptable)

## escalation comment (used from dev-cycle's escalation procedure Step 3)

- Post via `notion-create-comment`. Format:

```
dev-cycle: escalation stop (<stage>)
- reason: <stop reason, 1-2 lines>
- WIP branch: <branch name / none>
- state file: <path>
- resume: passing this ticket URL to work-intake resumes it in resume mode
```

- Do not change the status (leave it InProgress = keep it as a resume target)
- Do not transcribe secrets / the spec body

## Notes

- Do not edit the ticket body (changing the body via `notion-update-page`). Only the status property and comments may be touched
- Tickets with no priority property set are treated as lowest priority
- Contract validation is applied to **all** enumerated ready tickets (so that no deficient ticket is missed for a skip comment). Selection is the one with the highest priority among the tickets that satisfy the contract
