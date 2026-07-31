> **Source of truth:** `claude/ja/skills/self-review-changes/references/performance.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# performance — static inspection of complexity / I/O patterns

Skippable: code diff is 0. Don't take a profile; flag suspicious spots statically (see `~/.claude/rules/performance.md` for detailed criteria).

- **Complexity**: whether an added loop nest becomes O(n²) or worse against the input size / whether an existing O(n) path is degraded to O(n²)
- **I/O patterns**: sequential I/O inside a loop (N+1 query / API call one at a time / file open) — can it be batched or pre-fetched?
- **Hot path allocation**: unnecessary allocation on frequently called paths (slice/map creation inside a loop, string concatenation, `fmt.Sprintf`) / consider `strings.Builder` or pre-specifying capacity
- **Unnecessary synchronization**: too-coarse lock scope / unnecessary channel synchronization waits / serial execution of independent work that could be parallelized
- **Detecting degradation**: if a change alters existing performance characteristics (assumptions about volume / frequency), cross-check against the spec's constraints section (if there's no target, flag only)
