---
name: commit-push-branch
description: Cuts a new branch and commits & pushes the working-tree changes with a message that follows past commit style (type prefix / ticket ID / Co-Authored-By).
when_to_use: 「branch 切って commit & push して」「PR 用に push」. Also launched from dev-cycle's commit & push stage.
---

> **Source of truth:** `claude/ja/skills/commit-push-branch/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# commit-push-branch

A skill that cuts a new branch, creates a commit following past style, and pushes it. PR creation is separate (`gh pr create`).

## Applicability

Inside a git repo / the working tree has changes worth committing / the `origin` remote is configured.

## Procedure

### Steps 1-2: Check status and extract past style

Run `git status` / `git diff --stat` / `git diff --cached` and `git log -3 --format='%H%n%B%n---'`, and read from past commits the **conventional type prefix / the title's language / how ticket IDs are placed / whether bodies are used / the Co-Authored-By convention**. This extraction takes precedence in all later judgments.

### Step 3: Type and branch name

| Content | type / branch prefix |
|---|---|
| New feature | `feat` |
| Bug fix | `fix` |
| Infra / config / build / tooling | `chore` |
| Docs only | `docs` |
| Refactor (no behavior change) | `refactor` |
| Test additions | `test` |

The branch name is `<prefix>/<ticket-id>-<slug>` when there is a ticket, `<prefix>/<slug>` otherwise. The slug is kebab-case, 3-5 words. **Never identify a branch by ticket ID alone — always include a content slug.** Whether to include the ticket ID follows the Step 2 extraction (this table is a pattern example and does not override Step 2).

Create with `git checkout -b <name>`. On a collision, add a `-2` style suffix.

### Step 4: Explicit add

**Don't use** `-A` / `-a`. Enumerate the targets explicitly in `git add`, then confirm via `git status` that nothing like `.env` / `*.pem` / `credentials*` slipped in.

**When out-of-scope pre-existing changes live in the same file**: file-granular add can't separate them, and `git add -p` is interactive and unusable. **Without touching the working tree** (checkout / stash forbidden), put only your changes into the index:

```bash
tmp=$(mktemp)
git show HEAD:<path> > "$tmp"        # start from the HEAD version
# apply only your own changes to "$tmp" (Edit / sed / patch)
git update-index --cacheinfo 100644,$(git hash-object -w "$tmp"),<path>
```

After staging, print **both** `git diff --cached -- <path>` (only your changes go into the commit) and `git diff -- <path>` (the pre-existing changes remain in the working tree) to confirm the separation.

### Step 5: commit

**The default is a single-line title.** The title carries **only what changed** — why / background / impact scope / ticket context go in neither the title nor the body (they're traceable via the PR description / ticket / git history).

```bash
git commit -m "<type>(<scope>): <what changed>"
```

- Good: `docs(api): rename SearchMeta to RequestMeta and split it into common.proto`
- Bad: `chore: remove the slog.Info "phase" argument introduced in the last commit to avoid rot` (contains why)

**There are only 3 exceptions that warrant a body**: a breaking change (include a `BREAKING CHANGE: <impact>` line) / a genuinely non-obvious why that can't live in the PR description (rare) / past style consistently uses bodies. When using a HEREDOC, suppress expansion with `<<'EOF'` (single quotes). Follow past commits' convention for `Co-Authored-By:` and ticket IDs (don't add or drop them unilaterally).

**GPG signing hang**: in environments with `commit.gpgsign=true`, the commit can hang waiting on pinentry. Run `git commit` with the Bash tool timeout set to 30 seconds; on a hang, confirm via `git status` that the staged state survived (don't rush to reset) → guide the user to commit manually (running `echo test | gpg --clearsign > /dev/null` in another terminal warms the cache). **Don't work around it with `--no-gpg-sign` / `commit.gpgsign=false`** (same spirit as iron rule 2).

### Step 6: push and completion report

`git push -u origin <branch-name>`. Report Branch / Commit (short sha + title) / Files (n files, +additions/-deletions) / the PR creation URL (extracted from the push output). PR creation is a separate task.

## loop-mode (only when invoked by dev-cycle)

Applies **only when loop-mode is explicitly stated at invocation** (basis: CLAUDE.md "loop-mode").

- The branch name / commit message are decided automatically from the conventions and past style, with no user confirmation
- **The base ref is the PR's base branch, not the default branch**: in a stacked PR, base = the parent branch. Don't hardcode `origin/<default-branch>` in either the squash or `gh pr create` (it breaks the stack)
- **Deciding whether to squash the WIP commits**: when the branch carries `wip(<stage>):` commits, always run `git ls-remote --heads origin <branch>` first, and **only if the output is empty (not yet pushed)** run `git reset --soft $(git merge-base HEAD <base>)` to return everything to staged and build one conventional commit (never `--hard`). In that case, read Step 4's explicit add as "confirm the staged content contains no secrets / out-of-scope files". Before squashing, confirm `git log --oneline <base>..HEAD` shows only your own WIP commits (if the parent branch's commits are mixed in, the base is wrong — fix the base instead of squashing)
- **Don't squash an already-pushed branch** (it would require a force push, which conflicts with the prohibition). Stack the final commit on top of the wip commits and push fast-forward. The wip commits remain in the PR's commit list, but under squash-merge conventions the default branch stays clean
- After push, **create a draft PR**: `gh pr create --draft`. **If base is not the default branch, pass `--base <base>` explicitly**
- Never promote the draft or merge

### Constructing the PR body

Material passed from dev-cycle = the implementation plan / DoD check results / spec deviations (SD#) / impact scope / review and security review results / ticket URL.

1. **Search for a PR template**: `.github/pull_request_template.md` → `.github/PULL_REQUEST_TEMPLATE.md` → `.github/PULL_REQUEST_TEMPLATE/*.md` → `PULL_REQUEST_TEMPLATE.md` → `docs/pull_request_template.md`, taking the first one found
2. **If a template exists, its section structure is the SoT.** HTML comments (`<!-- ... -->`) are **read as filling instructions and then removed**. Section names vary by repo, so map by meaning:

| template section (example) | Material to fill in |
|---|---|
| Summary | Summary of the implementation plan / what changed |
| Spec compliance | Each DoD item ↔ the implementation / tests |
| Spec deviations | SD# (or "none") |
| Impact scope | The changed symbol → referencing sites mapping and impact classification |
| Review guide | Reading order of the diff (specify file → symbol, not line numbers — they rot on push) / areas needing focus |
| Compat & rollback | Whether breaking / migration, env, config changes and their order / rollback procedure |
| Verification | test / lint results + review and security review results |
| References | ticket URL / related docs |
| Checklist | Check only mechanically determinable items |

   Material with no corresponding section gets its own section appended at the end of the body (never silently dropped)
3. **If there is no template**, generate the 6 sections `## Summary` / `## Spec compliance` / `## Spec deviations` / `## Impact scope` / `## Verification` / `## References`
4. **Branch on repo visibility for ticket references** (determine mechanically via `gh repo view --json visibility`): private repos put the ticket URL in References. **Public repos must not carry internal URLs / ticket bodies**
5. **Don't delete sections you can't fill**: write "none" when not applicable

**Style**: nominal-ending phrasing / bullet-driven (no prose paragraphs) / don't enumerate every review nit and follow-up — compress to "count + state file path" plus "the 2-3 a reviewer needs before merge" / aim for 45-70 lines.

## Iron rules

1. **Create a new commit**: don't use `--amend`
2. **`--no-verify` forbidden**: respect pre-commit hooks; if one fails, fix the cause
3. **Never push directly to main / master**
4. **Don't use `git add -A` / `-a`**: explicit enumeration prevents secrets slipping in
5. **Match past style**: type / language / ticket notation / Co-Authored-By convention
6. **PRs come after user instruction** (the only exception is draft PR creation in loop-mode)
7. **Default is a one-line title with only what changed**

## Rebasing a stacked PR (after the parent was squash-merged)

Once the parent is squash-merged, none of its commits match by patch-id, so `git rebase --onto` conflicts trying to re-apply the parent's equivalent. Don't attempt a commit-wise rebase — fix the target tree and collapse to one commit:

1. Confirm `git diff <parent tip> origin/<default>` is **empty** (if not, this procedure doesn't apply)
2. Create a recovery point with `git branch backup/<name> <child tip>`
3. `NEW=$(git commit-tree <child tip>^{tree} -p origin/<default> -F <msg file>)`
4. `git checkout -B <branch> $NEW` (don't use `reset --hard`)
5. Mechanically verify that `git diff <child tip> HEAD` is empty (the tree is byte-identical to the reviewed head) and that `git diff origin/<default> HEAD --stat` matches the PR's expected diff

Pushing requires force, so **wait for the user's explicit instruction** (offer `--force-with-lease` + the backup ref).
