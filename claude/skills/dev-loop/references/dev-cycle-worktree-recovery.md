> **Source of truth:** `claude/ja/skills/dev-loop/references/dev-cycle-worktree-recovery.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# dev-cycle worktree recovery procedures (contingency)

A set of branches you never need to read on the normal path (when EnterWorktree succeeds). Consult it only when worktree isolation fails or is rejected during dev-cycle's implementation stage.

## If launched with a cwd inside a worktree (e.g., a parallel-cycle collision)

EnterWorktree cannot create a nested worktree from inside one. Identify the main checkout and create your own worktree off main (or origin/main) with `git worktree add`, then move into it. Never touch files inside another agent's worktree.

## If Edit/Write to the newly created worktree keeps being rejected

Under subagent cwd pinning, `EnterWorktree(path)` may report success while the write boundary does not actually move. Switch to a branch swap inside the pinned original worktree:

1. Clean up the new worktree with `git worktree remove`
2. **Ownership check**: mechanically confirm via reverse lookup that the original worktree is not owned by another active cycle — grep the state files in the per-project plans dir; if an active state file (= one whose Current state does not show all stages completed / terminated by escalation) records this worktree path under `worktree:`, treat it as owned (recent mtime as a secondary signal)
3. If it is owned, do not swap; escalate and stop (the "never touch another agent's worktree" principle)
4. Once confirmed safe, run `git fetch origin <base-ref>` to refresh the remote-tracking ref
5. Continue by swapping only the branch inside the original worktree directory via `git checkout -b <branch> origin/<base-ref>` (the original branch's commits are preserved)

## When cwd is pinned to the main checkout (under a background job's bgIsolation guard)

The branch swap above is not usable — swapping would hijack the user's checkout. The guard also rejects the Write/Edit tools for **every path under the repo root**, so a worktree created under `.claude/worktrees/` is not writable either. In this case create the worktree **outside the repo root**:

1. **Probe what the guard actually blocks**: try a Write to `/tmp` and a write from a Bash subprocess. If both succeed, the guard is a path-scoped Write/Edit tool block rooted at the repo checkout, not a session-wide block
2. `git worktree add <path as a sibling of the repo> origin/<base-ref>` to create the worktree outside the repo root (if one was already created inside, relocate it with `git worktree move`)
3. From then on, Write/Edit via absolute paths. The shared checkout is never touched, so the guard's intent is honored

## If Write/Edit is still rejected

Generate files with a Bash heredoc (`cat > <path> <<'EOF'`) or python, and run git / go etc. via `cd <worktree> && ...`. Do not change settings to disable the guard.
