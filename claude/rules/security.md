---
paths:
  - "**/*.{go,rs,py,rb,ts,tsx,js,jsx,java,kt,php,sql,sh,bash,zsh,c,cc,cpp,h,hpp,proto}"
  - "**/go.mod"
  - "**/go.sum"
  - "**/package.json"
  - "**/package-lock.json"
  - "**/Cargo.toml"
  - "**/Cargo.lock"
  - "**/pyproject.toml"
  - "**/requirements*.txt"
  - "**/Dockerfile*"
  - "**/*.{yaml,yml,tf,tfvars}"
---

# Security / Governance 詳細規約

コード・依存・manifest を触る時の詳細ルール。核となる原則 (secret 不書込 / least privilege / 破壊的操作の 3 点セット) は CLAUDE.md 側、shell command の強制は `hooks/guard-bash.sh` 側。

## secret / 機密情報

- secret の分離先は `.env` / secret manager / 環境変数 / KMS / Vault のいずれか
- 既知 prefix (`sk-` / `xoxb-` / `ghp_` / `AKIA` / JWT / PEM block) や高 entropy 文字列を検出したら即停止して報告
- log / error message / stack trace に PII / token / cookie / Authorization header を載せない。logging 直前に mask / redact
- 会話に貼られた secret を以降の出力 (tool 引数 / summary / commit message) に echo しない

## 権限拡大 (user 確認必須)

- `chmod 777` / `chmod -R` / `chown -R` / world-writable
- container `--privileged` / `--cap-add` / `hostNetwork` / `hostPID` / `hostPath` mount
- K8s `cluster-admin` / `*` verb / `*` resource binding
- IAM `*:*` / `Action: "*"` / wildcard Principal
- DB `GRANT ALL` / `SUPERUSER` / public role 付与
- cloud storage の public read / write 設定

## 入力検証 / Injection 対策

- SQL は必ず parameterized query (string 連結禁止)
- shell command 構築で外部入力を string 連結しない (argv 形式 / shell=False)
- `eval` / `exec` / `Function()` / dynamic require を default で書かない。必要なら user 承認 + 入力制限を plan で示す
- HTML / JSON / YAML / regex / path への外部入力は boundary で sanitize / validate
- file path / URL に `..` / `~` / 絶対 path / scheme 付き URL を許す箇所は path traversal / SSRF として扱う

## Supply chain / 外部依存

- 新規 dependency は user 承認 (特に AI / crypto / network / serialization / auth 系)。追加前に publisher / 最終更新 / known CVE を確認 (typosquatting 警戒)
- `curl | sh` 形式のインストールは避け、必要なら user 承認 + 出所明示 + checksum 検証
- lockfile (`go.sum` / `package-lock.json` / `Cargo.lock` / `poetry.lock`) は必ず commit
- pin 戦略を尊重 (exact pin なら exact のまま、勝手に緩めない / 締めない)
- vendored / submodule / git URL 依存の新規追加は user 確認

## Governance / コンプライアンス

- ライセンス互換性を確認 (GPL / AGPL / SSPL / 商用条項を商用コードに混ぜない)
- PII / 顧客データ / 監査ログを test fixture にそのまま使わない (匿名化 or synthetic)
- retention / 削除要件 (GDPR 等) のあるテーブル・log への変更は user 確認

## 危険操作の確認 (user の明示指示があっても 3 点セット提示後のみ)

- DB: `DROP TABLE/SCHEMA/DATABASE` / `TRUNCATE` / WHERE なし `DELETE`・`UPDATE` / down migration / backup・WAL 削除 / large table の index drop
- Infra: production deploy / IAM・trust relationship 変更 / DNS・LB・firewall・SG 変更 / public access 有効化 / TLS 証明書差し替え / secrets store の上書き・削除
- 公開: 公開 channel 送信 / public repo push / public gist / production key の新規発行
- destructive ops は dry-run / `EXPLAIN` / preview を必ず先に実行
