---
name: ddd-architecture
description: The house conventions for DDD. **Covers both the clean (Hexagonal) and layered (classic N-tier) styles; the applicable scope changes with the style.** Covers layer boundaries / dependency direction / Port-Adapter / ACL / Aggregate / Repository / DTO conversion / cross-cutting concerns. A reference, not a procedural skill.
when_to_use: When a question like 「層が曖昧」「責務違反では」「port の切り方」「is this the same as layered?」 comes up. During design review, when judging layer boundaries, or when generating refactor candidates. Referenced from `code-refactor-advisor` / `go-feature-tdd`.
---

> **Source of truth:** `claude/ja/skills/ddd-architecture/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# ddd-architecture

The house conventions for DDD, plus detection signals. **Covers both the clean (Hexagonal) and layered (classic N-tier) styles** — establish the style in §0 before reading on. The basis for design judgment / review / refactor candidate generation.

**General knowledge is not restated here** (the definitions of Entity and Value Object, what the Repository pattern is, etc.) — this skill carries the house layout and choices, where the YAGNI line sits, and the signals for catching violations via grep.

## 0. First, establish the architecture style

**DDD comes in a form that requires DIP (Clean / Hexagonal) and one that does not (Layered).** The tactical patterns (Entity / VO / Aggregate / Repository / UL / ACL) hold under both, and **Layered is not a degraded Clean but a legitimate variant** (Evans' original is Layered). Reviewing without establishing the style produces "dependency direction violation" and "missing Port abstraction" findings against code that is correct under Layered.

| style | Dependency direction | Port (who owns the interface) | Scope of this skill |
|---|---|---|---|
| **clean** (= Hexagonal) | Always inward; outward communication goes through a Port | The inside (Application) defines it, the outside (Adapter) implements it | All sections |
| **layered** (= classic N-tier / Evans' original) | An upper layer may reference a lower layer's concrete types directly | **Not needed.** A concrete Repository implementation suffices | **§2 and the DIP items in §11 are excluded** |

**How to determine it**:

1. If the target repo's `CLAUDE.md` / `.claude/rules/` declares a style, follow that
2. Otherwise infer from the layout — the equivalent of `application/ports/` present → clean; absent → layered
3. If still undecidable, **assume layered and state the assumption in the verdict** (the safe side = the side that doesn't over-report)

**The essential difference is whether the dependency direction is inverted**, not that the physical arrangement looks like stacked layers.

**Clean Architecture and Hexagonal are effectively synonymous** (the same mechanism: the Dependency Rule = inward dependency, with Ports defined on the inside and implemented on the outside). The four rings map onto Domain / Application / Interfaces+Adapters / cmd in the table below.

## 1. Layer definitions

| Layer | path | Responsibility | Inner layers it may depend on |
|---|---|---|---|
| **Domain** | `internal/domain/` | Entity / VO / Aggregate / Domain Service / Domain Event / sentinel errors. **Holds no external dependencies** | (innermost) |
| **Application** | `internal/application/` | Use case orchestration / Application Service / Ports (interface definitions) / DTOs | Domain |
| **Interfaces** | `internal/interfaces/` | Inbound adapters (gRPC / HTTP handlers / CLI / interceptors / wire shape ⇄ DTO conversion) | Application + Domain |
| **Adapters** | `internal/adapters/` | Outbound adapters (DB / vendor SDKs / external APIs; implement Ports) | Application (to implement Ports) + Domain (to reference types) |

**clean**: dependencies always point inward. Communication with the outside goes **through Ports** (defined by Application, implemented by Adapters). When inner → outer communication is needed, invert it by having the domain publish a Domain Event that the outside subscribes to.

**layered**: an upper layer may reference a lower layer's concrete types directly. **Keeping Domain free of external SDKs and frameworks holds under both styles** (Evans' domain isolation — a separate requirement from DIP).

## 2. Port-Adapter — **clean only**

> **Under layered this entire section does not apply.** Application may use a concrete Repository implementation directly, and extracting an interface is an optional choice for when you intend to swap it or need a fake in tests. Never report the absence of a Port as a violation.

- **Ports are vendor-neutral.** Don't leak SDK-specific types (pass `[]float32`; never let `openai.EmbeddingResponse` appear in a port shape)
- Keep port signatures to the **minimum necessary methods** (a single-method port is fine)

```go
// Application layer: port definition
type EmbeddingPort interface {
    Embed(ctx context.Context, req EmbedRequest) (*EmbedResult, error)
}

// Adapter layer: port implementation (SDK-specific logic stays inside the adapter)
package openai
func (a *Adapter) Embed(ctx context.Context, req ports.EmbedRequest) (*ports.EmbedResult, error) { ... }
```

## 3. Anti-Corruption Layer (ACL)

Translate **vocabulary / types / error models** at the boundary with external systems and vendors. At the adapter's boundary, convert vendor-specific → port-neutral and **wrap vendor-specific errors into port sentinel errors**. The same applies in the other direction (wire shape → application DTO).

```go
sdkResp, err := a.client.Embeddings.New(ctx, openai.EmbeddingNewParams{...})
if err != nil {
    return nil, fmt.Errorf("openai: %w: %w", ports.ErrEmbeddingProviderUnavailable, err)
}
return toPortResult(sdkResp), nil
```

## 4. Ubiquitous Language

Domain terms use **the same vocabulary across business, docs, and code** (if the docs say "knowledge chunk", the code says `Chunk`). Wire shapes (proto field names / JSON keys) align to the UL too. When vocabulary is split across people, **unify it in the docs first** (settle it in an ADR).

**Detect**: one concept under different names per package (`User` / `Member` / `Account` mixed) / divergence between proto field names and Go struct field names / docs and code using different terms

## 5. Where the YAGNI line sits

- **Simple data with no business rule is fine as a plain struct.** Don't over-apply Aggregates / Value Objects
- Start prototypes with plain structs like `Hit{ChunkID, Text, ...}` and promote them once a business rule appears
- If you do carve out an Aggregate, **the Aggregate Root protects the business invariant** (the shape where `Document.AddChunk(c)` guarantees chunk_sequence continuity)
- **Domain Events are also easy to over-introduce** — unnecessary in the prototype phase; consider them once audit / metrics / integrations accumulate

**Detect**: internal entities edited directly from outside, bypassing the Aggregate Root

## 6. Application Service vs Domain Service

- **Application Service**: orchestration per use case (calling multiple ports / entities to accomplish one business operation). Dependencies (the ports + logger) are injected
- **Domain Service**: domain logic that doesn't fit inside a single entity. Takes only domain objects
- Both are stateless

**Detect**: a Domain Service importing a port (dependency direction violation) / an Application Service that only validates (no business orchestration — it could fold into the handler)

## 7. Repository

The abstraction over a DB / persistent store (a special form of port). **Scope it per entity** (`ChunkRepository` / `DocumentRepository`); a search-only read model may be a separate repository. Keep it **vendor-neutral** — don't leak SQL, table names, or SDK details.

**Detect**: SQL strings in a repository's arguments or return values / a repository containing business logic rather than CRUD (responsibility confused with Application Service)

## 8. DTO conversion

Insert a conversion at each layer boundary: wire shape ⇄ Application DTO at the `Interfaces` boundary, DTO ⇄ Domain entity at the `Application` boundary, Domain ⇄ vendor SDK shape at the `Adapters` boundary (= the ACL). Conversion helpers live in the boundary layer and are **pure functions** (easy to test).

**Detect**: a Domain entity carrying proto / JSON tags (wire shape and domain shape mixed) / a wire shape flowing through the application layer unconverted

## 9. Cross-cutting concerns

Logging / Tracing / Auth / Rate Limit / Recovery live **at the interfaces / adapters boundary** (a `UnaryServerInterceptor` for gRPC, middleware for HTTP). **Never import them directly into the Application / Domain layers.** Context keys and the logger factory go in `internal/observability/` for each interceptor to consume.

**Detect**: `slog.Info(...)` called directly inside an Application Service / Domain Service / an auth check written inline in a handler

## 10. Configuration injection (functional option + ConfigMap)

Expose overrides in **three tiers**:

| Priority | Path | Purpose |
|---|---|---|
| 1 | **default const** (`defaultXxx`, hardcoded) | A safe base value |
| 2 | **functional option** (`WithXxx(...)` injected at construction) | Per-deployment override; the wiring path for global configuration |
| 3 | **proto field** (per request) | **The exception.** Only at the "we genuinely need per-request handling" level (requires user approval) |

Normal operation is (1) + (2). **Extending the proto is a last resort.**

```go
const defaultRenderDPI = 150
func WithDPI(dpi int) PDFOption { return func(pp *PDFParser) { pp.dpi = dpi } }

// cmd/api-server/main.go (wiring)
parser := adapters.NewPDFParser(vlm, adapters.WithDPI(cfg.Parser.DPI)) // value from the ConfigMap
```

**Detect**: no `defaultXxx` const, with numeric literals scattered through the code / `WithXxx(...)` not exported, so cmd can't override / public adapter struct fields (direct assignment by callers breaks immutability) / adapter-internal values exposed as proto fields

## 11. How to detect

**Three distinct channels. Don't conflate them.**

### A. The linter catches it

**Layer boundary violations can be enforced with `depguard` (golangci-lint)** — more reliable than grepping for them every time. **The rules you declare differ by style**:

```yaml
linters-settings:
  depguard:
    rules:
      # Both styles: domain isolation
      domain:
        files: ["**/internal/domain/**"]
        deny:
          - pkg: "**/internal/adapters/**"
            desc: domain must not depend on infrastructure
          - pkg: "**/internal/interfaces/**"
            desc: domain must not depend on presentation

      # clean only: enforcing DIP. Do not add this rule under layered
      application:
        files: ["**/internal/application/**"]
        deny:
          - pkg: "**/internal/adapters/**"
            desc: go through a Port (direct concrete adapter imports are forbidden)
```

**The `application` rule is clean-only.** Adding it to a layered repo rejects legitimate dependencies, so leave it out.

Once adopted, the linter catches the corresponding greps, dropping them out of review. In repos that haven't adopted it, catch them via B.

### B. Catch it with grep

```bash
# [both styles] Domain → outward import (domain isolation)
grep -rn 'import.*adapters\|import.*interfaces' internal/domain/

# [clean only] Application → concrete adapter import (not through ports)
#   A legitimate dependency under layered. Don't run it there
grep -rn 'import.*adapters/[a-z]\+/' internal/application/ | grep -v 'application/ports'

# [both styles] Adapter → interfaces import (sideways dependency)
grep -rn 'import.*interfaces' internal/adapters/

# SDK-specific types in a port shape (adjust vendor names to the target repo)
grep -rnE '(pineconego|openaigo|aws)\.' internal/application/ports/

# Direct logger calls inside an Application Service (cross-cutting leaking in)
grep -rnE 'slog\.(Info|Error|Warn|Debug)' internal/application/ | grep -v 'logger\.'

# SDK types imported into a handler / service
grep -rnE '(pineconego|openaigo)' internal/interfaces/ internal/application/

# SQL strings in a repository signature
grep -rnE '(SELECT|INSERT|UPDATE|DELETE)' internal/application/ports/

# Domain entities carrying wire tags (layers mixed)
grep -rnE '`(json|protobuf|yaml):' internal/domain/
```

**Replace the vendor names (`pineconego` etc.) with the target repo's actual dependencies** — don't hardcode them in the skill (take them from `MEMORY.md` / `go.mod`).

### C. Requires judgment (not greppable)

- **[clean only] Whether an adapter implements a Port** — without one its role is unclear and it gets imported ad hoc. Interface satisfaction requires following the types
- **[clean only] Whether application code receives an adapter as a concrete type** — judge by whether a fake can be injected in tests. **Under layered, receiving a concrete type is normal** — don't report it
- **Whether vendor-specific errors leak without a sentinel wrap** — requires following the error flow
- **Where the YAGNI line sits** — is something that could be a plain struct being made an Aggregate / does the Aggregate Root actually protect the invariant
- **Ubiquitous Language drift** — comparing vocabulary between docs and code cannot be mechanized

## Identifying false positives

The following are **not violations** even when a detection signal fires:

- **Generated code**: files containing `Code generated by ... DO NOT EDIT.` at the top (fix the source schema instead)
- **Language / library idioms**: fixed signatures and the like. These take precedence over this skill's rules
- **Deliberate design exceptions**: decisions whose intent is stated in code or docs
- **Public API compatibility**: exported symbols that can't change for backward compatibility

When in doubt, don't exclude it — flag it as a "false positive candidate" and seek the user's judgment.

## Output

When called from `code-refactor-advisor`, return a **per-layer responsibility map** (file × layer × responsibility), a **list of layer-boundary / dependency-direction violations** (file:line + what's violated), findings on **missing Port / Adapter / ACL**, and **UL drift**, along with a remediation stance (move layers / extract a port / add a DTO conversion layer, etc.).
