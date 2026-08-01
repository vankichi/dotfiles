---
name: k8s-style
description: K8s manifest / workload 設計 / RBAC / SecurityContext / NetworkPolicy / probe / resource / Kustomize / image 運用の house 規約。手順 skill ではない reference。
when_to_use: 「K8s 的にどう」「manifest 規約」「RBAC 最小権限」「probe どう書く」等の問いが来た時。manifest の作成 / review / refactor 候補出しの判断基準が要る時。`code-refactor-advisor` / `security-review-local` からの参照。
---

# k8s-style

K8s の house 規約と、規約違反を拾うための検出シグナル集。manifest 作成 / review / refactor 候補出しの判断基準として参照する。

**一般論 (Deployment と StatefulSet の使い分け / probe の役割 / base64 は暗号化ではない 等) は再掲しない** — 本 skill が持つのは house の選択、事故になる罠、grep で気付くための signal のみ。

## 1. 基本姿勢

- **production への apply は CD 経由 (GitOps: ArgoCD / Flux) が default**。`kubectl apply` の直接実行は禁忌
- 変更前は**必ず `kubectl diff`** で差分確認
- imperative command (`kubectl run` / `kubectl expose` / `kubectl edit`) で作ったリソースを残さない (**Git に存在しない state は禁忌**)
- 1 YAML = 1 リソース、または論理的に 1 単位 (Deployment + Service + HPA + PDB)

**検出**: manifest に無いリソースが cluster 上にある (drift) / `last-applied-configuration` annotation と Git の不一致

## 2. API version

`apiVersion` は最新 stable に揃える (`apps/v1` / `batch/v1` / `networking.k8s.io/v1` / `autoscaling/v2` / `policy/v1`)。`PodSecurityPolicy` は削除済みで **Pod Security Admission (PSA)** に移行する。CI で `pluto` を回して廃止 API を検知する。

## 3. 命名 / Label / Selector

- resource name は lowercase + `-` (RFC 1123)、63 文字以下。**環境を name に埋めない** (namespace で分離 — `my-app-prod` ではなく `my-app` + namespace `prod`)
- 全リソースに `app.kubernetes.io/*` を付ける: `name` (必須) / `instance` `version` `component` `managed-by` (推奨) / `part-of` (任意)
- **Deployment の `spec.selector.matchLabels` は immutable** — 後から変えると update できなくなる。Service の selector は `name` + `instance` で安定させ、**commit SHA / build number のような変動 label を selector に入れない**
- カスタム annotation は逆 DNS で namespace 化する (`example.com/my-key`)。controller 管理の annotation (`kubectl.kubernetes.io/*` / `meta.helm.sh/*`) は手で書かない

**検出**: 名前に大文字 / underscore / recommended labels 欠落 / rolling deploy で変わる値が selector に入っている

## 4. Resource requests / limits

- **requests と limits を必ず設定**する (未設定は BestEffort QoS で最初に kill される)
- **CPU limit は注意して使う** (throttling が発生する。requests のみの運用も一般的)。**memory limit は必ず設定**する (OOM kill のほうが node 全体の巻き込みより安全)
- `requests = limits` で Guaranteed QoS (重要 workload 向け)
- サイズは推測で決めず `kubectl top` / Prometheus / VPA recommender の**計測値に基づく**。初期は控えめ → 観測して調整

**検出**: `resources:` が空 / `limits` のみ / `requests` のみ / memory limits が requests の 10 倍以上 (枠の無駄) / latency 要件があるのに CPU limits が 100m 未満 (確実に throttle)

## 5. Probe

3 種を使い分ける (**全部同じ endpoint を当てるのは anti-pattern**)。専用 endpoint を持たせる (`/healthz` / `/readyz` / `/startupz`)。

- **liveness は最小限に保つ**: アプリ内部状態や依存 DB を見ず「process が応答するか」だけ。**liveness で DB を見ると DB 障害で全 pod が再起動して悪化する**
- **readiness は依存先を含めてよい** (DB / cache / dependent service の health を反映)
- 起動が遅いアプリは **startup probe で猶予を取り、liveness の `failureThreshold` は短く保つ** (liveness の `initialDelaySeconds` を伸ばす競争を避ける)

**検出**: liveness が DB を叩いている / 3 probe が同じ endpoint / `initialDelaySeconds` が異常に大きい (300s 等)

## 6. SecurityContext / Pod Security

house の baseline:

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

**禁忌**: `privileged: true` / `hostNetwork` `hostPID` `hostIPC` / `hostPath` mount (特に `/` `/etc` `/var/run/docker.sock`) / `runAsUser: 0` / `allowPrivilegeEscalation: true` / `capabilities.add: ["SYS_ADMIN"]` 等の強権限。

PSA は namespace label で強制し、**production / 一般 workload は `restricted`**:

```yaml
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
```

**検出**: `securityContext` 不在 / `hostPath` 使用 / root 実行 / `capabilities.drop` 未指定

## 7. RBAC (最小権限)

- ServiceAccount を**必ず明示**する (default SA を使わない)。K8s API を叩かない pod は `automountServiceAccountToken: false`
- **禁忌**: `verbs: ["*"]` / `resources: ["*"]` / `apiGroups: ["*"]` / `cluster-admin` の bind / 広範な ClusterRoleBinding (Role + RoleBinding で namespace 限定にできないか先に検討する)
- token が必要な場合のみ projected token (TokenRequest API) で短命化する

**検出**: `serviceAccountName` 未指定 / ClusterRole の wildcard / RoleBinding で済むのに ClusterRoleBinding

## 8. NetworkPolicy

各 namespace に default deny ingress / egress を 1 個入れ、必要な通信だけ allow で開ける:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]
```

**罠**:
- **DNS (kube-dns) への egress を忘れると name resolution が落ちて全 pod が死ぬ**。必ず allow する:
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
- egress を全開 (`{}`) にするとデータ exfiltration を防げない
- **cluster に network policy controller (Calico / Cilium 等) が居ないと NetworkPolicy は無視される**。導入前提を確認する

**検出**: NetworkPolicy が 1 つも無い namespace / 全開 egress / DNS allow の欠落

## 9. Workload 設計

- 1 Pod = 1 main process。sidecar は**役割が明確な時のみ**追加する。init container は起動前にだけ必要な処理 (migration / config 取得) に限定する
- production の Deployment は `replicas >= 2` + **PodDisruptionBudget** (`minAvailable: 1` 等)。複数 zone があるなら **topologySpreadConstraints** で分散し、rolling 中の `maxUnavailable` は控えめにする
- **graceful shutdown**: `terminationGracePeriodSeconds` を SIGTERM 後の cleanup 時間に合わせ、アプリ側は SIGTERM 受信で readiness を false にしてから drain する (preStop hook で sleep する pattern)

**検出**: production で `replicas: 1` / PDB なし / preStop hook が無く in-flight request が drop する

## 10. ConfigMap / Secret

- 設定値は ConfigMap、機密は Secret (混ぜない)。**`envFrom` の一括注入は env 肥大化と名前衝突を招く** — 必要な key だけ `valueFrom` で入れる
- `immutable: true` の ConfigMap で hot reload を抑止し controller 負荷を下げる
- 本番の Secret は **External Secrets Operator / Sealed Secrets / Vault / cloud secret manager** を使う。**Secret を環境変数で注入すると `/proc/<pid>/environ` から見える** ため、機微なものは volume mount + readOnly + tmpfs を検討する
- **Secret を Git に commit しない** (base64 encode 済みも同じ)

**検出**: ConfigMap に password / token らしき key / Secret が平の YAML で commit / 全環境で同じ Secret 値

## 11. Image / Tag

- **`:latest` を使わない**。semver tag + digest (`@sha256:...`) の併用が最安全で、production manifest は **digest pin** を default にする
- tag を pin したら `pullPolicy` に**明示的に `IfNotPresent`** を書く (`:latest` は implicit に `Always` になる)
- base は distroless / chainguard / minimal を default。multi-stage build で build deps を残さない。`trivy` / `grype` で CVE スキャンし SBOM を CI に組み込む

**検出**: `:latest` tag / 固定 tag なのに pullPolicy 未指定 / root user で動く image

## 12. Kustomize (default) / Helm

**default は Kustomize**。理由 = YAML のまま読める (template engine の癖が無い) / 環境差分は overlay で足りる / 部分上書きが patch で局所的にでき values で全穴を開けずに済む。**Helm は OSS chart を import する時と配布が必要な時に限定する**。

- 構造は `base/` + `overlays/{dev,staging,prod}/`。**base は環境非依存に保ち、環境固有の値で汚さない**
- overlay の patch は最小限に。値だけなら `configMapGenerator` / `secretGenerator` で上書きする
- patch は strategic merge patch (`patches:` with `target:`) を default に、JSON Patch は強い変更のみ
- `commonLabels` / `commonAnnotations` で label を一括付与。`namePrefix` / `nameSuffix` は **selector の immutability に注意**する
- `kustomize build overlays/prod | kubectl diff -f -` で本番差分を確認する
- OSS chart は Kustomize の `helmCharts:` で inflate → overlay patch が扱いやすい

**検出**: 自社アプリ用に新規 Helm chart を切ろうとしている (Kustomize で済まないか先に検討) / overlay の patch 肥大化 (base 設計を見直す signal) / base が環境値で汚れている

## 13. Lint / Validation (CI 必須)

| tool | 役割 |
|---|---|
| `kubeconform` | schema validation |
| `kube-linter` | 設定 anti-pattern (probe 無し / privileged / no resources) |
| `trivy config` | manifest の security misconfig |
| `conftest` (OPA / Rego) | 社内規約の強制 |
| `pluto` | 廃止 API 検出 |

**最低限 `kubeconform` + `kube-linter` + `trivy config` の 3 つを入れる**。`kustomize build` の出力をこれらに流すのが定番フロー。

## 14. Observability

log は **stdout / stderr に構造化 JSON で出す** (file に書かない — ephemeral container は消える)。metrics endpoint を全 workload に生やし、ServiceMonitor か `prometheus.io/scrape` annotation で配線する。**高 cardinality な label を metrics に入れない** (時系列 DB を破壊する)。重要 SLI は Recording Rule で事前計算する。

## チェックリスト (manifest review 時)

- [ ] `apiVersion` が stable / 非推奨でない
- [ ] `app.kubernetes.io/*` が全 resource に揃っている
- [ ] `resources.requests` / `limits` 設定済み (memory limit 必須)
- [ ] liveness / readiness / startup を使い分け (liveness は依存先を見ない)
- [ ] `runAsNonRoot` / `readOnlyRootFilesystem` / `capabilities.drop: ["ALL"]`
- [ ] `serviceAccountName` 明示 + 最小 RBAC + 不要なら `automountServiceAccountToken: false`
- [ ] NetworkPolicy で default deny + 必要な allow (**DNS allow 忘れに注意**)
- [ ] production `replicas >= 2` + PDB + topologySpreadConstraints
- [ ] image の digest pin + `pullPolicy` 明示 + distroless 系 base
- [ ] Secret が平文で commit されていない
- [ ] Kustomize の base が環境非依存 / overlay patch が最小
- [ ] `kubeconform` / `kube-linter` / `trivy config` を CI で通している
