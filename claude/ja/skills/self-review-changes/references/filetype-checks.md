# filetype-checks — file type 別の機械的 check

skip 可: なし (常時実施)。

- **Go (`*.go`)**: `gofmt` / `goimports` / godoc 規約 (`// Package <name>` / `// FuncName ...`) / `fmt.Errorf("...: %w", err)` / context arg 最初 / 不要 export
- **設定 (`.golangci.yaml` / `Makefile` / `*.yaml` / `*.json`)**: 形式バージョン (e.g. golangci-lint v1 vs v2) / regex glob (`gen` 中間一致 vs `^gen/` ルート限定) / インデント
- **Markdown / Docs**: 相対 link / コードブロック言語指定 / 表セル数一貫性 / heading 階層
- **Shell / Makefile / Dockerfile**: shell injection (`$VAR` クォート) / 危険コマンド (`rm -rf`, `curl | sh`)
- **Proto (`.proto`)**: package / option / field number / 後方互換性 (`buf breaking`)
