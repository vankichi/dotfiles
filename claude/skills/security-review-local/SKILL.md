---
name: security-review-local
description: Security audit of the local repository and Claude Code configuration. Cross-checks for secret leaks, real values leaking into `.env` files, over-granted permissions, suspicious commands, and supply-chain risk. Used for 「security review して」「secret 漏れてない?」 etc.
when_to_use: Before a commit or push, or after a configuration change. 「security review して」「secret 漏れてない?」. Also launched from dev-cycle's security review stage.
---

> **Source of truth:** `claude/ja/skills/security-review-local/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# security-review-local

A skill that audits the local repository across security perspectives. Run it before a commit, before a push, or after a configuration change.

> **Division of labor with the builtin `/security-review`**: the builtin reviews pending changes (a code diff) for vulnerabilities. This skill additionally audits, across the whole local checkout, **over-granted Claude Code permissions / tracked secret-like filenames / real values in `.env` templates / suspicious commands in the Makefile / supply chain**.

## Check items

### 1. `.gitignore` excludes secret patterns

```bash
git check-ignore -v .env .env.local secrets/foo.txt credentials.json id_rsa.pem 2>&1
```

OK if each test path matches as `.gitignore:<line>:<pattern>`. Anything unmatched needs to be added to `.gitignore`. Target patterns: `.env`, `*.env`, `*.pem`, `*.key`, `id_rsa*`, `credentials*`, `secret*`, `*.p12`, `*.pfx`, `*.kdbx`.

### 2. Secret-like naming among tracked files

```bash
git ls-files | xargs -I {} sh -c 'case "{}" in *.env|*.pem|*.key|*credentials*|*secret*|*.p12|*.pfx) echo "WARNING: {}";; esac'
```

**Templates like `.env.example` are acceptable.** If a real secret file (`.env`, `id_rsa`) is tracked, unstage it immediately.

### 3. Real values in `.env*` templates

Read tracked `.env.example` files and confirm no real values like `OPENAI_API_KEY=sk-...` are present (the desired form is an empty `KEY=`).

### 4. Claude Code configuration permissions

Confirm the allow lists in `.claude/settings.json` and `~/.claude/settings.json` **do not contain**:

| ⚠️ Dangerous | Reason |
|---|---|
| `Bash(*)` | Fully arbitrary execution |
| `Bash(rm:*)` / `Bash(rm -rf:*)` | Destructive |
| `Bash(curl:*)` / `Bash(wget:*)` | Arbitrary URL access |
| `Bash(cat:*)` / `Bash(grep:*)` (broad) | Reading arbitrary files such as `~/.ssh/id_rsa` |
| `Write(*)` / `Edit(*)` (broad) | Arbitrary writes, including outside the project |
| `Bash(ssh:*)` / `Bash(scp:*)` | Remote access |

Scope-limited read-only entries (`Bash(go test:*)` / `Bash(git status)` / `Bash(ls:*)`) are fine.

### 5. Suspicious commands in code / Makefile

```bash
grep -rE "(curl|wget|eval\(|http://|https://[^ )]*\.(sh|env)|nc -e|/dev/tcp)" \
    Makefile .golangci.yaml cmd/ internal/ scripts/ 2>/dev/null
```

`curl https://...install.sh | sh` in a CI script needs review.

### 6. Secrets in log output

```bash
grep -rnE 'slog\.(Info|Debug|Warn|Error).*\b(API_KEY|SECRET|TOKEN|PASSWORD|ENV)' cmd/ internal/ 2>/dev/null
grep -rnE 'fmt\.(Print|Println|Printf).*\b(API_KEY|SECRET|TOKEN|PASSWORD)' cmd/ internal/ 2>/dev/null
grep -rn 'os\.Environ()' cmd/ internal/ 2>/dev/null   # dumping all environment variables
```

### 7. Supply chain of external dependencies

Is each `require` in `go.mod` from a trustworthy org (not a typosquat) / does a `replace` point at a local path (must not be committed) / is `go.sum` gitignored (it's required for integrity verification).

### 8. `.claude/settings.local.json`

Confirm it is ignored via `git check-ignore .claude/settings.local.json`. If tracked, personal tokens risk leaking.

## Report format

```
## Security audit result (<time>)

### ✓ No problems
- <one line of evidence per check item>

### ⚠️ Action required
| # | Item | Risk | Remediation |
|---|---|---|---|
```

If there is even one "⚠️ action required", the caller (dev-cycle) stops unconditionally.

## Iron rules

1. **Report concretely**: not just "X is a problem" but where and how to fix it
2. **Don't fear false positives**: list anything suspicious. Never fake a clean result
3. **Don't fix**: this skill audits only (fixing belongs to `self-review-changes` etc.)
