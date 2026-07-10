---
name: security-review-local
description: Security audit of the local repository and Claude Code configuration. Cross-checks for secret leaks, real values leaking into `.env` files, over-granted permissions, suspicious commands, and supply-chain risk. Used for 「security review して」「secret 漏れてない?」 etc.
---

> **Source of truth:** `claude/ja/skills/security-review-local/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# security-review-local

A skill that cross-audits the security aspects of the local repository. Run it before committing, before pushing, or after a configuration change.

> **Division of labor with the builtin `/security-review`**: the builtin reviews vulnerabilities in pending changes (the code diff). This skill additionally cross-audits the local repository for **over-granted permissions in the Claude Code configuration, secret-like tracked filenames, real values leaking into `.env` files, suspicious commands in the Makefile, and supply-chain risk**. Use `/security-review` for vulnerabilities in a code diff, and this skill for leak/permission auditing across the repository and Claude configuration.

## Applicability

- Run inside a git repository
- Targets files such as `.gitignore`, `.env*`, `.claude/settings*.json`, etc.

## Check items

### 1. `.gitignore` excludes secret patterns

Confirm that `.env`, `*.env`, `*.pem`, `*.key`, `id_rsa*`, `credentials*`, `secret*`, `*.p12`, `*.pfx`, `*.kdbx` are covered:

```bash
git check-ignore -v .env .env.local secrets/foo.txt credentials.json id_rsa.pem 2>&1
```

OK if each test path matches as `.gitignore:<line>:<pattern>`. If it doesn't match → an addition to `.gitignore` is needed.

### 2. Check tracked files for secret-like naming

```bash
git ls-files | xargs -I {} sh -c 'case "{}" in *.env|*.pem|*.key|*credentials*|*secret*|*.p12|*.pfx) echo "WARNING: {}";; esac'
```

**Templates** such as `.env.example` / `.envrc.example` are acceptable. If an actual secret file (`.env`, `id_rsa`) is tracked, unstage it immediately.

### 3. Check `.env*` templates for real values leaking in

```bash
ls -la .env* 2>/dev/null
```

If `.env.example` etc. is tracked, Read it and check that no real value (such as `OPENAI_API_KEY=sk-...`) has been entered. The preferred format is `KEY=` (empty).

### 4. Check Claude Code configuration permissions

```bash
cat .claude/settings.json
cat ~/.claude/settings.json
```

Confirm the allow list does **not** contain the following:

| ⚠️ Dangerous if present | Reason |
|---|---|
| `Bash(rm:*)` / `Bash(rm -rf:*)` | destructive |
| `Bash(curl:*)` / `Bash(wget:*)` | arbitrary URL access |
| `Bash(cat:*)` (broad) | reads arbitrary files such as `~/.ssh/id_rsa` |
| `Bash(grep:*)` (broad) | greps arbitrary files |
| `Write(*)` / `Edit(*)` (broad) | arbitrary writes, including outside the project |
| `Bash(ssh:*)` / `Bash(scp:*)` | remote access |
| `Bash(*)` | fully arbitrary execution |

Scoped read-only commands (`Bash(go test:*)`, `Bash(git status)`, `Bash(ls:*)`) are fine.

### 5. Suspicious commands in code / Makefile

```bash
grep -rE "(curl|wget|eval\(|http://|https://[^ )]*\.(sh|env)|nc -e|/dev/tcp)" \
    Makefile .golangci.yaml cmd/ internal/ scripts/ 2>/dev/null
```

If there's a hit, check the details. `curl https://...install.sh | sh` in a CI script needs review.

### 6. Secrets in Go code log output

```bash
grep -rnE 'slog\.(Info|Debug|Warn|Error).*\b(API_KEY|SECRET|TOKEN|PASSWORD|ENV)' cmd/ internal/ 2>/dev/null
grep -rnE 'fmt\.(Print|Println|Printf).*\b(API_KEY|SECRET|TOKEN|PASSWORD)' cmd/ internal/ 2>/dev/null
grep -rn 'os\.Environ()' cmd/ internal/ 2>/dev/null   # 環境変数全ダンプ
```

If there's a hit, consider whether log masking/redaction is needed.

### 7. Supply chain of external dependencies

```bash
cat go.mod
go mod why <suspicious-pkg>   # 必要なら
```

- Whether the dependencies in the `require` block come from a trustworthy org (e.g., typosquatting by a suspicious author)
- Whether a `replace` directive points at a local path (must not be committed)
- Whether `go.sum` is gitignored (required for integrity verification)

### 8. `.claude/settings.local.json` (personal settings)

```bash
git check-ignore .claude/settings.local.json
```

Confirm it's ignored. If it's tracked, there's a risk of leaking personal tokens etc.

## Report format

```
## セキュリティ監査結果 (<時刻>)

### ✓ 問題なし
- .gitignore: .env / *.pem / *.key / credentials* / secrets/ 全て ignored
- tracked files: secret 系命名なし (git ls-files スキャン)
- .env.example: 全キー空 (実値未混入)
- .claude/settings.json allow list: 安全範囲
- 外部依存: <数> 件、全て信頼できる org
- log 出力: sensitive ダンプなし

### ⚠️ 要対応
| # | 項目 | リスク | 修正方針 |
|---|---|---|---|
| 1 | ... | ... | ... |
```

## Iron rules

1. **Report concretely**: don't just say "X is a problem" — also show where to fix it
2. **Don't fear false positives**: list anything suspicious. Don't pretend everything is fine
3. **Leave fixes to another skill**: this skill is audit-only. Fixes go through `/self-review-changes` etc.
4. **Remember past incidents**: don't miss the same leak pattern next time
