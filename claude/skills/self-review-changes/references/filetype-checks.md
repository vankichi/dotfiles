> **Source of truth:** `claude/ja/skills/self-review-changes/references/filetype-checks.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# filetype-checks — mechanical checks by file type

Skippable: none (always performed).

- **Go (`*.go`)**: `gofmt` / `goimports` / godoc conventions (`// Package <name>` / `// FuncName ...`) / `fmt.Errorf("...: %w", err)` / context arg first / unnecessary exports
- **Config (`.golangci.yaml` / `Makefile` / `*.yaml` / `*.json`)**: format version (e.g. golangci-lint v1 vs v2) / regex glob (`gen` substring match vs `^gen/` root-anchored) / indentation
- **Markdown / Docs**: relative links / code block language tags / consistent table cell counts / heading hierarchy
- **Shell / Makefile / Dockerfile**: shell injection (quoting `$VAR`) / dangerous commands (`rm -rf`, `curl | sh`)
- **Proto (`.proto`)**: package / option / field number / backward compatibility (`buf breaking`)
