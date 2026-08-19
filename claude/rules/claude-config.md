---
paths:
  - "**/settings.json"
  - "**/settings.local.json"
  - "**/.gitignore"
  - "**/.mcp.json"
---

# Claude Code 設定を触る時の規約

builtin `/security-review` は pending changes の脆弱性 review を担当する。**設定と repo の secret 衛生はその対象外** — ここが SoT。

## permission の実測特性

- **permission rule は model context に載らない** (harness 側で強制される)。**行数を削っても token は減らない** — 削減目的で壁を薄くしない
- **`**/` pattern は project root 相対**。project 外の絶対 path には及ばない (実測: `Read(**/*.pem)` は `/tmp/permprobe/outside.pem` を拒否しなかった)。home 配下の secret (`~/.ssh/**` / `~/.aws/credentials` / `~/.kube/config`) を守るなら **`~/` 始まりの形を別途書く**
- deny は allow より強い。迷ったら deny に寄せる

## allow list に入れてはいけない entry

| 危険な entry | 理由 |
|---|---|
| `Bash(*)` | 完全な任意実行 |
| `Bash(rm:*)` / `Bash(rm -rf:*)` | 破壊的 |
| `Bash(curl:*)` / `Bash(wget:*)` | 任意 URL アクセス |
| broad な `Bash(cat:*)` / `Bash(grep:*)` | `~/.ssh/id_rsa` 等の任意 file 読み出し |
| broad な `Write(*)` / `Edit(*)` | project 外を含む任意書き込み |
| `Bash(ssh:*)` / `Bash(scp:*)` | リモートアクセス |

範囲限定された read-only 系 (`Bash(go test:*)` / `Bash(git status)` / `Bash(ls:*)`) は問題ない。

## repo の secret 衛生

```bash
# .gitignore が secret pattern を除外しているか (path ごとに .gitignore:<line>:<pattern> が出れば OK)
git check-ignore -v .env .env.local secrets/foo.txt credentials.json id_rsa.pem

# tracked file に secret 系の命名が無いか
git ls-files | grep -iE '\.(env|pem|key|p12|pfx)$|credentials|secret'
```

`.env.example` のような**テンプレは許容**。実 secret file が tracked なら**即 unstage して報告**。テンプレに `KEY=sk-...` のような実値が入っていないかも確認する (空が望ましい)。

## hook

hook で自動実行される command は **user に明示してから commit する**。hook の無効化・迂回は user の明示指示なしに行わない。
