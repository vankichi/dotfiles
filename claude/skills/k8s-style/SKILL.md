---
name: k8s-style
description: The house conventions for K8s manifests / workload design / RBAC / SecurityContext / NetworkPolicy / probes / resources / Kustomize / image operations. A reference, not a procedural skill.
when_to_use: When a question like 「K8s 的にどう」「manifest 規約」「RBAC 最小権限」「probe どう書く」 comes up. When authoring or reviewing manifests, or generating refactor candidates. Referenced from `code-refactor-advisor` / `security-review-local`.
---

> **Source of truth:** `claude/ja/skills/k8s-style/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# k8s-style

The house K8s conventions, plus detection signals for catching violations. Consulted as the basis for judgment when authoring / reviewing manifests or generating refactor candidates.

**General knowledge is not restated here** (Deployment vs StatefulSet, what each probe does, "base64 is not encryption", etc.) — this skill carries only the house's choices, the traps that cause incidents, and the signals that let you notice via grep.

## 1. Basic stance

- **Applying to production goes through CD (GitOps: ArgoCD / Flux) by default.** Running `kubectl apply` directly is taboo
- **Always check the diff with `kubectl diff`** before a change
- Don't leave behind resources created with imperative commands (`kubectl run` / `kubectl expose` / `kubectl edit`) — **state that doesn't exist in Git is taboo**
- 1 YAML = 1 resource, or one logical unit (Deployment + Service + HPA + PDB)

**Detect**: resources on the cluster that aren't in the manifests (drift) / mismatch between the `last-applied-configuration` annotation and Git

## 2. API version

Keep `apiVersion` on the latest stable (`apps/v1` / `batch/v1` / `networking.k8s.io/v1` / `autoscaling/v2` / `policy/v1`). `PodSecurityPolicy` is removed — migrate to **Pod Security Admission (PSA)**. Run `pluto` in CI to detect removed APIs.

## 3. Naming / Labels / Selectors

- Resource names are lowercase + `-` (RFC 1123), 63 characters or fewer. **Don't bake the environment into the name** (separate by namespace — `my-app` + namespace `prod`, not `my-app-prod`)
- Put `app.kubernetes.io/*` on every resource: `name` (required) / `instance`, `version`, `component`, `managed-by` (recommended) / `part-of` (optional)
- **A Deployment's `spec.selector.matchLabels` is immutable** — changing it later makes updates impossible. Stabilize a Service's selector on `name` + `instance`, and **never put volatile labels (commit SHA / build number) in a selector**
- Namespace custom annotations with reverse DNS (`example.com/my-key`). Don't hand-write controller-managed annotations (`kubectl.kubernetes.io/*` / `meta.helm.sh/*`)

**Detect**: uppercase / underscores in names / missing recommended labels / values that change on rolling deploy present in a selector

## 4. Resource requests / limits

- **Always set both requests and limits** (without them the pod gets BestEffort QoS and is killed first)
- **Use CPU limits with caution** (they cause throttling; running with requests only is a common pattern). **Always set a memory limit** (an OOM kill is safer than dragging down the whole node)
- `requests = limits` gives Guaranteed QoS (for important workloads)
- Don't guess at sizing — base it on **measured values** from `kubectl top` / Prometheus / the VPA recommender. Start conservative → observe and adjust

**Detect**: `resources:` empty / only `limits` / only `requests` / memory limits 10x requests or more (wasted headroom) / CPU limits under 100m with a latency requirement (guaranteed throttling)

## 5. Probes

Use the three appropriately (**pointing all of them at the same endpoint is an anti-pattern**). Give each its own endpoint (`/healthz` / `/readyz` / `/startupz`).

- **Keep liveness minimal**: don't look at internal app state or dependent DBs — only "does the process respond". **If liveness checks the DB, a DB outage restarts every pod and makes things worse**
- **readiness may include dependencies** (reflecting DB / cache / dependent service health)
- For slow-starting apps, **give grace time via the startup probe and keep liveness's `failureThreshold` short** (avoid the race of inflating liveness's `initialDelaySeconds`)

**Detect**: liveness hitting the DB / all three probes on the same endpoint / an abnormally large `initialDelaySeconds` (e.g. 300s)

## 6. SecurityContext / Pod Security

The house baseline:

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

**Forbidden**: `privileged: true` / `hostNetwork`, `hostPID`, `hostIPC` / `hostPath` mounts (especially `/`, `/etc`, `/var/run/docker.sock`) / `runAsUser: 0` / `allowPrivilegeEscalation: true` / elevated capabilities such as `capabilities.add: ["SYS_ADMIN"]`.

Enforce PSA via a namespace label; **use `restricted` for production and general workloads**:

```yaml
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
```

**Detect**: missing `securityContext` / `hostPath` in use / running as root / `capabilities.drop` unspecified

## 7. RBAC (least privilege)

- **Always specify a ServiceAccount** (don't use the default SA). Set `automountServiceAccountToken: false` for pods that never call the K8s API
- **Forbidden**: `verbs: ["*"]` / `resources: ["*"]` / `apiGroups: ["*"]` / binding `cluster-admin` / broad ClusterRoleBindings (first consider whether Role + RoleBinding can scope it to a namespace)
- Where a token is needed, shorten its life with a projected token (TokenRequest API)

**Detect**: `serviceAccountName` unspecified / wildcards in a ClusterRole / a ClusterRoleBinding where a RoleBinding would do

## 8. NetworkPolicy

Put one default-deny ingress / egress in each namespace and open only what's needed:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]
```

**Traps**:
- **Forgetting egress to DNS (kube-dns) kills name resolution and takes every pod down.** Always allow it:
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
- Leaving egress wide open (`{}`) fails to prevent data exfiltration
- **Without a network policy controller (Calico / Cilium etc.) in the cluster, NetworkPolicy is ignored.** Confirm it's deployed

**Detect**: a namespace with no NetworkPolicy at all / wide-open egress / missing DNS allow

## 9. Workload design

- 1 Pod = 1 main process. Add sidecars **only when the role is clear**. Limit init containers to work needed strictly before startup (migration / config fetch)
- Production Deployments run `replicas >= 2` + a **PodDisruptionBudget** (`minAvailable: 1`, etc.). With multiple zones, spread via **topologySpreadConstraints**, and keep `maxUnavailable` conservative during rolling updates
- **Graceful shutdown**: match `terminationGracePeriodSeconds` to the post-SIGTERM cleanup time, and have the app flip readiness to false on SIGTERM before draining (the preStop-hook sleep pattern)

**Detect**: `replicas: 1` in production / no PDB / in-flight requests dropped for lack of a preStop hook

## 10. ConfigMap / Secret

- Configuration in ConfigMaps, secrets in Secrets (never mixed). **Bulk injection via `envFrom` bloats the environment and causes name collisions** — inject only the keys you need with `valueFrom`
- Use `immutable: true` ConfigMaps to suppress hot reload and reduce controller load
- Production Secrets go through **External Secrets Operator / Sealed Secrets / Vault / a cloud secret manager**. **Secrets injected as environment variables are visible via `/proc/<pid>/environ`** — for sensitive material consider a volume mount + readOnly + tmpfs
- **Never commit Secrets to Git** (base64-encoded is no different)

**Detect**: password / token-like keys in a ConfigMap / a Secret committed as plain YAML / the same Secret value across all environments

## 11. Image / Tag

- **Don't use `:latest`.** A semver tag plus a digest (`@sha256:...`) is safest, and production manifests should **pin by digest** by default
- Once a tag is pinned, write `pullPolicy` **explicitly as `IfNotPresent`** (`:latest` implies `Always`)
- Default to distroless / chainguard / minimal bases. Don't leave build deps behind — use multi-stage builds. Scan for CVEs with `trivy` / `grype` and wire SBOM generation into CI

**Detect**: a `:latest` tag / a pinned tag with no `pullPolicy` / an image that runs as root

## 12. Kustomize (default) / Helm

**Kustomize is the default.** Rationale = it stays readable as YAML (no template-engine quirks) / overlays are enough for environment differences / partial overrides stay local via patches instead of poking holes through values. **Use Helm only when importing an OSS chart or when distribution is required.**

- Structure as `base/` + `overlays/{dev,staging,prod}/`. **Keep base environment-independent — never pollute it with environment-specific values**
- Keep overlay patches minimal. For values alone, override via `configMapGenerator` / `secretGenerator`
- Default to strategic merge patches (`patches:` with `target:`); reserve JSON Patch for stronger changes
- Apply labels in bulk with `commonLabels` / `commonAnnotations`. **Mind selector immutability** when using `namePrefix` / `nameSuffix`
- Check production diffs with `kustomize build overlays/prod | kubectl diff -f -`
- For OSS charts, inflating via Kustomize's `helmCharts:` then patching in an overlay is the easiest arrangement

**Detect**: cutting a new Helm chart for an in-house app (check whether Kustomize suffices first) / bloated overlay patches (a signal to revisit the base design) / a base polluted with environment values

## 13. Lint / Validation (required in CI)

| tool | Role |
|---|---|
| `kubeconform` | Schema validation |
| `kube-linter` | Configuration anti-patterns (no probes / privileged / no resources) |
| `trivy config` | Security misconfiguration in manifests |
| `conftest` (OPA / Rego) | Enforcing in-house policy |
| `pluto` | Detecting removed APIs |

**At minimum, adopt `kubeconform` + `kube-linter` + `trivy config`.** Piping `kustomize build` output into them is the standard flow.

## 14. Observability

Emit logs **to stdout / stderr as structured JSON** (never to files — ephemeral containers vanish). Give every workload a metrics endpoint, wired via a ServiceMonitor or a `prometheus.io/scrape` annotation. **Don't put high-cardinality labels in metrics** (it destroys the time-series DB). Precompute important SLIs with Recording Rules.

## Checklist (for manifest review)

- [ ] `apiVersion` is stable / not deprecated
- [ ] `app.kubernetes.io/*` present on every resource
- [ ] `resources.requests` / `limits` set (memory limit required)
- [ ] liveness / readiness / startup used appropriately (liveness doesn't touch dependencies)
- [ ] `runAsNonRoot` / `readOnlyRootFilesystem` / `capabilities.drop: ["ALL"]`
- [ ] `serviceAccountName` explicit + minimal RBAC + `automountServiceAccountToken: false` where unneeded
- [ ] NetworkPolicy default deny + the necessary allows (**watch out for the missing DNS allow**)
- [ ] Production `replicas >= 2` + PDB + topologySpreadConstraints
- [ ] Image pinned by digest + explicit `pullPolicy` + distroless-style base
- [ ] No Secrets committed in plaintext
- [ ] Kustomize base is environment-independent / overlay patches are minimal
- [ ] `kubeconform` / `kube-linter` / `trivy config` run in CI
