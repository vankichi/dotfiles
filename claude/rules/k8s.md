---
paths:
  - "**/manifests/**/*.{yaml,yml}"
  - "**/k8s/**/*.{yaml,yml}"
  - "**/deploy/**/*.{yaml,yml}"
  - "**/overlays/**/*.{yaml,yml}"
  - "**/base/**/*.{yaml,yml}"
  - "**/kustomization.{yaml,yml}"
---

# K8s house 規約

一般論は書かない。**house の選択**と**事故になる罠**のみ。

## 適用経路

production への apply は **CD 経由 (GitOps) が default**。`kubectl apply` の直接実行は禁忌。**Git に存在しない state を作らない** (`kubectl run` / `edit` の産物を残さない)。変更前は `kubectl diff`。

## 命名 / selector

- **環境を name に埋めない** — namespace で分離する (`my-app-prod` ではなく `my-app` + namespace `prod`)
- 全リソースに `app.kubernetes.io/name`
- **`spec.selector.matchLabels` は immutable**。**commit SHA / build number のような変動 label を selector に入れない**

## 事故になる罠

**liveness probe に依存先を見せない** — アプリ内部状態や DB を見ると、DB 障害で全 pod が再起動して障害が悪化する。「process が応答するか」だけにする。依存先は readiness 側。起動が遅いなら startup probe で猶予を取る (liveness の `initialDelaySeconds` を伸ばす競争を避ける)。3 probe に同じ endpoint を当てない。

**NetworkPolicy で kube-dns への egress を忘れると name resolution が落ちて全 pod が死ぬ**。default deny を入れたら必ず DNS を allow する:

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

cluster に network policy controller (Calico / Cilium) が居ないと **NetworkPolicy は黙って無視される**。

**memory limit は必ず設定する** (OOM kill のほうが node 全体の巻き込みより安全)。**CPU limit は throttling を招くため注意して使う** — requests のみの運用も一般的。sizing は推測せず計測値に基づく。

**tag を pin したら `pullPolicy` を明示的に書く** (`:latest` は implicit に `Always` になる)。production は digest pin。

**Secret を環境変数で注入すると `/proc/<pid>/environ` から見える**。機微なものは volume mount + readOnly。**`envFrom` の一括注入をしない** (env 肥大化と名前衝突)。

## SecurityContext baseline

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
    seccompProfile: { type: RuntimeDefault }
  containers:
  - name: app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities: { drop: ["ALL"] }
```

禁忌: `privileged` / `hostNetwork` `hostPID` `hostIPC` / `hostPath` mount / `runAsUser: 0`。namespace に `pod-security.kubernetes.io/enforce: restricted` を貼る。

## RBAC

ServiceAccount を**必ず明示**する (default SA を使わない)。K8s API を叩かない pod は `automountServiceAccountToken: false`。禁忌: `verbs`/`resources`/`apiGroups` の `*` / `cluster-admin` bind。**ClusterRoleBinding の前に Role + RoleBinding で足りないかを必ず先に検討する**。

## workload

production は `replicas >= 2` + PDB。複数 zone なら topologySpreadConstraints。**graceful shutdown**: SIGTERM 受信で readiness を false にしてから drain し、`terminationGracePeriodSeconds` を cleanup 時間に合わせる。

## Kustomize が default

**Helm は OSS chart の import と配布が必要な時に限定する**。理由 = YAML のまま読める / 環境差分は overlay で足りる / patch が局所的で values で全穴を開けずに済む。

`base/` は環境非依存に保つ。overlay の patch は最小限に (値だけなら `configMapGenerator`)。`namePrefix` / `nameSuffix` は **selector の immutability に注意**。OSS chart は `helmCharts:` で inflate → overlay patch。

## CI

`kubeconform` (schema) + `kube-linter` (anti-pattern) + `trivy config` (misconfig) の 3 つに `kustomize build` の出力を流す。これらが green なら probe 無し / resources 無し / `privileged` / root 実行 / `:latest` / RBAC wildcard は**検出済みとして扱い、review で再走しない**。
