---
name: ddd-clean-architecture
description: Reference skill for DDD + Clean Architecture (in Go, effectively synonymous with Hexagonal / Ports-and-Adapters). Covers layer boundaries / dependency direction / Port-Adapter / ACL / Aggregate / Repository / DTO conversion / cross-cutting concerns. Consult it for questions like 「層曖昧」「責務違反」「port の切り方」「is this the same as layered?」or during design review. Not a procedural skill.
---

> **Source of truth:** `claude/ja/skills/ddd-clean-architecture/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# ddd-clean-architecture

The house conventions for DDD + Clean Architecture, plus detection signals. Consulted as the basis for design judgment / review / refactor candidate generation.

**General knowledge is not restated here** (the definitions of Entity and Value Object, what the Repository pattern is, etc.) — this skill carries the house layout and choices, where the YAGNI line sits, and the signals for catching violations via grep.

> **Clean Architecture and Hexagonal are effectively synonymous** (the same mechanism: the Dependency Rule = inward dependency, with Ports defined on the inside and implemented on the outside). The four rings map onto Domain / Application / Interfaces+Adapters / cmd in the table below.
>
> **classic Layered (N-tier) is a different thing**: Layered permits the Business layer to import concrete Data Access types directly and does not require DIP. The "Application → concrete adapter direct import" this skill forbids is not a violation under Layered. **The essential difference is whether the dependency direction is inverted**, not that the physical arrangement looks like stacked layers.

## 1. Layer definitions

| Layer | path | Responsibility | Inner layers it may depend on |
|---|---|---|---|
| **Domain** | `internal/domain/` | Entity / VO / Aggregate / Domain Service / Domain Event / sentinel errors. **Holds no external dependencies** | (innermost) |
| **Application** | `internal/application/` | Use case orchestration / Application Service / Ports (interface definitions) / DTOs | Domain |
| **Interfaces** | `internal/interfaces/` | Inbound adapters (gRPC / HTTP handlers / CLI / interceptors / wire shape ⇄ DTO conversion) | Application + Domain |
| **Adapters** | `internal/adapters/` | Outbound adapters (DB / vendor SDKs / external APIs; implement Ports) | Application (to implement Ports) + Domain (to reference types) |

Dependencies always point inward. Communication with the outside goes **through Ports** (defined by Application, implemented by Adapters). When inner → outer communication is needed, invert it by having the domain publish a Domain Event that the outside subscribes to.

## 2. Port-Adapter

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

## 11. Detection signals (grep)

| Violation | grep |
|---|---|
| Domain → outward import | `grep -r 'import.*adapters\|import.*interfaces' internal/domain/` |
| Application → concrete adapter import | `grep -r 'import.*adapters/[a-z]\+/' internal/application/ \| grep -v 'application/ports'` |
| Adapter → interfaces import | `grep -r 'import.*interfaces' internal/adapters/` |
| SDK-specific types in a port shape | `grep -rn 'pineconego\.\|openaigo\.\|aws\.' internal/application/ports/` |
| Direct logger calls in an Application Service | `grep -rn 'slog\.Info\|slog\.Error' internal/application/ \| grep -v 'logger\.'` |
| SDK types imported into a handler / service | `grep -rn 'pineconego\|openaigo' internal/interfaces/ internal/application/` |
| SQL strings in a repository | `grep -rn 'SELECT\|INSERT\|UPDATE\|DELETE' internal/application/ports/` |

Other signals: an adapter that implements no Port (its role is unclear and it gets imported ad hoc) / application code receiving an adapter as a concrete type (no fake can be injected in tests) / vendor-specific errors leaking into the application layer without a sentinel wrap.

## Identifying false positives

The following are **not violations** even when a detection signal fires:

- **Generated code**: files containing `Code generated by ... DO NOT EDIT.` at the top (fix the source schema instead)
- **Language / library idioms**: fixed signatures and the like. These take precedence over this skill's rules
- **Deliberate design exceptions**: decisions whose intent is stated in code or docs
- **Public API compatibility**: exported symbols that can't change for backward compatibility

When in doubt, don't exclude it — flag it as a "false positive candidate" and seek the user's judgment.

## Output

When called from `code-refactor-advisor`, return a **per-layer responsibility map** (file × layer × responsibility), a **list of layer-boundary / dependency-direction violations** (file:line + what's violated), findings on **missing Port / Adapter / ACL**, and **UL drift**, along with a remediation stance (move layers / extract a port / add a DTO conversion layer, etc.).
