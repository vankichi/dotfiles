---
name: k8s-style
description: Reference skill for K8s manifests / workload design / RBAC / SecurityContext / NetworkPolicy / probes / resources / Kustomize / image operations. Consult it for questions like 「K8s 的にどう」「manifest 規約」「RBAC 最小権限」「probe どう書く」. Not a procedural skill.
---

> **Source of truth:** `claude/ja/skills/k8s-style/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# k8s-style

A reference skill collecting Kubernetes-related idioms and conventions. Consult it as a criterion for creating manifests, reviews, and identifying refactor candidates.

## Applicability

- Any situation dealing with K8s manifests (`*.yaml` / `*.yml` containing `apiVersion` / `kind`)
- Situations dealing with Kustomize (`kustomization.yaml`) / Helm charts (`Chart.yaml` / `templates/` / `values.yaml`)
- Referenced by the code-refactor-advisor agent / security-review-local skill
- Situations where you're asked 「K8s 的にどう書く」「probe どうする」「最小権限」

---

## 1. Basic stance on manifests

- 1 YAML = 1 resource, or group them as **one logical unit** (Deployment + Service + HPA + PDB)
- Default to `kubectl apply -f` (`kubectl create` is not idempotent, so don't use it in CI)
- **Always check the diff with `kubectl diff`** before making changes (recommended convention)
- Default to applying to production via CD (GitOps: ArgoCD / Flux). Directly running `kubectl apply` is forbidden
- Don't leave behind resources created with imperative commands (`kubectl run` / `kubectl expose` / `kubectl edit`) (state that doesn't exist in Git is forbidden)

Detection signals:
- Resources exist on the cluster that aren't in any manifest (drift)
- Traces of `kubectl edit` (mismatch between the `last-applied-configuration` annotation and Git)

---

## 2. API version / deprecated APIs

- Don't use deprecated / removed APIs. Align `apiVersion` to **the latest stable**
  - `Deployment` / `DaemonSet` / `StatefulSet` / `ReplicaSet` → `apps/v1`
  - `Job` / `CronJob` → `batch/v1`
  - `Ingress` → `networking.k8s.io/v1` (`extensions/v1beta1` / `v1beta1` have been removed)
  - `HorizontalPodAutoscaler` → `autoscaling/v2`
  - `PodDisruptionBudget` → `policy/v1`
  - `PodSecurityPolicy` has been removed → migrate to **Pod Security Admission (PSA)**
- Detect deprecated APIs in CI with `pluto`

---

## 3. Naming / Labels / Annotations

### Naming (resource name)
- lowercase + `-` (RFC 1123). `_` is not allowed
- Length must be 63 characters or fewer (because it becomes the Service / Pod hostname)
- Don't embed the environment in the name (separate via namespace). Use `my-app` + namespace `prod` instead of `my-app-prod`

### Recommended labels
**Attach to all resources** (with the `app.kubernetes.io/*` prefix):

| label | example | requirement level |
|---|---|---|
| `app.kubernetes.io/name` | `my-app` | Required |
| `app.kubernetes.io/instance` | `my-app-prod` | Recommended |
| `app.kubernetes.io/version` | `1.2.3` | Recommended |
| `app.kubernetes.io/component` | `api` / `worker` | Recommended |
| `app.kubernetes.io/part-of` | `my-platform` | Optional |
| `app.kubernetes.io/managed-by` | `kustomize` / `argocd` | Recommended |

### selector labels
- Deployment's `spec.selector.matchLabels` is **immutable**. Changing it later makes updates impossible
- Stabilize the Service's `selector` using `app.kubernetes.io/name` + `app.kubernetes.io/instance`
- Don't put environment-varying labels (commit SHA / build number) into the selector

### annotations
- Namespace custom annotations using **reverse DNS** (`example.com/my-key`)
- Don't hand-write controller-managed annotations such as `kubectl.kubernetes.io/*` / `meta.helm.sh/*`

Detection signals:
- Uppercase letters / underscores in names
- Missing recommended labels
- The selector includes a value that changes on rolling deploy

---

## 4. Resource requests / limits

### Required settings
- **Always set both `resources.requests` and `resources.limits`** (recommended convention)
- Without them, the pod gets BestEffort QoS and is the first to be killed

### CPU vs Memory
- **Use CPU limits with caution**: they cause throttling. Running with requests only is also a common pattern
- **Always set a memory limit**: an OOM kill is safer than dragging down the entire node
- requests ≤ limits. Setting `requests = limits` gives **Guaranteed QoS** (for important workloads)

### Sizing
- Don't guess. Base sizing **on measured values** from `kubectl top` / Prometheus / the VPA recommender
- Start conservative → observe and adjust (over-provisioning hurts cost and scheduling efficiency)
- For batch / job workloads, account for short-lived spikes

Detection signals:
- `resources:` is empty / only `limits` / only `requests`
- memory `limits` is 10x or more the requests (wasted headroom)
- CPU `limits` is under 100m while there's a latency requirement (guaranteed to throttle)

---

## 5. Probes (liveness / readiness / startup)

**Use the three types appropriately.** Pointing all of them at the same endpoint is an anti-pattern:

| probe | role | behavior on failure |
|---|---|---|
| `startup` | Determines whether startup is complete. Required if there's heavy init work (DB migration / cache warmup) | On failure, **kill and restart** |
| `liveness` | Health check. **Only catches deadlocks / hangs** | On failure, **kill and restart** |
| `readiness` | Whether traffic can be accepted. Reflects connectivity to dependencies (DB / cache) | On failure, **removed from the Service** (not killed) |

### Best practices
- **Keep liveness minimal**: don't check internal app state / dependent DBs. Only "does the process respond"
  - If liveness checks the DB, a DB outage causes all pods to restart, making things worse
- **readiness may include dependencies**: reflect the health of DB connections / cache connections / dependent services
- **Use the startup probe to avoid tuning liveness's `initialDelaySeconds`**: for slow-starting apps, give it grace time via startup, and keep liveness's `failureThreshold` short
- Have a dedicated endpoint for each probe (`/healthz` / `/readyz` / `/startupz`)

Detection signals:
- liveness hits the DB
- All three probes use the same endpoint
- `initialDelaySeconds` is abnormally large (e.g. 300s)

---

## 6. SecurityContext / Pod Security

### Required at the Pod / Container level

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

### Forbidden
- `privileged: true`
- `hostNetwork: true` / `hostPID: true` / `hostIPC: true`
- `hostPath` mounts (especially `/` / `/etc` / `/var/run/docker.sock`)
- `runAsUser: 0` (root)
- `allowPrivilegeEscalation: true`
- Elevated capabilities such as `capabilities.add: ["SYS_ADMIN"]`

### Pod Security Admission (PSA)
Enforce **restricted** / **baseline** / **privileged** via a namespace label. Use `restricted` for production / general workloads:

```yaml
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
```

Detection signals:
- Missing `securityContext` / use of `hostPath` / running as root / `capabilities.drop` not specified

---

## 7. RBAC (least privilege)

### Start from default deny
- **Always specify** a ServiceAccount explicitly (don't use the default SA)
- If the pod doesn't need to call the K8s API, set `automountServiceAccountToken: false`
- Role / ClusterRole should include **only the necessary verbs / resources**

### Forbidden
- `verbs: ["*"]` / `resources: ["*"]` / `apiGroups: ["*"]`
- Binding `cluster-admin` (don't grant it to people, let alone to SAs)
- Broad ClusterRoleBindings (first consider whether a Role + RoleBinding scoped to a namespace would suffice)

### Automatic token mounting
- Only when necessary, use a short-lived projected token (TokenRequest API)

Detection signals:
- `serviceAccountName` not specified (using the default)
- Wildcard verb / resource in a ClusterRole
- Using a ClusterRoleBinding when a RoleBinding would suffice

---

## 8. NetworkPolicy

### Introduce default deny

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]
```

Add one **default deny ingress / egress** policy per namespace, and open up necessary traffic with allow rules.

### Common pitfalls
- **Forgetting egress to DNS (kube-dns)** → name resolution breaks and all pods die. Always allow it:
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
- Leaving egress fully open (`{}`) can't prevent data exfiltration
- Without a network policy controller (Calico / Cilium, etc.) in the cluster, NetworkPolicy is **ignored**. Confirm the prerequisite is in place

Detection signals:
- A namespace with no NetworkPolicy at all / fully open egress / missing DNS allow rule

---

## 9. Pod / Workload design

### Deployment vs StatefulSet vs DaemonSet vs Job
- **stateless app** → Deployment
- **Needs stable identity / persistent volumes** → StatefulSet (DB / Kafka / etcd, etc.)
- **One pod per node** → DaemonSet (log collector / node exporter)
- **Runs to completion once / runs periodically** → Job / CronJob

### Pod design
- 1 Pod = 1 main process. Don't cram multiple processes into a single container
- Only add a sidecar (proxy / log shipper) **when its role is clear**. Don't add one just because
- Limit init containers to **work that's only needed before startup** (migrations / fetching config)

### Replicas / availability
- Production Deployments should have `replicas >= 2` + **a PodDisruptionBudget**:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
spec:
  minAvailable: 1  # or maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: my-app
```

- If the cluster spans multiple zones, spread across zones with **topologySpreadConstraints**
- Keep `maxUnavailable` conservative so all pods don't go down simultaneously during a rolling update

### Graceful shutdown
- Match `terminationGracePeriodSeconds` to the cleanup time needed after SIGTERM (default 30s)
- On the app side, set readiness to false upon receiving SIGTERM, then drain (a pattern of sleeping in a preStop hook)

Detection signals:
- `replicas: 1` in production / no PDB / in-flight requests get dropped due to no preStop hook

---

## 10. ConfigMap / Secret

### ConfigMap
- Configuration values go in ConfigMap, secrets go in Secret (don't mix them)
- Bulk-injecting with `envFrom` bloats the environment / causes name collisions. **Use `valueFrom` for only the keys you need**
- Use immutable ConfigMaps (`immutable: true`) to suppress hot reload (reduces controller load)

### Secret
- base64 is **not encryption**. Without encryption-at-rest configured, a Secret is effectively plaintext in etcd
- In production, use **External Secrets Operator / Sealed Secrets / Vault / a cloud secret manager**
- Injecting a Secret as an environment variable makes it visible via `/proc/<pid>/environ` → for sensitive values, consider **volume mount + readOnly + tmpfs**
- Don't commit Secrets to Git (this applies even if already base64-encoded)

Detection signals:
- A key that looks like a password / token in a ConfigMap
- A Secret committed as **plain YAML**
- The same Secret value used across all environments

---

## 11. Image / Tag / Pull policy

### Tag
- **Don't use** `:latest` (not reproducible / can't track what was deployed during a rolling update)
- Combining a semver tag (`v1.2.3`) with a digest (`@sha256:...`) is safest
- Defaulting production manifests to a **digest pin** keeps them safe even if the tag gets overwritten

### Pull policy
- If the tag is `:latest`, it implicitly becomes `Always` → when pinning a tag, **explicitly write `IfNotPresent`**
- Explicitly set `imagePullSecrets` for private registries

### Image size / vulnerabilities
- Default to a distroless / chainguard / minimal base
- Use multi-stage builds so build dependencies aren't left behind
- Scan for CVEs with `trivy` / `grype`, and build SBOM generation into CI

Detection signals:
- `:latest` tag
- pull policy not specified + a fixed tag
- An image that runs as root

---

## 12. Kustomize (default) / Helm

**Kustomize is the default.** Reasons:
- It reads as plain YAML (no template-engine quirks)
- Overlays are sufficient for handling environment differences in our own apps
- Partial overrides can be done locally via patches, without needing to expose every knob through values

Use Helm only **when importing an OSS chart** / **when distribution is required**.

### Kustomize conventions
- A `base/` + `overlays/{dev,staging,prod}/` structure
- Keep **patches minimal** in overlays. For plain values, override via `configMapGenerator` / `secretGenerator`
- Check the production diff with `kustomize build overlays/prod | kubectl diff -f -` → render with `kustomize build` in CI
- Default to **strategic merge patch (`patches:` with `target:`)**. Use JSON Patch only for more forceful changes
- Attach labels to all resources in bulk via `commonLabels` / `commonAnnotations`
- Use `namePrefix` / `nameSuffix` for environment-specific suffixes (watch out for selector immutability)
- Don't pollute the parent `base/` with environment-specific values (keep base environment-agnostic)

### Conventions when using Helm
- `apiVersion: v2` in `Chart.yaml`
- Distinguish chart version from app version (`version` / `appVersion`)
- Make values.yaml **commented / typed** so users can read it
- Render with `helm template` → check with `kubectl diff` before running `helm upgrade`
- Even when pulling in an OSS chart, a structure where Kustomize's `helmCharts:` inflates values → overlay patch is easy to work with

Detection signals:
- About to cut a new Helm chart for an in-house app (first consider whether Kustomize would suffice)
- Patches bloating in an overlay (a signal to reconsider the base design)
- base polluted with environment-specific values

---

## 13. Lint / Validation

Always wire these into CI:

| tool | role |
|---|---|
| `kubeconform` | schema validation (consistency of apiVersion / kind) |
| `kube-linter` | configuration anti-patterns (no probes / privileged / no resources, etc.) |
| `conftest` (OPA / Rego) | custom policies (enforcing internal conventions) |
| `trivy config` | detects security misconfigurations in manifests |
| `kustomize build` | renderability + feeds the result into kubeconform / kube-linter |
| `pluto` | detects deprecated APIs |

**At minimum**, include `kubeconform` + `kube-linter` + `trivy config`. Feeding the output of `kustomize build` into these in CI is the standard flow.

---

## 14. Observability

- Expose a **metrics endpoint** (`/metrics` in Prometheus format) on every workload
- Wire it up via a `prometheus.io/scrape` annotation on the pod, or a ServiceMonitor (Prometheus Operator)
- Emit logs to stdout / stderr **as structured JSON**. Don't write to files (ephemeral containers disappear)
- For traces, use the OpenTelemetry SDK + a sidecar / DaemonSet collector → backend (Tempo / Jaeger)
- Precompute important SLIs with a **Recording Rule** (avoid heavy computation at request time)
- Don't put high-cardinality labels / tags into metrics (it will break the time-series DB)

---

## 15. Cost / efficiency

- Unnecessary resource requests are a hidden cost. Base them on measured values from the VPA recommender
- Use HorizontalPodAutoscaler (`autoscaling/v2`) to **track load**. Consider custom metrics in addition to CPU
- Use Cluster Autoscaler / Karpenter for automatic node scaling
- Use Spot / Preemptible nodes for batch / dev (also conditionally for stateless production workloads)

---

## 16. Related skills / agents

- security review → `security-review-local` skill
- docs (ADR / Runbook / Design) → `tech-docs-writer` skill
- layer boundaries / responsibilities (app side) → `ddd-hexagonal` skill
- Go app conventions → `go-style` / `go-test` skill

---

## Checklist (for manifest review)

- [ ] `apiVersion` is stable / not deprecated
- [ ] recommended labels (`app.kubernetes.io/*`) are present on all resources
- [ ] `resources.requests` / `limits` are set (memory limit required)
- [ ] `liveness` / `readiness` / `startup` are used appropriately (liveness doesn't check dependencies)
- [ ] `securityContext` sets `runAsNonRoot` / `readOnlyRootFilesystem` / `capabilities.drop: ["ALL"]`
- [ ] `serviceAccountName` is explicit + RBAC is minimal + `automountServiceAccountToken: false` (if not needed)
- [ ] NetworkPolicy has default deny + necessary allows (watch out for forgetting the DNS allow)
- [ ] production `replicas >= 2` + PDB + topologySpreadConstraints
- [ ] image tag is pinned (digest recommended) + `pullPolicy` is explicit + distroless-based image
- [ ] Secrets are not committed in plaintext (External Secrets / Sealed Secrets / Vault)
- [ ] Kustomize's base is environment-agnostic / overlay patches are minimal
- [ ] `kubeconform` / `kube-linter` / `trivy config` are run in CI
