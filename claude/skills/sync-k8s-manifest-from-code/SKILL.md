---
name: sync-k8s-manifest-from-code
description: Propagates interface changes (config / env / port / probe / resources) in a code repo (Go application) to the K8s Kustomize manifest repo (through detection + edits across 3 environments + `git add`; does not commit or push). Target repo information is fetched from the reference memory in MEMORY.md.
when_to_use: When propagating interface changes on the code side (config / env / port / probe / resource) into k8s manifests.
allowed-tools: Read, Edit, Grep, Glob, Bash(git status:*, git diff:*, git add:*, ls:*, find:*, cat:*)
---

> **Source of truth:** `claude/ja/skills/sync-k8s-manifest-from-code/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# sync-k8s-manifest-from-code

A skill that semi-automates **code → manifest direction** sync (detect → Edit → stage) for setups where the application code repo and the K8s Kustomize manifest repo are separate. The reverse direction (manifest → code) is out of scope.

## Applicable pattern

Assumes a project matching the following:

- The code repo has a YAML config schema (struct) with a design that **rejects unknown fields at startup** (i.e., ConfigMap drift immediately causes a crash)
- Required env vars (both secret and non-secret) are validated at startup (i.e., missing env vars cause `os.Exit(1)`)
- The manifest repo is structured as Kustomize `bases/` (= prod source of truth) + `overlays/{dev, stg, ...}/`
- Each service has config split like `config/{app.yaml, config.env, sealed-secret.yaml, secret.yaml}`

## Resolving the target project at startup (important)

This is a global skill, so **project-specific terms are not hardcoded into this SKILL.md**. At startup, fetch the following about the target project from the reference memory in MEMORY.md:

| Item to fetch | Example |
|---|---|
| code repo path | `~/.../some-code-repo` |
| manifest repo path + service directory | `~/.../some-mani-repo/<service-dir>` |
| config schema location | `internal/config/config.go` |
| env definition location | `internal/config/secrets.go` |
| config example | `cmd/<binary>/config.example.yaml` |
| binaries (sync behavior) | `[<A>: full sync, <B>: detect-warn]` |
| overlay structure | `[bases, overlays/dev, overlays/stg, ...]` |
| constraints / ordering | e.g., manifest-first → code-follows is mandatory |

If no corresponding reference memory is found, ask the user to obtain the information → propose it as a candidate to save as reference memory (don't write it immediately; get user approval first).

Example of a reference memory you might refer to:
- e.g., a reference memory like `[[<service>-sync]]`

## Detection logic (project-agnostic)

Based on the location information obtained from reference memory, read the following in the code repo (in priority order):

1. Fields added / changed / removed in the **config struct (YAML schema)**
   - Propagates to: `config/app.yaml` in all overlays
   - If the design rejects unknown fields, **manifest-first is mandatory**
2. **Env definitions** (required env added / renamed / removed)
   - Propagates to (secret): the key in `config/sealed-secret.yaml` (envFrom), or the key in `config/secret.yaml`
   - Propagates to (non-secret): `config/config.env`
   - If the design fails to start when unset, **manifest-first is mandatory**
3. Value / structure changes in the **config example**
   - Propagates to: the corresponding key in `config/app.yaml` for each environment
4. **Listen port / probe endpoint in main.go**
   - Propagates to: `bases/deployment.yaml` (containerPort, livenessProbe, readinessProbe) + `bases/svc.yaml` (port)
5. **Changes affecting resource consumption** (adding a heavy library / large cache / large buffer / changing parallelism)
   - Candidate propagation targets: `bases/{deployment, hpa, pdb}.yaml`
   - **Numeric values require user judgment** (the skill only flags; it never decides automatically)
6. **proto / API listen port** (gRPC / REST)
   - Propagates to: `bases/{deployment, svc}.yaml` ports
7. **Major dependency added to `go.mod`** (Redis / DB / external API client, etc.)
   - Propagates to: NetworkPolicy (flag only if absent) / Secret (add a key if new credentials are involved)
8. Changes to a **binary designated detect-warn** (as specified in reference memory)
   - Detection only, no Edit, emit a warning
9. **New binary** (a new addition under `cmd/<new>/`)
   - Detection only; initializing a new directory is out of scope; emit a warning

## Operation flow

1. **Pre-check**
   - Confirm the manifest repo's working tree is **clean** via `git status` (stop if dirty, don't mix in other work)
   - Confirm the target ref of the code repo (default = working tree HEAD)
   - Resolve the target project from reference memory
2. **Detect**
   - Extract differences using the detection logic above
   - Output the results as a summary table (which category / which value / candidate propagation target)
3. **Plan-present (waiting for user approval)**
   - Present the candidate propagation targets
   - For items where the choice of overlay to touch branches (e.g., resources), ask the **user to decide, presented in comparison form**
   - Always make the **manifest-first → code-follows ordering** explicit to the user (emphasize it when adding env vars / unknown fields)
4. **Edit**
   - Edit the approved changes into the manifest repo's working tree
   - Preserve the existing YAML / sealed-secret indentation, ordering, and comments
   - Respect existing overlay overrides (where an overlay overrides a value from `bases/`)
5. **Stage**
   - `git add` only the touched files, by specific path (the guard-bash.sh hook denies `git add -A` / `git add .`)
6. **Stop**
   - Output a summary of `git diff --staged`
   - The skill stops here; after the user reviews → commit & push separately via `/commit-push-branch`

## Constraints / out of scope

| Item | Treatment |
|---|---|
| commit / push / PR creation | **Never executed under any circumstance.** `git push` / `gh` are not included in allowed-tools |
| kubeseal (SealedSecret value encryption) | Out of scope. Only adds the key; the user runs kubeseal on the value later |
| Directory initialization for a new binary | Out of scope. Warning only |
| Reverse sync (manifest → code) | Treated as a separate skill (e.g., `.upstream-sha`-based operations) |
| Automatically deciding resource numbers | Out of scope. Heuristic flagging only; the user decides the final values |

## Handling detection gaps

Detection is heuristic, so always state explicitly at the end of the output **"areas that may not have been caught"**:

- New volume mounts / hostAlias / annotations
- NetworkPolicy / PodSecurityContext / SecurityContext details
- Sidecar / init container additions
- Annotation-based behavior changes (Argo Rollouts, Linkerd, Istio, etc.)

Add a one-line note: "there may be other affected areas; a visual check is recommended."

## Stop conditions on failure (don't proceed unilaterally)

If any of the following are detected, **stop and report to the user**:

- The manifest repo's working tree is dirty
- The code repo / manifest repo path cannot be resolved (no reference memory / the path has changed)
- The propagation target file doesn't exist (the overlay structure differs from what was expected)
- A change requiring user confirmation on security grounds (`Action: "*"` / `privileged` / `hostNetwork` / `hostPID` / expanding public exposure / granting a broad role to a service account)
- The SealedSecret's **value** (encrypted) needs to change
- A change limited to a detect-warn-designated binary that could still affect a full-sync-target binary

## Related

- The target project's reference memory (e.g., `[[<service>-sync]]`) — holds repo path / config location / binaries
- `commit-push-branch` skill — commit & push after this skill completes (cutting a branch + following past style)
- `security-review-local` skill — security-perspective review after editing the manifest (recommended to use together)
