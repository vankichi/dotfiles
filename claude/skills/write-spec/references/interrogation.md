> **Source of truth:** `claude/ja/skills/write-spec/references/interrogation.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# Interrogation perspective checklist (write-spec Step 3)

Whenever a perspective's trigger condition is met, confirm the corresponding question one at a time via AskUserQuestion.
Include the implementation status of every perspective (done / skipped + reason) in the Step 5 validation output (no silent skipping).

## Always on (applied to every spec)

### 1. Concreteness of the purpose

- "The day after this change ships, what will be visibly different, to count as success?"
- If the purpose is phrased as a means (e.g., "introduce X"), ask about the value beyond that

### 2. Scope boundaries

- Enumerate the peripheral elements that appear in the design body and confirm "will Y be touched this time, or not?"
- If non-goals is empty, draw out at least one "thing we'll probably want to do but are holding off on this time"

### 3. Machine-verifiability of the DoD

- Tie each DoD item to "which command / procedure will verify this?"
- Turn "X works correctly" into something concrete: "given what input, what output counts as correct?"

### 4. Explicitness of constraints

- Is adding a new dependency allowed (and under what conditions if so)?
- Is there a performance target / acceptable degradation (if none, have them state "none" explicitly)?
- Does it handle secrets / PII?

## Conditional (triggered by the content of the design body)

### 5. External interfaces

- Trigger condition: includes a new or changed API / RPC / event schema / enum / public interface
- → Delegate to api-design-review in SKILL.md Step 4 (do not duplicate the interrogation here)

### 6. Data / state

- Trigger condition: includes persistence / migration / data model changes
- Backward compatibility: what happens to existing data? What's the rollback procedure?

### 7. Failure-mode behavior

- Trigger condition: includes calls to external services / asynchronous processing
- On failure, does it retry or give up, and who sees the failure, and how?

### 8. Operations

- Trigger condition: includes a long-running process / scheduled execution / new service
- How is "it's running" observed (logs / metrics / alerts)?
