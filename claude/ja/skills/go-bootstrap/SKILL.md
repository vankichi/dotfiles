---
name: go-bootstrap
description: 新規 / 既存 Go プロジェクトに動く骨格を一括セットアップする (module 初期化 / ディレクトリ骨格 / .golangci.yaml / Makefile / .gitignore / golangci-lint 導入)。「Go プロジェクトのセットアップ」「Go module を切って」「lint と Makefile 用意して」等の依頼で使う。
---

# go-bootstrap

新規 Go プロジェクトをゼロから「`make build` / `make test` / `make lint` が pass する状態」までセットアップする skill。1 リポジトリにつき 1 回しか使わない想定。

## 適用条件

- Go (1.22+ 想定、Toolchain Directive 利用) がローカルに導入されている
- リポジトリ ルートに `go.mod` がまだ無い (or 再セットアップで OK)
- DDD + Clean Architecture を採用する (`internal/{domain,application,adapters}/`)。違うレイアウトのときはユーザーに確認

## 手順

### Step 0: 前提確認

```bash
go version                     # 1.22 以上
ls -la                         # 既存ファイル把握
test -f go.mod && cat go.mod   # 既存 module 確認
```

確認事項 (AskUserQuestion で 1 ターンに集約):
- module path (例: `github.com/<org>/<repo>`)
- Go バージョン (デフォルト: ローカルの最新安定版)
- バイナリ構成 (例: `cmd/<bin1>` 単独 / `cmd/<bin1>` + `cmd/<bin2>` / その他。`<bin1>` 等は project に合わせて命名)
- スコープ外: buf / gRPC / IaC は別 skill (本 skill では骨格のみ)

### Step 1: `go mod init`

```bash
go mod init <module-path>
```

`go.mod` を Read して module path と go directive を確認。

### Step 2: cmd/ 骨格

各バイナリに最小スタブを Write:

```go
// Package main is the entry point for the <bin-name> binary.
package main

import "log/slog"

func main() {
    slog.Info("<bin-name> starting")
}
```

コメントは英語、`log/slog` を採用。

### Step 3: internal / apis / deploy 骨格

`.gitkeep` で空ディレクトリを管理:

- `internal/domain/.gitkeep`
- `internal/application/.gitkeep`
- `internal/adapters/.gitkeep`
- `apis/proto/server/v1/.gitkeep` (proto 利用予定なら)
- `deploy/.gitkeep` (IaC 配置予定なら)

### Step 4: `.golangci.yaml` (v2 形式)

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

`paths` は **regex** として解釈されるため `^gen/` のように先頭一致させる。

### Step 5: Makefile

```makefile
.DEFAULT_GOAL := help

.PHONY: help build test lint generate tidy

help: ## このヘルプを表示
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

build: ## 全バイナリをビルド (go build ./...)
	go build ./...

test: ## race + coverage 付きでテスト実行
	go test -race -coverprofile=coverage.out ./...

lint: ## golangci-lint を実行
	@if ! command -v golangci-lint >/dev/null 2>&1; then \
		echo "golangci-lint が未インストールです。インストール: go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest"; \
		exit 1; \
	fi
	golangci-lint run ./...

generate: ## コード生成 (go generate)
	go generate ./...

tidy: ## go.mod / go.sum を整理
	go mod tidy
```

### Step 6: `.gitignore` 整備 (既存に追記)

既存 `.gitignore` がなければ作成、あれば末尾に追加:

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

`!.env.example` のような既存除外が secret 管理にあれば尊重。

### Step 7: CLAUDE.md / README.md 同期

`CLAUDE.md` があれば「## 開発コマンド」セクションを追加 (重複しないか先に確認):

```markdown
## 開発コマンド

主要コマンドは `Makefile` 経由で実行する。

| コマンド | 用途 |
|---|---|
| `make help` | ターゲット一覧を表示 |
| `make build` | `go build ./...` |
| `make test` | race + coverage 付きで全テスト実行 |
| `make lint` | `golangci-lint run` (v2 系) |
| `make generate` | `go generate ./...` |
| `make tidy` | `go mod tidy` |

`golangci-lint` は v2 系を使用。`go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest` で `$(go env GOPATH)/bin` に入る。
```

### Step 8: golangci-lint インストール (未導入時のみ)

```bash
which golangci-lint || go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest
golangci-lint --version
```

### Step 9: 動作確認

```bash
make build && echo BUILD_OK
make test  && echo TEST_OK
make lint  && echo LINT_OK
```

revive の `package-comments` で警告が出る場合、cmd の `main.go` に英語のパッケージコメントを追加する (Step 2 のテンプレに従っていれば既に付いているはず)。

### Step 10: 完了報告

DoD と各ステップの対応表で報告:

| 項目 | 状況 |
|---|---|
| `go build ./...` | ✓ |
| `make test` / `make lint` | ✓ |
| module path | <確認値> |
| ディレクトリ骨格 (cmd/internal/apis/proto/deploy) | ✓ |
| `.golangci.yaml` (v2) | ✓ |
| Makefile (build/test/lint/generate/tidy) | ✓ |

## 鉄則

1. **既存ファイル尊重**: 既存 `.gitignore` / `CLAUDE.md` / `README.md` は上書きせず追記
2. **コメントは英語**: Go ファイルのコメントは英語
3. **scope を守る**: buf / gRPC / VectorStorePort 等の機能実装は対象外。次の skill / agent に渡す
4. **コミットしない**: コミットは別 skill (`/commit-push-branch`) に委ねる

## アンチパターン

- `go mod init` を確認なしで上書き
- `.gitignore` を既存内容無視で全置換
- `cmd/*/main.go` のコメントを日本語で書く
- `.golangci.yaml` を v1 形式で書く (現在は v2 が主流)
- 動作確認 (`make build/test/lint`) を skip
