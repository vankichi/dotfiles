---
name: sync-k8s-manifest-from-code
description: code repo (Go application) の interface 変更 (config / env / port / probe / resources) を K8s Kustomize manifest repo に伝播する (検出 + 3 環境 Edit + git add まで。commit & push はしない)。対象 repo 情報は MEMORY.md の reference memory から取得する。
when_to_use: code 側の interface 変更 (config / env / port / probe / resource) を k8s manifest に反映する時。
allowed-tools: Read, Edit, Grep, Glob, Bash(git status:*, git diff:*, git add:*, ls:*, find:*, cat:*)
---

# sync-k8s-manifest-from-code

application code repo と K8s Kustomize manifest repo が分離されている運用で、**code → manifest 方向** の sync (検出 → Edit → stage) を半自動化する skill。逆方向 (manifest → code) は対象外。

## 適用パターン

以下に該当する project を想定:

- code repo に YAML config schema (struct) を持ち、**unknown field を起動時 reject** する設計 (= ConfigMap drift が即 crash につながる)
- env (機密 / 非機密) を起動時に required 検証 (= env 不足で `os.Exit(1)`)
- manifest repo は Kustomize `bases/` (= prod SoT) + `overlays/{dev, stg, ...}/` の構成
- 1 service あたり `config/{app.yaml, config.env, sealed-secret.yaml, secret.yaml}` のような config 分離

## 起動時の対象 project 解決 (重要)

global skill なので **project 固有用語を本 SKILL.md に hardcode しない**。起動時、対象 project の以下を MEMORY.md の reference memory から取得する:

| 取得項目 | 例 |
|---|---|
| code repo path | `~/.../some-code-repo` |
| manifest repo path + service directory | `~/.../some-mani-repo/<service-dir>` |
| config schema 位置 | `internal/config/config.go` |
| env 定義位置 | `internal/config/secrets.go` |
| config example | `cmd/<binary>/config.example.yaml` |
| binaries (sync 動作) | `[<A>: full sync, <B>: detect-warn]` |
| overlay 構成 | `[bases, overlays/dev, overlays/stg, ...]` |
| 制約 / 順序 | manifest 先行 → code 後追い マスト 等 |

対応する reference memory が見つからない場合、user に質問して取得 → reference memory として保存する候補を提示する (即書きはしない、user 承認を取る)。

参照可能な reference memory の例:
- 例: `[[<service>-sync]]` のような reference memory

## 検出ロジック (project-agnostic)

reference memory から得た位置情報を元に、code repo の以下を読む (priority 順):

1. **config struct (YAML schema)** の field 追加 / 変更 / 削除
   - 反映先: 全 overlay の `config/app.yaml`
   - unknown field reject 設計なら **manifest 先行マスト**
2. **env 定義** (required env 追加 / rename / 削除)
   - 反映先 (機密): `config/sealed-secret.yaml` (envFrom) の key、または `config/secret.yaml` の key
   - 反映先 (非機密): `config/config.env`
   - 未設定で起動失敗する設計なら **manifest 先行マスト**
3. **config example** の値 / 構造変更
   - 反映先: 各環境 `config/app.yaml` の対応 key
4. **main.go の listen port / probe endpoint**
   - 反映先: `bases/deployment.yaml` (containerPort, livenessProbe, readinessProbe) + `bases/svc.yaml` (port)
5. **resource consumption に効く変更** (heavy lib 追加 / 大 cache / 大 buffer / 並列度変更)
   - 反映先候補: `bases/{deployment, hpa, pdb}.yaml`
   - **数値は user 判断必須** (skill は flag のみ、自動で決めない)
6. **proto / API listen port** (gRPC / REST)
   - 反映先: `bases/{deployment, svc}.yaml` ports
7. **`go.mod` の major dep 追加** (Redis / DB / 外部 API client 等)
   - 反映先: NetworkPolicy (無ければ flag のみ) / Secret (新規認証情報があれば key 追加)
8. **detect-warn 指定 binary** (reference memory で指定) の変更
   - 検出のみ、Edit しない、warn 出力
9. **新規 binary** (`cmd/<new>/` の新規追加)
   - 検出のみ、新規 directory 初期化は対象外、warn 出力

## 動作フロー

1. **pre-check**
   - manifest repo の working tree が **clean** か `git status` で確認 (dirty なら停止、他作業に混ぜない)
   - code repo の対象 ref (default = working tree HEAD) を確認
   - reference memory から対象 project 解決
2. **detect**
   - 上記検出ロジックで差分を抽出
   - 結果を要約 table (どのカテゴリ / どの値 / 反映先候補) で出力
3. **plan-present (user 承認待ち)**
   - 反映先候補を提示
   - 触る overlay の選定が分岐する項目 (resource 等) は **比較形式で user 判断** を仰ぐ
   - **manifest 先行 → code 後追いの順序** を必ず user に明示 (env / unknown field 追加時は強調)
4. **edit**
   - 承認された変更を manifest repo の working tree に Edit
   - 既存 YAML / sealed-secret の indent / 順序 / コメントを保持
   - 既存 overlay override (`bases/` の値を overlay が上書きしているもの) を尊重
5. **stage**
   - 触ったファイルだけ specific path で `git add` (guard-bash.sh hook が `git add -A` / `git add .` を deny)
6. **stop**
   - `git diff --staged` の summary を出力
   - skill はここで停止、user が確認 → `/commit-push-branch` で別途 commit & push

## 制約 / 対象外

| 項目 | 扱い |
|---|---|
| commit / push / PR 作成 | **絶対実行しない**。allowed-tools に `git push` / `gh` を含めない |
| kubeseal (SealedSecret 値暗号化) | 対象外。key の追加までを行い、値は user が後で kubeseal |
| 新規 binary 用 directory 初期化 | 対象外。warn のみ |
| 逆方向 sync (manifest → code) | 別 skill 扱い (例: `.upstream-sha` 系の運用) |
| resource 数値の自動決定 | 対象外。heuristic で flag のみ、最終値は user 決定 |

## 検出漏れの扱い

検出は heuristic なので、出力末尾に **「拾えなかった可能性のある領域」** を必ず明示する:

- 新規 volume mount / hostAlias / annotation
- NetworkPolicy / PodSecurityContext / SecurityContext 細部
- Sidecar / init container 追加
- annotation ベースの動作変更 (Argo Rollouts, Linkerd, Istio 等)

"他にも影響箇所があるかも、目視確認推奨" を 1 行で添える。

## 失敗時の停止条件 (勝手に進まない)

以下を検出したら **stop + user 報告**:

- manifest repo の working tree が dirty
- code repo / manifest repo の path が解決できない (reference memory が無い / path が変わった)
- 反映先ファイルが存在しない (overlay 構成が想定と違う)
- security 観点で要 user 確認の変更 (`Action: "*"` / `privileged` / `hostNetwork` / `hostPID` / public exposure 拡張 / SA に大きい role 付与)
- SealedSecret の **値** (encrypted) 変更が必要
- detect-warn 指定 binary 単独の変更だが、full sync 対象 binary に影響が及ぶ可能性

## 関連

- 対象 project の reference memory (例 `[[<service>-sync]]`) — repo path / config 位置 / binary を保持
- `commit-push-branch` skill — 本 skill 完了後の commit & push (branch 切り + 過去スタイル踏襲)
- `security-review-local` skill — manifest 編集後の security 観点 review (推奨併用)
