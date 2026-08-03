---
name: security-review-local
description: ローカルリポジトリと Claude Code 設定のセキュリティ監査。secret leak / .env 実値混入 / permission 過剰許可 / suspicious 命令 / supply chain リスクを横断チェックする。
when_to_use: commit 前 / push 前 / 設定変更後。「security review して」「secret 漏れてない?」。dev-cycle の security review 工程からも起動される。
---

# security-review-local

ローカルリポジトリの security 観点を横断監査する skill。commit 前 / push 前 / 設定変更後に走らせる。

> **builtin `/security-review` との使い分け**: builtin は pending changes (code diff) の脆弱性 review。本 skill はそれに加えて **Claude Code 設定の permission 過剰付与 / tracked secret 名 / .env 実値混入 / Makefile の suspicious 命令 / supply chain** をローカル横断で監査する。

## チェック項目

### 1. `.gitignore` の secret パターン除外

```bash
git check-ignore -v .env .env.local secrets/foo.txt credentials.json id_rsa.pem 2>&1
```

各テストパスが `.gitignore:<line>:<pattern>` でマッチすれば OK。マッチしないものは `.gitignore` へ追記が必要。対象パターン: `.env`, `*.env`, `*.pem`, `*.key`, `id_rsa*`, `credentials*`, `secret*`, `*.p12`, `*.pfx`, `*.kdbx`。

### 2. tracked files の secret 系命名

```bash
git ls-files | xargs -I {} sh -c 'case "{}" in *.env|*.pem|*.key|*credentials*|*secret*|*.p12|*.pfx) echo "WARNING: {}";; esac'
```

`.env.example` のような**テンプレは許容**。実 secret ファイル (`.env`, `id_rsa`) が tracked なら即 unstage。

### 3. `.env*` テンプレの実値混入

tracked な `.env.example` 等を Read し、`OPENAI_API_KEY=sk-...` のような実値が入っていないか確認する (形式は `KEY=` の空が望ましい)。

### 4. Claude Code 設定の permission

`.claude/settings.json` と `~/.claude/settings.json` の allow list に以下が**含まれていない**ことを確認:

| ⚠️ 危険 | 理由 |
|---|---|
| `Bash(*)` | 完全な任意実行 |
| `Bash(rm:*)` / `Bash(rm -rf:*)` | 破壊的 |
| `Bash(curl:*)` / `Bash(wget:*)` | 任意 URL アクセス |
| `Bash(cat:*)` / `Bash(grep:*)` (broad) | `~/.ssh/id_rsa` 等の任意ファイル読み出し |
| `Write(*)` / `Edit(*)` (broad) | project 外を含む任意書き込み |
| `Bash(ssh:*)` / `Bash(scp:*)` | リモートアクセス |

範囲限定された read-only 系 (`Bash(go test:*)` / `Bash(git status)` / `Bash(ls:*)`) は問題なし。

### 5. code / Makefile の suspicious コマンド

```bash
grep -rE "(curl|wget|eval\(|http://|https://[^ )]*\.(sh|env)|nc -e|/dev/tcp)" \
    Makefile .golangci.yaml cmd/ internal/ scripts/ 2>/dev/null
```

CI script の `curl https://...install.sh | sh` は要レビュー。

### 6. log 出力への secret 混入

```bash
grep -rnE 'slog\.(Info|Debug|Warn|Error).*\b(API_KEY|SECRET|TOKEN|PASSWORD|ENV)' cmd/ internal/ 2>/dev/null
grep -rnE 'fmt\.(Print|Println|Printf).*\b(API_KEY|SECRET|TOKEN|PASSWORD)' cmd/ internal/ 2>/dev/null
grep -rn 'os\.Environ()' cmd/ internal/ 2>/dev/null   # 環境変数の全ダンプ
```

### 7. 外部依存の supply chain

`go.mod` の `require` が信頼できる org か (typosquat でないか) / `replace` が local path を指していないか (commit してはいけない) / `go.sum` が gitignore されていないか (整合性検証に必須)。

### 8. `.claude/settings.local.json`

`git check-ignore .claude/settings.local.json` で ignored であることを確認する。tracked なら個人 token 漏洩のリスク。

## レポート形式

```
## セキュリティ監査結果 (<時刻>)

### ✓ 問題なし
- <check 項目ごとに 1 行で根拠を書く>

### ⚠️ 要対応
| # | 項目 | リスク | 修正方針 |
|---|---|---|---|
```

「⚠️ 要対応」が 1 件でもあれば、呼び出し元 (dev-cycle) は無条件で停止する。

## 鉄則

1. **報告は具体的に**: 「○○が問題」だけでなく、どこをどう直すかまで書く
2. **false-positive を恐れない**: 怪しいものは挙げる。「問題なし」を装わない
3. **修正はしない**: 本 skill は監査専用 (修正は `self-review-changes` 等の責務)
