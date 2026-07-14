---
name: work-intake
description: Entry-point skill for the dev loop that picks up a ready ticket from Notion, validates it against the spec contract (rules/spec-contract.md), and returns a normalized work item. Use for "次の work 拾って" ("grab the next work item"), "ready ticket ある?" ("any ready tickets?"), "work-intake", etc. Tickets that fail the contract are skipped with a reason comment. The watched DB is resolved from a memory reference.
---

> **Source of truth:** `claude/ja/skills/work-intake/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# work-intake

The entry point of the dev loop. Picks a single ready ticket and normalizes it into a work item that dev-cycle can implement autonomously.
**Does not fix or fill in ticket content** (that's for humans + write-spec to handle).

## Procedure

### Step 1: Resolve configuration (no hardcoding)

- Get the watched Notion DB / ready flag / "in progress" status representation from the reference memory in `MEMORY.md`
- The memory reference must be registered **per project** (different repos may watch different DBs)
- If not found, explicitly state "memory reference not registered" and stop; then get the DB info from the user, register the reference in that project's memory, and continue
- Option: if a ticket URL is passed as an argument, skip the enumeration in Step 2 and target only that ticket. **If the URL-specified ticket is already "in progress", treat it as a resume: perform only contract validation and work item output** (skip the status transition and skip-comment)

### Step 2: Enumerate ready tickets

- Enumerate tickets in the ready state following the procedure in `references/notion-adapter.md`
- If there are 0, explicitly state "none found" and exit normally

### Step 3: Contract validation (output judgment for every item)

- Apply the validation checklist from `~/.claude/rules/spec-contract.md` to each ticket
- **Always output the judgment (satisfied / not satisfied + reason) for every item** (no silent skipping)
- For tickets that don't satisfy it: skip and post a comment on the ticket with the reason for the deficiency (do not edit the body)

### Step 4: Selection and state transition

- Select **exactly one** ticket from the contract-satisfying ones, in priority order (oldest first for equal priority)
- If the user gave an explicit instruction at invocation time (e.g., "youngest ID first"), it takes precedence over the priority rule; flag the deviation from the rule in one line
- Update the selected ticket's status to the "in progress" equivalent (to prevent double-pickup. State lives on the source side; this skill holds no state of its own)

### Step 5: Work item output

```
## work item
- source: notion
- id: <ticket id>
- url: <ticket URL>
- target repo: <from spec meta>
- priority: <from spec meta>
- remaining ready count: <N> (for reference)

### spec
<all sections: purpose / scope & non-goals / design body / DoD / constraints / meta>
```

## On failure

- Notion MCP unreachable / auth expired: do not retry; explicitly state "cannot reach Notion" and exit abnormally (notification is the caller's responsibility)

## Iron rules

1. Do not fix or fill in ticket content (non-goal)
2. Contract validation must output a judgment for every item (no silent skipping)
3. Writes are status updates + comment additions only (never edit the ticket body)
4. Never transcribe the full ticket body into logs / insights (reference by id / URL only)
5. Do not hardcode DB information into the skill (the memory reference is the source of truth)
