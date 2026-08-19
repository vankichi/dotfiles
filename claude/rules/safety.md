---
paths:
  - "**/*.{go,rs,py,rb,ts,tsx,js,jsx,java,kt,php,sql,sh,bash,zsh,c,cc,cpp,h,hpp,proto}"
  - "**/go.mod"
  - "**/package.json"
  - "**/Cargo.toml"
  - "**/pyproject.toml"
  - "**/requirements*.txt"
  - "**/Dockerfile*"
  - "**/Makefile"
  - "**/*.{yaml,yml,tf,tfvars}"
---

# Security / Governance

核となる壁 (secret 不書込 / least privilege / 破壊的操作の 3 点セット / 新規依存の承認) は **CLAUDE.md が SoT**。ここは code・依存・manifest を触る時の詳細のみ。shell command の強制は `hooks/guard-bash.sh`。

## secret

- 既知 prefix (`sk-` / `xoxb-` / `ghp_` / `AKIA` / JWT / PEM block) や高 entropy 文字列を検出したら**即停止して報告**。勝手に削除 / mask / commit しない
- log / error / stack trace に PII / token / cookie / Authorization header を載せない
- 会話に貼られた secret を以降の出力 (tool 引数 / summary / commit message) に echo しない

## injection

- SQL は必ず parameterized query (string 連結禁止)
- shell command 構築で外部入力を string 連結しない (argv 形式)
- `eval` / `exec` / dynamic require を default で書かない。必要なら user 承認 + 入力制限を plan で示す
- file path / URL に `..` / `~` / 絶対 path / scheme 付き URL を許す箇所は path traversal / SSRF として扱う

## 依存

- **新規 dependency は user 承認**。追加前に publisher / 最終更新 / known CVE を確認 (typosquatting 警戒)
- `curl | sh` を避ける。必要なら user 承認 + 出所明示 + checksum 検証
- lockfile は必ず commit。**pin 戦略を尊重する** (勝手に緩めない / 締めない)
- `replace` が local path を指したまま commit されていないか確認する
- ライセンス互換性を確認 (GPL / AGPL / SSPL を商用コードに混ぜない)

## 権限拡大 (user 確認必須)

`chmod 777` / `chmod -R` / `chown -R` / container の `--privileged`・`--cap-add`・`hostPath` / K8s の `cluster-admin`・`*` verb / IAM の `*:*`・wildcard Principal / DB の `GRANT ALL`・`SUPERUSER` / cloud storage の public 化。

## 破壊的操作 — 3 点セット提示後のみ

**3 点セット = dry-run + 影響範囲 + 戻し方**。user の明示指示があっても提示を省かない。

- **DB**: `DROP` / `TRUNCATE` / WHERE なし `DELETE`・`UPDATE` / down migration / backup 削除 / large table の index drop
- **Infra**: production deploy / IAM・trust relationship / DNS・LB・firewall・SG / public access 有効化 / TLS 証明書差し替え / secrets store の上書き
- **公開**: 公開 channel 送信 / public repo push / public gist / production key の発行

destructive ops は dry-run / `EXPLAIN` / preview を必ず先に実行する。

## test fixture

PII / 顧客データ / 監査ログをそのまま使わない (匿名化 or synthetic)。
