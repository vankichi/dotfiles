> **Source of truth:** `claude/ja/skills/self-review-changes/references/observability.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# observability — operational observability

Skippable: no new code path (docs / config / test-only change).

- **Presence of logs**: whether new error paths / branches have logs that let operators identify "what happened" at runtime (verbose logs on the happy path are flagged, conversely)
- **Actionability of error messages**: whether the message alone conveys "for which input / where / what to look at next." Whether context (id / key / count) is wrapped in
- **PII / secret leakage**: whether logs / error messages / metric labels contain PII / tokens / connection strings / a full transcription of a ticket body (**critical**)
- **metric / trace**: when adding a resident process / scheduled execution / external call, whether success / failure / duration is observable (only if the repo has a metrics foundation; if not, don't flag but note it)
