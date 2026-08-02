---
name: go-bootstrap
description: Sets up a working skeleton for a new or existing Go project in one shot (module initialization / directory skeleton / .golangci.yaml / Makefile / .gitignore / golangci-lint installation).
when_to_use: When scaffolding a new or existing Go project (go.mod / cmd / internal / .golangci.yaml / Makefile). 「Go project 立ち上げて」.
---

> **Source of truth:** `claude/ja/skills/go-bootstrap/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# go-bootstrap

A skill that sets up a new Go project from scratch to the point where "`make build` / `make test` / `make lint` pass." Intended to be used once per repository.

## Applicability

- Go (assuming 1.22+, using the Toolchain Directive) is installed locally
- The repository root doesn't yet have a `go.mod` (or it's fine to re-set-up)
- Adopting DDD + Clean Architecture (`internal/{domain,application,adapters}/`). Confirm with the user if a different layout is wanted.

## Procedure

### Step 0: Confirm prerequisites

```bash
go version                     # 1.22 or later
ls -la                         # check existing files
test -f go.mod && cat go.mod   # check existing module
```

Things to confirm (consolidate into a single AskUserQuestion turn):
- module path (e.g., `github.com/<org>/<repo>`)
- Go version (default: the latest stable version installed locally)
- Binary layout (e.g., a single `cmd/<bin1>` / `cmd/<bin1>` + `cmd/<bin2>` / other. Name `<bin1>` etc. to match the project.)
- Out of scope: buf / gRPC / IaC are separate skills (this skill covers only the skeleton)

### Step 1: `go mod init`

```bash
go mod init <module-path>
```

Read `go.mod` to confirm the module path and go directive.

### Step 2: `cmd/` skeleton

Write a minimal stub for each binary:

```go
// Package main is the entry point for the <bin-name> binary.
package main

import "log/slog"

func main() {
    slog.Info("<bin-name> starting")
}
```

Comments in English; adopt `log/slog`.

### Step 3: internal / apis / deploy skeleton

Manage empty directories with `.gitkeep`:

- `internal/domain/.gitkeep`
- `internal/application/.gitkeep`
- `internal/adapters/.gitkeep`
- `apis/proto/server/v1/.gitkeep` (if proto usage is planned)
- `deploy/.gitkeep` (if IaC placement is planned)

### Step 4: `.golangci.yaml` (v2 format)

```yaml
version: "2"

run:
  timeout: 5m

linters:
  default: standard
  enable:
    - misspell
    - revive
    - gocritic
  exclusions:
    paths:
      - ^gen/
      - ^cli/go/gen/
    rules:
      - path: _test\.go
        linters:
          - errcheck
          - gocritic

formatters:
  enable:
    - gofmt
    - goimports
  settings:
    goimports:
      local-prefixes:
        - <module-path>
```

`paths` is interpreted as a **regex**, so anchor it at the start like `^gen/`.

### Step 5: Makefile

```makefile
.DEFAULT_GOAL := help

.PHONY: help build test lint generate tidy

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

build: ## Build all binaries (go build ./...)
	go build ./...

test: ## Run tests with race + coverage
	go test -race -coverprofile=coverage.out ./...

lint: ## Run golangci-lint
	@if ! command -v golangci-lint >/dev/null 2>&1; then \
		echo "golangci-lint is not installed. Install with: go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest"; \
		exit 1; \
	fi
	golangci-lint run ./...

generate: ## Generate code (go generate)
	go generate ./...

tidy: ## Tidy go.mod / go.sum
	go mod tidy
```

### Step 6: Update `.gitignore` (append to the existing file)

Create it if there is no existing `.gitignore`; otherwise append to the end:

```
# ===== Go =====
*.exe
*.exe~
*.dll
*.so
*.dylib
bin/
dist/

# Test & coverage
*.test
*.out
*.prof
coverage.*
coverage/

# Go workspace
go.work
go.work.sum

# Dependency directory (legacy)
vendor/

# ===== Generated code =====
/gen/
```

Respect any existing exclusions related to secret management, such as `!.env.example`.

### Step 7: Sync CLAUDE.md / README.md

If `CLAUDE.md` exists, add a "## Development Commands" section (check first that it isn't already present):

```markdown
## Development Commands

Run primary commands via the `Makefile`.

| Command | Purpose |
|---|---|
| `make help` | Show the list of targets |
| `make build` | `go build ./...` |
| `make test` | Run all tests with race + coverage |
| `make lint` | `golangci-lint run` (v2 series) |
| `make generate` | `go generate ./...` |
| `make tidy` | `go mod tidy` |

Uses the v2 series of `golangci-lint`. `go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest` installs it into `$(go env GOPATH)/bin`.
```

### Step 8: Install golangci-lint (only if not already installed)

```bash
which golangci-lint || go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest
golangci-lint --version
```

### Step 9: Verify it works

```bash
make build && echo BUILD_OK
make test  && echo TEST_OK
make lint  && echo LINT_OK
```

If revive's `package-comments` warning appears, add an English package comment to the `main.go` in `cmd/` (it should already be there if it followed the Step 2 template).

### Step 10: Report completion

Report using a DoD-to-step correspondence table:

| Item | Status |
|---|---|
| `go build ./...` | done |
| `make test` / `make lint` | done |
| module path | <confirmed value> |
| Directory skeleton (cmd/internal/apis/proto/deploy) | done |
| `.golangci.yaml` (v2) | done |
| Makefile (build/test/lint/generate/tidy) | done |

## Iron rules

1. **Respect existing files**: don't overwrite an existing `.gitignore` / `CLAUDE.md` / `README.md` — append to them
2. **Comments in English**: comments in Go files are in English
3. **Stay in scope**: implementing features like buf / gRPC / VectorStorePort is out of scope; hand off to the next skill / agent
4. **Don't commit**: committing is delegated to a separate skill (`/commit-push-branch`)

## Anti-patterns

- Overwriting `go mod init` without confirmation
- Fully replacing `.gitignore`, ignoring its existing content
- Writing `cmd/*/main.go` comments in Japanese
- Writing `.golangci.yaml` in v1 format (v2 is now the mainstream)
- Skipping verification (`make build/test/lint`)
