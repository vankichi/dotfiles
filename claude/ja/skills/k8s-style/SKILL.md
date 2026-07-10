---
name: k8s-style
description: K8s manifest / workload 設計 / RBAC / SecurityContext / NetworkPolicy / probe / resource / Kustomize / image 運用の reference skill。「K8s 的にどう」「manifest 規約」「RBAC 最小権限」「probe どう書く」等の問いで参照する。手順 skill ではない。
---

# k8s-style

Kubernetes 関連の慣用句・お作法を集めた reference skill。manifest 作成 / review / refactor 候補出しの判断基準として参照する。

## 適用条件

- K8s manifest (`*.yaml` / `*.yml` で `apiVersion` / `kind` を含む) を扱う任意の場面
- Kustomize (`kustomization.yaml`) / Helm chart (`Chart.yaml` / `templates/` / `values.yaml`) を扱う場面
- code-refactor-advisor agent / security-review-local skill からの参照
- 「K8s 的にどう書く」「probe どうする」「最小権限」を尋ねられる場面

---

## 1. Manifest の基本姿勢

- 1 YAML = 1 リソース、または **論理的に 1 単位** (Deployment + Service + HPA + PDB) でまとめる
- `kubectl apply -f` を default にする (`kubectl create` は冪等でないので CI で使わない)
- 変更前は **必ず `kubectl diff`** で差分確認 (推奨規約)
- production への apply は CD 経由 (GitOps: ArgoCD / Flux) を default。`kubectl apply` 直接実行は禁忌
- imperative command (`kubectl run` / `kubectl expose` / `kubectl edit`) で作ったリソースを残さない (Git に存在しない state は禁忌)

検出シグナル:
- manifest に存在しないリソースが cluster 上にある (drift)
- `kubectl edit` の痕跡 (annotation の `last-applied-configuration` と Git の不一致)

---

## 2. API version / 非推奨 API

- 非推奨 / 削除済み API を使わない。`apiVersion` は **最新の stable** に揃える
  - `Deployment` / `DaemonSet` / `StatefulSet` / `ReplicaSet` → `apps/v1`
  - `Job` / `CronJob` → `batch/v1`
  - `Ingress` → `networking.k8s.io/v1` (`extensions/v1beta1` / `v1beta1` は削除済み)
  - `HorizontalPodAutoscaler` → `autoscaling/v2`
  - `PodDisruptionBudget` → `policy/v1`
  - `PodSecurityPolicy` は削除済み → **Pod Security Admission (PSA)** に移行
- `pluto` で deprecated API を CI 検知

---

## 3. 命名 / Label / Annotation

### 命名 (resource name)
- lowercase + `-` (RFC 1123)。`_` は不可
- 長さは 63 文字以下 (Service / Pod の hostname になるため)
- 環境を name に埋めない (namespace で分離)。`my-app-prod` ではなく `my-app` + namespace `prod`

### 推奨ラベル
**全リソースに付ける** (`app.kubernetes.io/*` prefix):

| label | 例 | 必須度 |
|---|---|---|
| `app.kubernetes.io/name` | `my-app` | 必須 |
| `app.kubernetes.io/instance` | `my-app-prod` | 推奨 |
| `app.kubernetes.io/version` | `1.2.3` | 推奨 |
| `app.kubernetes.io/component` | `api` / `worker` | 推奨 |
| `app.kubernetes.io/part-of` | `my-platform` | 任意 |
| `app.kubernetes.io/managed-by` | `kustomize` / `argocd` | 推奨 |

### selector の label
- Deployment の `spec.selector.matchLabels` は **immutable**。後から変えると update できなくなる
- Service の `selector` は `app.kubernetes.io/name` + `app.kubernetes.io/instance` で安定させる
- 環境変動する label (commit SHA / build number) は selector に入れない

### annotation
- カスタム annotation は **逆 DNS** で namespace 化 (`example.com/my-key`)
- `kubectl.kubernetes.io/*` / `meta.helm.sh/*` 等の controller 管理 annotation は手で書かない

検出シグナル:
- 名前に大文字 / underscore
- recommended labels が無い
- selector に rolling-deploy で変わる値が含まれる

---

## 4. Resource requests / limits

### 必須設定
- **必ず `resources.requests` と `resources.limits` を設定** (推奨規約)
- 未設定だと best-effort QoS で最初に kill される

### CPU vs Memory
- **CPU limit は注意して使う**: throttling が発生する。requests のみで運用するパターンも一般的
- **Memory limit は必ず設定**: OOM kill のほうが node 全体への巻き込みより安全
- requests ≤ limits。`requests = limits` で **Guaranteed QoS** (重要 workload)

### サイズ感
- 推測で決めない。`kubectl top` / Prometheus / VPA recommender で **計測値に基づく**
- 初期値は控えめに → 観測して調整 (over-provision はコストと scheduling 効率に響く)
- batch / job 系は短時間 spike を見込む

検出シグナル:
- `resources:` が空 / `limits` のみ / `requests` のみ
- memory `limits` が requests の 10 倍以上 (枠の無駄)
- CPU `limits` が 100m 未満で latency 要件あり (確実に throttle)

---

## 5. Probe (liveness / readiness / startup)

3 種類を **使い分ける**。全部同じ endpoint を当てるのは anti-pattern:

| probe | 役割 | 失敗時の挙動 |
|---|---|---|
| `startup` | 起動完了の判定。重い init (DB migration / cache warmup) があるなら必須 | 失敗で **kill して再起動** |
| `liveness` | 死活確認。**deadlock / hang のみ拾う** | 失敗で **kill して再起動** |
| `readiness` | trafic 受け入れ可否。依存先 (DB / cache) との接続状況 | 失敗で **Service から外す** (kill しない) |

### ベストプラクティス
- **liveness は最小限**: アプリ内部状態 / 依存 DB を見ない。「process が応答するか」だけ
  - liveness で DB を見ると、DB 障害で全 pod が再起動して悪化する
- **readiness は依存先を含めて良い**: DB 接続 / cache 接続 / dependent service の health を反映
- **startup probe で liveness の `initialDelaySeconds` 競争を避ける**: 起動が遅いアプリは startup で猶予を取り、liveness の `failureThreshold` を短くする
- 各 probe 専用 endpoint を持つ (`/healthz` / `/readyz` / `/startupz`)

検出シグナル:
- liveness が DB を叩いている
- 3 つの probe が同じ endpoint
- `initialDelaySeconds` が異常に大きい (300s 等)

---

## 6. SecurityContext / Pod Security

### Pod / Container レベルで必須

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
```

### 禁忌
- `privileged: true`
- `hostNetwork: true` / `hostPID: true` / `hostIPC: true`
- `hostPath` mount (特に `/` / `/etc` / `/var/run/docker.sock`)
- `runAsUser: 0` (root)
- `allowPrivilegeEscalation: true`
- `capabilities.add: ["SYS_ADMIN"]` 等の強権限

### Pod Security Admission (PSA)
namespace label で **restricted** / **baseline** / **privileged** を強制。production / 一般 workload は `restricted`:

```yaml
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
```

検出シグナル:
- `securityContext` 不在 / `hostPath` 使用 / root user 実行 / `capabilities.drop` 未指定

---

## 7. RBAC (最小権限)

### default deny から開始
- ServiceAccount は **必ず明示** (default SA を使わない)
- pod が K8s API を叩く必要がないなら `automountServiceAccountToken: false`
- Role / ClusterRole は **必要な verb / resource のみ**

### 禁忌
- `verbs: ["*"]` / `resources: ["*"]` / `apiGroups: ["*"]`
- `cluster-admin` の bind (人にも、ましてや SA には付けない)
- 広範な ClusterRoleBinding (Role + RoleBinding で namespace 限定にできないか先に検討)

### token 自動マウント
- 必要な場合のみ projected token (TokenRequest API) で短命化

検出シグナル:
- `serviceAccountName` 未指定 (default 使用)
- ClusterRole に wildcard verb / resource
- RoleBinding で済むのに ClusterRoleBinding

---

## 8. NetworkPolicy

### default deny を導入

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]
```

各 namespace に **default deny ingress / egress** を 1 個入れて、必要な通信を allow rule で開ける。

### よくある落とし穴
- **DNS (kube-dns) への egress を忘れる** → name resolution が落ちて全 pod 死亡。必ず allow:
  ```yaml
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
  ```
- egress を全開 (`{}`) にしてるとデータ exfiltration を防げない
- cluster に network policy controller (Calico / Cilium 等) が居ないと NetworkPolicy は **無視される**。導入前提を確認

検出シグナル:
- NetworkPolicy が 1 つも無い namespace / 全開 egress / DNS allow 欠落

---

## 9. Pod / Workload 設計

### Deployment vs StatefulSet vs DaemonSet vs Job
- **stateless app** → Deployment
- **stable identity / persistent volume が必要** → StatefulSet (DB / Kafka / etcd 等)
- **全 node に 1 pod** → DaemonSet (log collector / node exporter)
- **1 回完結 / 定期実行** → Job / CronJob

### Pod 設計
- 1 Pod = 1 main process。複数 process を 1 container に詰めない
- sidecar (proxy / log shipper) は **役割が明確な時のみ**。なんとなく追加しない
- init container は **起動前にだけ必要な処理** に限定 (migration / config 取得)

### Replica / 可用性
- production の Deployment は `replicas >= 2` + **PodDisruptionBudget**:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
spec:
  minAvailable: 1  # or maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: my-app
```

- 複数 zone がある cluster なら **topologySpreadConstraints** で zone 分散
- rolling 中に全 pod が同時に落ちないよう `maxUnavailable` を控えめに

### Graceful shutdown
- `terminationGracePeriodSeconds` を SIGTERM 後の cleanup 時間に合わせる (default 30s)
- アプリ側で SIGTERM 受信時に readiness を false にしてから drain (preStop hook で sleep するパターン)

検出シグナル:
- production で `replicas: 1` / PDB なし / preStop hook なしで in-flight request が drop

---

## 10. ConfigMap / Secret

### ConfigMap
- 設定値は ConfigMap、機密は Secret (混ぜない)
- `envFrom` で一括注入すると env が肥大化 / 名前衝突する。**必要な key だけ `valueFrom`**
- immutable ConfigMap (`immutable: true`) でホットリロード抑止 (controller 負荷低減)

### Secret
- base64 は **暗号化ではない**。Secret は etcd で平文同等 (encryption-at-rest 設定なければ)
- 本番では **External Secrets Operator / Sealed Secrets / Vault / cloud secret manager** を使う
- Secret を環境変数で注入すると `/proc/<pid>/environ` から見える → 機微なものは **volume mount + readOnly + tmpfs** を検討
- Secret を Git に commit しない (base64 encode 済みも同じ)

検出シグナル:
- ConfigMap に password / token らしき key
- Secret が **平の YAML** で commit
- 全環境で同じ Secret 値

---

## 11. Image / Tag / Pull policy

### Tag
- `:latest` を **使わない** (再現性が無い / rolling で何が deploy されたか追えない)
- semver tag (`v1.2.3`) + digest (`@sha256:...`) の併用が最安全
- production manifest は **digest pin** を default にすると tag を上書きされても安全

### Pull policy
- tag が `:latest` だと implicit に `Always` → tag pin した時は **明示的に `IfNotPresent`** を書く
- private レジストリは `imagePullSecrets` を明示

### イメージサイズ / 脆弱性
- distroless / chainguard / minimal base を default
- multi-stage build で build deps を残さない
- `trivy` / `grype` で CVE スキャン、SBOM を CI に組み込む

検出シグナル:
- `:latest` tag
- pull policy 未指定 + 固定 tag
- root user で動く image

---

## 12. Kustomize (default) / Helm

**default は Kustomize**。理由:
- YAML のまま読める (template engine の癖が無い)
- 自社アプリの環境差分用途では overlay で十分
- 部分上書きが patch で局所的にでき、values で全穴を開ける必要がない

Helm は **OSS chart を import する時** / **配布が必要な時** に限定して使う。

### Kustomize 規約
- `base/` + `overlays/{dev,staging,prod}/` の構造
- overlay では **patch を最小限**。値だけなら `configMapGenerator` / `secretGenerator` で上書き
- `kustomize build overlays/prod | kubectl diff -f -` で本番差分確認 → CI で `kustomize build` をレンダリング
- patch は **strategic merge patch (`patches:` with `target:`)** を default。JSON Patch は強い変更のみ
- `commonLabels` / `commonAnnotations` で全リソースに label 一括付与
- `namePrefix` / `nameSuffix` で環境別接尾辞 (selector の immutability に注意)
- 親 `base/` を環境固有の値で汚さない (base は環境非依存に保つ)

### Helm を使う場合の規約
- `Chart.yaml` の `apiVersion: v2`
- chart version と app version を区別 (`version` / `appVersion`)
- values.yaml は **commented / typed** にして利用者が読める形
- `helm template` で render → `kubectl diff` で確認してから `helm upgrade`
- OSS chart を取り込む時も Kustomize の `helmCharts:` で values inflate → overlay patch、という構成が扱いやすい

検出シグナル:
- 自社アプリ用に新規 Helm chart を切ろうとしている (Kustomize で済まないか先に検討)
- overlay で patch が肥大化 (base 設計を見直す signal)
- base が環境値で汚れている

---

## 13. Lint / Validation

CI に必ず仕込む:

| tool | 役割 |
|---|---|
| `kubeconform` | schema validation (apiVersion / kind の整合) |
| `kube-linter` | 設定 anti-pattern (probe 無し / privileged / no resources 等) |
| `conftest` (OPA / Rego) | カスタムポリシー (社内規約の強制) |
| `trivy config` | manifest の security misconfig 検出 |
| `kustomize build` | render 可能性 + 結果を kubeconform / kube-linter に流す |
| `pluto` | 廃止 API 検出 |

**最低限**: `kubeconform` + `kube-linter` + `trivy config` の 3 つは入れる。`kustomize build` の出力を CI でこれらに流すのが定番フロー。

---

## 14. Observability

- 全 workload に **metrics endpoint** (`/metrics` Prometheus format) を生やす
- pod に `prometheus.io/scrape` annotation か、ServiceMonitor (Prometheus Operator) で配線
- log は stdout / stderr に **構造化 JSON で出す**。file には書かない (ephemeral container は消える)
- trace は OpenTelemetry SDK + sidecar / DaemonSet collector → backend (Tempo / Jaeger)
- 重要 SLI は **Recording Rule** で事前計算 (request 時の計算重を避ける)
- 高 cardinality な label / tag を metrics に入れない (時系列 DB を破壊する)

---

## 15. Cost / 効率

- 不要な resources requests = 隠れたコスト。VPA recommender で計測値ベースに
- HorizontalPodAutoscaler (`autoscaling/v2`) で **負荷追従**。CPU だけでなく custom metrics も検討
- Cluster Autoscaler / Karpenter で node 自動増減
- Spot / Preemptible node を batch / dev に活用 (production の stateless にも条件付きで)

---

## 16. 関連 skill / agent

- security レビュー → `security-review-local` skill
- docs (ADR / Runbook / Design) → `tech-docs-writer` skill
- 層境界 / 責務 (アプリ側) → `ddd-clean-architecture` skill
- Go アプリ規約 → `go-style` / `go-test` skill

---

## チェックリスト (manifest review 時)

- [ ] `apiVersion` は stable / 非推奨でない
- [ ] recommended labels (`app.kubernetes.io/*`) が全 resource に揃っている
- [ ] `resources.requests` / `limits` が設定されている (memory limit 必須)
- [ ] `liveness` / `readiness` / `startup` を使い分けている (liveness は依存先を見ない)
- [ ] `securityContext` で `runAsNonRoot` / `readOnlyRootFilesystem` / `capabilities.drop: ["ALL"]`
- [ ] `serviceAccountName` 明示 + 必要最小の RBAC + `automountServiceAccountToken: false` (不要なら)
- [ ] NetworkPolicy で default deny + 必要な allow (DNS allow 忘れに注意)
- [ ] production `replicas >= 2` + PDB + topologySpreadConstraints
- [ ] image tag pin (digest 推奨) + `pullPolicy` 明示 + distroless 系 base
- [ ] Secret が平文で commit されていない (External Secrets / Sealed Secrets / Vault)
- [ ] Kustomize の base が環境非依存 / overlay patch が最小
- [ ] `kubeconform` / `kube-linter` / `trivy config` を CI で通している
