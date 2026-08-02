---
name: write-spec
description: Assistant skill that polishes a human's design draft into a spec that satisfies the spec contract (rules/spec-contract.md). Makes no design decisions itself — only interrogates gaps, formats, and validates against the contract. Use for "spec にして" ("turn this into a spec"), "spec 書くの手伝って" ("help me write a spec"), "設計を spec 化" ("formalize this design into a spec"), etc. Only a human may set the ready flag.
when_to_use: When polishing a human's design draft into something that satisfies the spec contract. 「spec に起こして」「仕様書いて」.
---

> **Source of truth:** `claude/ja/skills/write-spec/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# write-spec

Polishes a design that a human has written and led into a spec that an agent (dev-cycle) can implement autonomously.
**Makes no design decisions. Does not create an implementation plan either.** Only finds gaps, asks about them, and once they're filled in, formats and validates.

## Input

Any of: a design explanation from the conversation / a local file / a Notion page URL.

## Procedure

### Step 1: Read the contract

Read `~/.claude/rules/spec-contract.md` (required sections / validation checklist / meaning of ready).

### Step 2: Map the draft onto the template

Sort the input into required sections 1-6, and present the user with a list of sections that are unfilled or ambiguous.

### Step 3: Interrogation (one question at a time)

Using the perspectives in `references/interrogation.md`, confirm unfilled spots one question at a time via AskUserQuestion.

- Do not fill in answers on your own. When offering choices, limit any "recommended" option to one, with a stated rationale
- Do not keep raising objections to a design the human has confirmed as "good as is" (flag a concern once, then follow their decision)
- When confirming a proposal (a candidate DoD / a candidate constraint, etc.), **restate the proposal's content inside the question itself** (a reference to the preceding message alone may not be visible to the user)
- **Escape hatch for undesigned areas**: if it turns out that an entire section has no design at all — not just a gap to fill — delegate to the `grill-me` skill for deeper exploration, then return to this step with the result. When delegating, constrain the scope via args (e.g., "Limit to failure-mode behavior in contract section 3 (design body)"). Do not let it run open-ended
- Record the status of every perspective (done / skipped + reason) and include it in the Step 5 output

### Step 4: Trigger check for api-design-review (mechanical)

If the design body includes any of the following, invoke the `api-design-review` skill and add any detected gaps to the Step 3 interrogation:

- A new or changed API endpoint, RPC, event schema, enum, or public interface (**applies only to things exposed outside the repo**. Skill-to-skill contracts internal to the harness are out of scope — handle those in the design body of the spec)
- A change to the ACL / permission model

If none apply, skip and note the reason in the Step 5 output.

### Step 5: Formatting and validation

Assemble the spec in markdown, and output the judgment for **every item** of the contract's validation checklist (satisfied / not satisfied + reason). If any unsatisfied items remain, return to Step 3.

### Step 6: Output

- Present the finished spec (markdown that can be pasted into Notion)
- Only write to Notion if the user explicitly instructs it (via MCP)
- **Do not set the ready flag** — end by stating explicitly that "setting it to ready is for the human to do"

## Iron rules

1. Do not make design decisions or implementation plans on the human's behalf (stay strictly in an assisting role)
2. Always output the judgment for every item of the validation checklist and the implementation status of every interrogation perspective (no silent skipping)
3. Interrogate one question at a time (prefer multiple choice)
4. Do not hardcode project-specific information (e.g., the Notion DB); get it from the reference in `MEMORY.md`
5. **Keep the spec body limited to constraints (what / why)**: do not write implementation means (how) into the DoD. When cost/benefit flips during implementation, a spec that prescribed the how turns a correct decision update into a "deviation". If you must show a means, a **"reference proposal (non-binding)" label is mandatory**
6. **Only write identifier literals you have verified against the repo**: when putting type names / file paths / column names into a spec, grep the real repo to confirm they exist. Write unverified literals as "equivalent to ..." and leave them to the implementer's discretion
