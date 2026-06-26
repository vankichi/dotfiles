#!/usr/bin/env bash
# PreToolUse guard for Bash tool calls. Enforces ~/.claude/CLAUDE.md governance rules.
#
# Contract (Claude Code PreToolUse hook):
#   stdin  : JSON { "tool_name": "...", "tool_input": { "command": "..." }, ... }
#   deny   : print JSON permissionDecision=deny on stdout, exit 0 (model is told why)
#   warn   : print JSON permissionDecision=ask on stdout, exit 0 (user must confirm)
#   allow  : exit 0 with no output
#
# Performance: a cheap raw-input grep short-circuits the common case (no relevant
# keyword) before spawning any JSON parser, so most Bash calls pay one grep only.

set -euo pipefail

input=$(cat)

# Fast path: if no governed keyword appears anywhere in the payload, allow immediately.
if ! printf '%s' "$input" | grep -qE 'zshrc\.local|git[[:space:]]+(add|push|reset|clean|checkout)|--no-verify|--no-gpg-sign|chmod|chown|rm[[:space:]]|curl|wget'; then
  exit 0
fi

# Precise extraction of the command string (jq preferred, python3 fallback).
extract_cmd() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null && return
  fi
  printf '%s' "$input" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null || printf ''
}
cmd=$(extract_cmd)
[ -z "$cmd" ] && exit 0

json_str() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"; }
decide() { # $1=decision(deny|ask) $2=reason
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":%s}}\n' \
    "$1" "$(json_str "$2")"
  exit 0
}

# 0. zshrc.local への言及 -> deny (settings.json の Read/Edit/Write deny を Bash 側でも担保)
if printf '%s' "$cmd" | grep -qi 'zshrc\.local'; then
  decide deny "zshrc.local は機密ファイルのため Bash 経由のアクセスを一律禁止しています (settings.json deny と対)。"
fi

# 1. git add -A / --all / . / *  -> deny (CLAUDE.md: git add は必ず specific path 指定)
if printf '%s' "$cmd" | grep -qE '(^|[;&|`(]|[[:space:]])git[[:space:]]+add([[:space:]]+[^;&|]*)?([[:space:]](-A|--all)([[:space:]]|$)|[[:space:]]\.([[:space:]]|$)|[[:space:]]\*)'; then
  decide deny "git add は specific path 指定のみ (CLAUDE.md)。-A / --all / . / * は使わず、対象ファイルを個別に指定してください。"
fi

# 2. git push --force / --force-with-lease / -f  -> deny (危険操作: force push)
if printf '%s' "$cmd" | grep -qE '(^|[;&|`(]|[[:space:]])git[[:space:]]+push([[:space:]]|$)' \
   && printf '%s' "$cmd" | grep -qE '(--force([[:space:]]|=|$)|--force-with-lease|[[:space:]]-f([[:space:]]|$))'; then
  decide deny "force push は危険操作 (CLAUDE.md)。影響範囲 / 戻し方を提示し user の明示確認を取ってから手動で実行してください。"
fi

# 3. 安全スキップ / 権限拡大 -> ask (CLAUDE.md: user の明示指示なしには使わない)
if printf '%s' "$cmd" | grep -qE '(--no-verify([[:space:]]|=|$)|--no-gpg-sign|chmod[[:space:]]+777([[:space:]]|$)|chmod[[:space:]]+-R([[:space:]]|$)|chown[[:space:]]+-R([[:space:]]|$))'; then
  decide ask "安全スキップ / 権限拡大 (--no-verify / --no-gpg-sign / chmod 777 / chmod -R / chown -R) を検出 (CLAUDE.md)。意図を確認してください。"
fi

# 4. rm -rf 系: 危険 target (~ / / / $VAR 展開 / 裸の *) -> deny、それ以外の再帰強制削除 -> ask
if printf '%s' "$cmd" | grep -qE '(^|[;&|`(]|[[:space:]])rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r|-r[[:space:]]+-f|-f[[:space:]]+-r)([[:space:]]|$)'; then
  if printf '%s' "$cmd" | grep -qE 'rm[[:space:]]+-[a-zA-Z-]+[[:space:]]+("?\$[A-Za-z_{]|~([[:space:]/]|$)|/([[:space:]]|$)|\*)'; then
    decide deny "rm -rf の対象に ~ / / / \$VAR 展開 / 裸の * を含んでいます (CLAUDE.md 危険操作)。具体 path を確認し user の明示確認を取ってください。"
  fi
  decide ask "再帰強制削除 (rm -rf) を検出 (CLAUDE.md 危険操作)。対象範囲と戻し方を確認してください。"
fi

# 5. 未 commit 変更の破棄 (git reset --hard / clean -f / checkout .) -> ask
if printf '%s' "$cmd" | grep -qE '(^|[;&|`(]|[[:space:]])git[[:space:]]+(reset[[:space:]]+[^;&|]*--hard|clean[[:space:]]+[^;&|]*-[a-zA-Z]*f|checkout[[:space:]]+(\.|--[[:space:]]+\.)([[:space:]]|$))'; then
  decide ask "未 commit 変更を破棄する操作 (git reset --hard / git clean -f / git checkout .) を検出 (CLAUDE.md 危険操作)。失われる変更がないか確認してください。"
fi

# 6. curl / wget の出力を shell に pipe -> ask (supply chain: 出所明示 + checksum 検証が必要)
if printf '%s' "$cmd" | grep -qE '(curl|wget)[^;&|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|da)?sh([[:space:]]|$)'; then
  decide ask "curl/wget の出力を shell に直接 pipe しています (CLAUDE.md supply chain)。出所と checksum を確認してから実行してください。"
fi

exit 0
