> **Source of truth:** `claude/ja/skills/self-review-changes/references/test-adversarial.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# test-adversarial — surfacing trivial passes

Skippable: the test file diff is 0.

For each test's assertions, ask: "**is there a mutation that inverts the implementation's behavior but still passes?**" Pay special attention when the input contains repeated content / identical values / nil / empty, and look for paths where assertions like `strings.Contains` / `len(got) > 0` / `errors.Is(...)` trivially pass.

Example: PR #30 C7 — checking carry-over overlap with `strings.Contains` against 80 repeats of the same sentence → trivially true even if carry-over is broken. The correct form is to insert a distinct marker (`[文NNN]`) and verify the boundary with `HasPrefix`.

Also confirm that slice operations in tests (`slice[len-N:]`) have a `len >= N` guard and don't panic when the input is short.
