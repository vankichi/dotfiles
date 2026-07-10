---
name: security-review-local
description: ローカルリポジトリと Claude Code 設定のセキュリティ監査。secret leak / .env 実値混入 / permission 過剰許可 / suspicious 命令 / supply chain リスクを横断チェックする。「security review して」「secret 漏れてない?」等で使う。
---

# security-review-local

ローカルリポジトリの security 観点を横断監査する skill。コミット前 / push 前 / 設定変更後に走らせる。

> **builtin `/security-review` との使い分け**: builtin は pending changes (code diff) の脆弱性 review。本 skill はそれに加えて **Claude Code 設定の permission 過剰付与 / tracked secret 名 / .env 実値混入 / Makefile suspicious 命令 / supply chain** をローカル横断で監査する。コード差分の脆弱性なら `/security-review`、リポジトリ + Claude 設定の漏洩・権限監査なら本 skill。

## 適用条件

- git リポジトリ内で実行
- `.gitignore` / `.env*` / `.claude/settings*.json` などが対象になる

## チェック項目

### 1. .gitignore の secret パターン除外

`.env`, `*.env`, `*.pem`, `*.key`, `id_rsa*`, `credentials*`, `secret*`, `*.p12`, `*.pfx`, `*.kdbx` がカバーされているか確認:

```bash
git check-ignore -v .env .env.local secrets/foo.txt credentials.json id_rsa.pem 2>&1
```

各テストパスが `.gitignore:<line>:<pattern>` でマッチすれば OK。マッチしない → `.gitignore` に追記が必要。

### 2. tracked files に secret 系命名がないか

```bash
git ls-files | xargs -I {} sh -c 'case "{}" in *.env|*.pem|*.key|*credentials*|*secret*|*.p12|*.pfx) echo "WARNING: {}";; esac'
```

`.env.example` / `.envrc.example` のような **テンプレ** は許容。実 secret ファイル (`.env`, `id_rsa`) が tracked になっていたら即 unstage。

### 3. .env* テンプレの実値混入チェック

```bash
ls -la .env* 2>/dev/null
```

`.env.example` 等が tracked なら Read して、`OPENAI_API_KEY=sk-...` のような実値が入っていないか確認。形式は `KEY=` (空) が望ましい。

### 4. Claude Code 設定の permission 確認

```bash
cat .claude/settings.json
cat ~/.claude/settings.json
```

allow リストに以下が**含まれていない**ことを確認:

| ⚠️ 含まれていたら危険 | 理由 |
|---|---|
| `Bash(rm:*)` / `Bash(rm -rf:*)` | 破壊的 |
| `Bash(curl:*)` / `Bash(wget:*)` | 任意 URL アクセス |
| `Bash(cat:*)` (broad) | `~/.ssh/id_rsa` 等任意ファイル読み出し |
| `Bash(grep:*)` (broad) | 任意ファイル grep |
| `Write(*)` / `Edit(*)` (broad) | プロジェクト外含む任意書き込み |
| `Bash(ssh:*)` / `Bash(scp:*)` | リモートアクセス |
| `Bash(*)` | 完全な任意実行 |

範囲限定された read-only 系 (`Bash(go test:*)`, `Bash(git status)`, `Bash(ls:*)`) は問題なし。

### 5. コード / Makefile の suspicious コマンド

```bash
grep -rE "(curl|wget|eval\(|http://|https://[^ )]*\.(sh|env)|nc -e|/dev/tcp)" \
    Makefile .golangci.yaml cmd/ internal/ scripts/ 2>/dev/null
```

ヒットしたら詳細確認。CI スクリプトでの `curl https://...install.sh | sh` は要レビュー。

### 6. Go コードの log 出力に secret

```bash
grep -rnE 'slog\.(Info|Debug|Warn|Error).*\b(API_KEY|SECRET|TOKEN|PASSWORD|ENV)' cmd/ internal/ 2>/dev/null
grep -rnE 'fmt\.(Print|Println|Printf).*\b(API_KEY|SECRET|TOKEN|PASSWORD)' cmd/ internal/ 2>/dev/null
grep -rn 'os\.Environ()' cmd/ internal/ 2>/dev/null   # 環境変数全ダンプ
```

ヒットしたら、log mask / redact が必要か検討。

### 7. 外部依存の supply chain

```bash
cat go.mod
go mod why <suspicious-pkg>   # 必要なら
```

- `require` ブロックの依存先が信頼できる org か (例: 怪しい author の typosquat)
- `replace` ディレクティブが local path を指していないか (commit してはいけない)
- `go.sum` が gitignore されていないか (整合性検証に必須)

### 8. .claude/settings.local.json (個人設定)

```bash
git check-ignore .claude/settings.local.json
```

ignored であることを確認。tracked になっていたら個人 token 等の漏洩リスク。

## レポート形式

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

## 鉄則

1. **報告は具体的に**: 「○○が問題」だけでなく、どこを直すかまで提示
2. **false-positive を恐れない**: 怪しいものは listed する。「問題なし」を装わない
3. **修正は別 skill に委ねる**: ここは監査専用。修正は `/self-review-changes` 等で
4. **過去の incident を覚えておく**: 同じ漏洩パターンを次回も見落とさない
