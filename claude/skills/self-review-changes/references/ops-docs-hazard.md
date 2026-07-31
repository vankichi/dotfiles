> **Source of truth:** `claude/ja/skills/self-review-changes/references/ops-docs-hazard.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# ops-docs-hazard — hazards in operational-procedure docs

Skippable: the docs diff for runbooks / incident response / CLI procedures is 0 (no changes under `docs/runbook/**`, and no shell-command code fence in the added docs lines).

**How to read**: read not for "is this correct as prose" but for "**would an operator who executes this procedure literally take a wrong / destructive action**". Because the code-lens perspectives (correctness / test-adversarial etc.) are skipped when the code diff is 0, this perspective is the only breakwater for docs-only changes.

- **Impact scope stated explicitly**: whether the prose lets the reader tell, for each command listed, whether it is **single-target / all-records / irreversible** (e.g., a command that operates on all records placed in the context of a "procedure that processes only one record"). A command whose scope is not stated explicitly is treated as **critical**
- **Handling of destructive commands**: whether irreversible commands (discard-all / delete / force-overwrite) are explicitly prohibited, or carry a guard (prior confirmation / condition / approval). Whether a path has been created by which the reader arrives at an irreversible command from another section's text in the same file (e.g., "to delete it" offers no means, making a destructive command in another section the only candidate)
- **Sufficiency of preconditions**: whether the procedure's preconditions (required permissions / visibility & time windows / execution order / prior state) can be satisfied within the procedure. If the step that satisfies a precondition exists only in another doc, whether there is a link
- **Presence of dead ends**: whether the alternatives / next steps presented **actually exist** (whether a nonexistent command / an unimplemented feature / an operation you lack permission for is written up as "do this")
- **Effectiveness of prohibitions / warnings**: whether the target of a prohibition / warning points at the knob that actually determines the behavior (prohibiting the setting that does not determine the effective value has no effect and self-contradicts within the same section)
- **Cost of re-billing / side effects**: when re-running the procedure causes re-billing on an external API or duplicate processing, whether that fact and the conditions for avoiding it are written down
- **Counterexample path for quantifiers**: for every universal expression ("the only" / "always" / "necessarily" / "solely" / "unconditionally", etc.), look for one counterexample path. A quantifier not accompanied by an enumeration of the paths that hold is a finding (the quantifier line in `~/.claude/rules/verify-before-assert.md`)
