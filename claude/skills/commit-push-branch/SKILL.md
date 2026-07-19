---
name: commit-push-branch
description: Cuts a new branch and commits & pushes the working-tree changes with a message that follows past commit style (type prefix / ticket ID / Co-Authored-By). Used for 「branch 切って commit & push して」「PR 用に push」 etc.
---

> **Source of truth:** `claude/ja/skills/commit-push-branch/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# commit-push-branch

A skill that cuts a new branch, creates a commit following past style, and pushes it. PR creation is separate (`gh pr create`).

## Applicability

- Inside a git repository
- The working tree has changes to commit (something shows up in `git status`)
- Remote `origin` is configured

## Procedure

### Step 1: Check status

```bash
git status
git diff --stat
git diff --cached
git log -3 --format='%H%n%B%n---'   # 過去スタイル把握
```

### Step 2: Extract past style

From the `git log -3` output:
- **Conventional type prefixes** (`chore:`, `feat:`, `fix:`, `docs:`, `refactor:`, `test:`)
- **Title language** (English / Japanese)
- **How ticket IDs are placed** (`(PROJ-123)` / `Refs: PROJ-123` / `(#123)` etc., depends on repo convention)
- Whether **multi-line HEREDOC** is used
- Whether a **Co-Authored-By line** is included
- **PR merge style** (squash or merge commit)

### Step 3: Decide the type and branch name

| Change content | type | branch prefix |
|---|---|---|
| New feature | `feat` | `feat/` |
| Bug fix | `fix` | `fix/` |
| Infra / config / build / tooling | `chore` | `chore/` |
| Docs only | `docs` | `docs/` |
| Refactor (no behavior change) | `refactor` | `refactor/` |
| Adding tests | `test` | `test/` |

Branch name patterns:

| Case | Format | Example |
|---|---|---|
| With a ticket | `<prefix>/<ticket-id>-<description-slug>` | `chore/proj-123-add-feature` |
| Without a ticket | `<prefix>/<description-slug>` | `docs/api-error-codes-cleanup` |

Keep the description slug short in kebab-case (3-5 words). Don't identify a branch by ticket ID alone — always attach a slug that describes the content.

If past PRs have a convention of including a ticket ID, attach one; if the convention is ticket-less (mainly seen with `docs/` / `chore/` types), use slug only. **The decision follows the result of Step 2 ("Extract past style")** (this table is just a pattern example and does not override Step 2).

### Step 4: Create the branch

```bash
git checkout -b <prefix>/<ticket-id>-<slug>
```

If it collides with an existing branch, add a suffix like `-N`.

### Step 5: Explicit add

**Don't use** `-A` / `-a`. Explicitly list new / edited files:

```bash
git add <file1> <file2> <dir1>/ <dir2>/
git status   # 確認
```

Confirm no secret patterns like `.env` / `*.pem` / `credentials*` are included.

### Step 6: Commit

**By default, use a single-line title only.** `-m "<title>"` is sufficient. Don't default to HEREDOC + body.

```bash
git commit -m "<type>: <変更内容>"
# または scope 付き
git commit -m "<type>(<scope>): <変更内容>"
```

What goes in the title = **the change content only**. Don't put why / background / impact scope / rot risk / ticket context in either the title or the body (these can be tracked via the PR description / Notion ticket / git history).

Good examples:
- `chore: ブートログから phase フィールドを削除`
- `docs(api): SearchMeta を RequestMeta にリネームし common.proto へ切り出す`
- `chore: translate Makefile comments and error messages to English`

Bad examples (verbose / includes why):
- `chore: ブートログから phase フィールドを削除\n\nphase 値はログに焼き付けると rot するだけで利得がない。`
- `chore: 前 commit で導入した slog.Info の "phase" 引数を削除して rot を回避`

#### Exceptions where body / HEREDOC is used

Only write a body in the following cases:
- **Breaking change** → include a `BREAKING CHANGE: <impact>` line
- There's a **genuinely non-obvious why** that can't be captured in the PR description (rare)
- **Past style consistently requires HEREDOC + body** (based on Step 2's findings)

Template for the exception case:

```bash
git commit -m "$(cat <<'EOF'
<type>: <変更内容>

<最小限の why。1-2 行。>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Notes:
- Use HEREDOC with `'EOF'` (single-quoted) to suppress expansion
- Include `Co-Authored-By:` **only if past commits have it; omit it if they don't**. Even for a short commit, you can add it by passing two `-m` flags like `-m "..." -m "Co-Authored-By: ..."` (depends on repo convention)
- Whether to attach a ticket ID like `(PROJ-123)` also depends on past style. It's fine to omit it if the title would get too long

#### Handling GPG signing hangs

In environments with `commit.gpgsign=true` set, `git commit` can hang waiting for pinentry (an agent environment has no TTY so the pinentry GUI can't launch, or the gpg-agent cache has expired and it's waiting for a passphrase).

Handling steps:

1. **Set the Bash tool's timeout to 30 seconds when running `git commit`** (don't wait the default 2 minutes)
2. **When a hang / timeout is detected**: confirm via `git status` that the staged state is preserved (the commit failed, but files remain staged)
3. Check for a hung process with **`ps aux | grep -E "gpg|git commit" | grep -v grep`**, and ask the user to kill it if needed
4. **Guide the user through a manual commit**:
   - Run `echo test | gpg --clearsign > /dev/null` in a separate terminal → enter the passphrase in pinentry → this warms the cache
   - Or have the user run the following command directly:
     ```bash
     git commit -m "<type>: <変更内容>" -m "Co-Authored-By: <name> <email>"
     ```
5. **After the manual commit completes, once the user signals something like "commit done," the skill proceeds to push** (after confirming via `git log --oneline -1`)
6. Once the cache is warmed, subsequent commits / pushes will also go through on the agent side (the following Step 7 push can also be run by the skill)

Notes:
- The skill must not work around this on its own with `--no-gpg-sign` or `commit.gpgsign=false` (same spirit as Iron Rule #2, "no `--no-verify`" — safety skips only happen when the user explicitly requests them)
- The staged state isn't destroyed even if it hangs, so don't rush to reset

### Step 7: Push

```bash
git push -u origin <branch-name>
```

Direct pushes to main / master trigger a warning (this assumes Step 4 has already guaranteed we're on a working branch).

### Step 8: Completion report

| Item | Value |
|---|---|
| Branch | `<prefix>/<ticket-id>-<slug>` |
| Commit | `<short-sha>` (`<type>: ...`) |
| Files | `<n>` files (+<additions>/-<deletions>) |
| PR creation URL | (extracted from the push output: `https://github.com/<org>/<repo>/pull/new/<branch>`) |

PR creation is a separate task. If the user instructs it, continue with `gh pr create`.

## loop-mode (only when invoked by dev-cycle)

Applies **only when loop-mode is explicitly specified** at invocation time (basis: "loop-mode (exception rules for autonomous execution)" in CLAUDE.md):

- The branch name / commit message in Steps 3-6 are decided automatically from conventions and past style, with no user confirmation
- **WIP squash**: if `wip(<stage>):` commits are stacked on the working branch (dev-cycle's stage-boundary WIP commits), run `git reset --soft $(git merge-base HEAD origin/<default-branch>)` to return all changes to staged, then create the single conventional commit (never use `--hard`). In this case, Step 5's explicit add is reinterpreted as "confirm via `git status` that the staged contents contain no secrets / out-of-scope files"
- After the push in Step 7, **create a draft PR**: `gh pr create --draft` (title = commit title, body = the implementation plan / DoD check results / review results passed from the caller)
- Never promote the draft (remove draft status) or merge
- Interactive behavior without loop-mode is unchanged (PR creation only after user instruction)

## Iron rules

1. **Create a new commit**: don't use `--amend` (it could destroy the previous commit)
2. **No `--no-verify`**: respect the pre-commit hook. If it fails, fix the root cause
3. **Don't push a branch directly to main**: always use a working branch
4. **Don't use `git add -A` / `-a`**: prevent secrets from leaking in by listing files explicitly
5. **Respect past style**: align with the type / language / ticket notation / Co-Authored-By conventions from the last 3 commits
6. **PR only after user instruction**: the skill goes up to push. `gh pr create` happens only if the user instructs it (exception: draft PR creation in loop-mode only — see the "loop-mode" section above)
7. **Default to a single-line title, content only**: don't write why / background / impact scope. Only write a body for breaking changes / a genuinely non-obvious why

## Anti-patterns

- `git commit -am` (misses untracked files + blindly commits everything staged)
- Casually using `git push --force` even on a working branch
- Writing HEREDOC as `EOF` (unquoted), causing variable expansion
- Committing with an English title without checking past style (e.g., the repo actually has a Japanese title convention)
- Unilaterally deciding to add or omit `Co-Authored-By` (match the repo's convention)
- Writing why, rot risk, or "in order to ~" in the title (write the change content only)
- Defaulting to a HEREDOC + multi-line body even for a simple commit (if one line suffices, use one line)
