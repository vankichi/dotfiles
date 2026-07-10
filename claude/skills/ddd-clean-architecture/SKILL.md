---
name: ddd-clean-architecture
description: Reference skill for DDD + Clean Architecture (in Go, effectively synonymous with Hexagonal / Ports-and-Adapters). Covers layer boundaries / dependency direction / Port-Adapter / ACL / Aggregate / Repository / DTO conversion / cross-cutting concerns. Consult it for questions like 「層曖昧」「責務違反」「port の切り方」「is this the same as layered?」or during design review. Not a procedural skill.
---

> **Source of truth:** `claude/ja/skills/ddd-clean-architecture/SKILL.md` (Japanese). To update, edit the Japanese source first, then re-translate this file into English.

# ddd-clean-architecture

A reference skill collecting the idioms and principles of DDD + Clean Architecture. Consult it as a criterion for design decisions, reviews, and identifying refactor candidates.

> **Clean Architecture vs. Hexagonal**: When implemented in Go, the two are effectively synonymous (same Dependency Rule: dependencies point inward, the inner layer defines Ports, the outer layer implements them). Clean Architecture's four rings (Entities / Use Cases / Interface Adapters / Frameworks & Drivers) map directly onto Domain / Application / Interfaces+Adapters / cmd in the table below.
>
> **Not the same as classic Layered (N-tier)**: Layered architecture allows the Business layer to import concrete Data Access types directly and does not require the Dependency Inversion Principle. What §2/3 of this skill flag as a violation ("Application directly importing a concrete adapter") is not a violation under plain Layered. In Go, the layout looking like "stacked layers" is just physical placement — what actually distinguishes it is whether the dependency direction is inverted.

## Applicability

- Projects that adopt DDD + Clean Architecture (`internal/{domain,application,interfaces,adapters}/` layout)
- Referenced by the code-refactor-advisor agent
- Situations involving decisions about layer boundaries / port design / how to split adapters

## 1. Layer definitions

| Layer | path | Responsibility | Inner layers it may depend on |
|---|---|---|---|
| **Domain** | `internal/domain/` | Entity / Value Object / Aggregate / Domain Service / Domain Event / sentinel errors. **Has no external dependencies** (pure logic) | (innermost layer, no dependencies) |
| **Application** | `internal/application/` | Use case orchestration / Application Service / Port (interface definitions) / DTO | Domain |
| **Interfaces** | `internal/interfaces/` | Inbound adapters (gRPC handler / HTTP handler / CLI / interceptors / wire shape ⇄ application DTO conversion) | Application + Domain |
| **Adapters** | `internal/adapters/` | Outbound adapters (DB / vendor SDK / external API implementations, implement Ports) | Application (to implement Ports) + Domain (to reference types) |

Detection signals:
- Domain imports adapter / application (dependency direction violation)
- Adapter imports interfaces (lateral dependency, prevents reuse)
- Application directly imports an adapter (= missing port abstraction)

## 2. Dependency direction (the inward-pointing principle)

```
Interfaces ──┐                                  ┌── Adapters
             ├──> Application ──> Domain <──────┤
             └─────────────────────────────────┘
```

- **Dependencies always point inward** (outer → inner). The inner layer (Domain) knows nothing about the outer layers (Application / Adapters)
- Communication with the outside happens via a **Port (interface)**. Application defines the Port, Adapter implements it
- When inner → outer communication is needed, invert it with a mechanism such as **Domain Event + subscription on the outside**

Detection signals:
- `import ".../adapters/..."` / `import ".../interfaces/..."` inside Domain code
- `import ".../adapters/concrete-vendor"` inside Application code (= direct import of a concrete adapter, bypassing the port)

## 3. Port-Adapter pattern

- **Port** = an interface (defined in the Application layer). Example: `EmbeddingPort` / `VectorStorePort`
- **Adapter** = an implementation of a Port (in the Adapters layer). Example: `openai.Adapter` (= implements `EmbeddingPort`) / `pinecone.Adapter` (= implements `VectorStorePort`)
- Ports are **vendor-neutral**. They must not leak SDK-specific types (e.g. pass `[]float32`; never let `openai.EmbeddingResponse` appear in a port shape)
- A Port's signature should have **only the minimum necessary methods**. Don't add methods to the port that the adapter doesn't use (a single-method port named with an `I` suffix or `xxxer` naming is fine)

Example:
```go
// Application layer: port definition
type EmbeddingPort interface {
    Embed(ctx context.Context, req EmbedRequest) (*EmbedResult, error)
}

// Adapter layer: port implementation
package openai
type Adapter struct { ... }
func (a *Adapter) Embed(ctx context.Context, req ports.EmbedRequest) (*ports.EmbedResult, error) {
    // SDK-specific logic stays contained within the adapter
}
```

Detection signals:
- SDK-specific types appear in a Port shape (`*openai.EmbeddingResponse` / `*pinecone.QueryResponse`, etc.)
- An Adapter does not implement a Port (= its role as an adapter is unclear, gets imported ad hoc and directly)
- Application code receives an adapter as a concrete type (= cannot be mocked, a fake cannot be injected in tests)

## 4. Anti-Corruption Layer (ACL)

- A translation layer that converts **vocabulary / types / exception models** at the boundary with external systems / vendors
- At the boundary inside the adapter, convert **vendor-specific → port-neutral** and wrap **vendor-specific errors → port sentinel errors**
- The same applies in the opposite direction (interface → application): convert wire shape (proto / JSON) → application DTO

Example:
```go
// ACL inside the adapter
func (a *Adapter) Embed(ctx context.Context, req ports.EmbedRequest) (*ports.EmbedResult, error) {
    sdkResp, err := a.client.Embeddings.New(ctx, openai.EmbeddingNewParams{...})
    if err != nil {
        return nil, fmt.Errorf("openai: %w: %w", ports.ErrEmbeddingProviderUnavailable, err)
    }
    // convert sdkResp.Data → []ports.Vector
    return toPortResult(sdkResp), nil
}
```

Detection signals:
- A handler takes/returns SDK types as arguments/return values (= missing ACL, application becomes vendor lock-in)
- The Application layer receives a `pinecone.Client` directly (not via a Port)
- Vendor-specific errors leak directly into the application layer / handler (no sentinel wrap)

## 5. Ubiquitous Language (UL)

- Domain terminology must use **the same vocabulary across business / docs / code**
- Example: if the docs call it a 「ナレッジチャンク」(knowledge chunk), the code should also use `Chunk` (avoid mixing aliases such as `Document` / `Item`)
- Align wire shapes (proto field names / JSON keys) with the UL as well
- If departments / stakeholders have diverging vocabulary → unify it in the docs first (fix the vocabulary via an ADR)

Detection signals:
- Different names for the same concept across packages (`User` / `Member` / `Account` / `Principal` mixed together)
- proto field names differ from Go struct field names (`product_ids` ⇔ `ProductIDList`)
- Terminology differs between docs and code (docs: 「コレクション」("collection") / code: `Index` and `Collection` mixed)

## 6. Aggregate / Entity / Value Object

- **Entity**: an object that has an identity (ID). E.g. `Chunk{ID, Text, ...}`
- **Value Object**: has no identity, judged by value equality. E.g. `Vector []float32` / `EmbedRequest{Inputs []string}`
- **Aggregate**: a consistency boundary. Internal entities are only manipulated via the Aggregate Root
- The Aggregate Root **protects business invariants**. Example: if `Document` is the root, `Document.AddChunk(c)` guarantees the continuity of chunk_sequence

Note:
- Over-applying Aggregate / Value Object modeling is YAGNI. **Simple data with no business rules** is fine as a plain struct
- During the Phase 1 prototype period, start with a plain struct like `Hit{ChunkID, Text, ...}` and promote it once business rules emerge

Detection signals:
- No distinction between Entity and Value Object (= everything is a plain struct, identity isn't handled via ID comparison)
- Internal entities are edited directly from the outside, skipping the Aggregate Root

## 7. Application Service vs Domain Service

- **Application Service**: orchestration at the use-case level. Achieves one business operation by calling multiple ports / domain entities
- **Domain Service**: domain logic that doesn't fit inside a single entity (operations between entities / domain rule validation)
- Both are stateless. Application Service receives injected dependencies (a set of ports + logger); Domain Service only receives domain objects

Example:
```go
// Application Service (recommended pattern)
type Service struct {
    embedding   ports.EmbeddingPort
    vectorStore ports.VectorStorePort
}
func (s *Service) Search(ctx, in SearchInput) (*SearchOutput, error) {
    // Embed → vector search → convert to hits (use case orchestration)
}
```

Detection signals:
- Domain Service imports a port (dependency direction violation)
- Application Service only does validation (= no business orchestration, could be folded into the handler)
- Application Service has only one method (= only a single use case; sometimes there's little value in making it a struct)

## 8. Repository pattern

- Abstraction over DB / persistent stores is the **Repository** (a specialized form of port)
- Split granularity per entity: `ChunkRepository` (CRUD on Chunk) / `DocumentRepository`
- Search-only / read models are sometimes split into a separate Repository (`ChunkSearchRepository`)
- **Vendor-neutral**. Must not leak SQL / table names / SDK details

Example:
```go
type ChunkRepository interface {
    Save(ctx context.Context, c Chunk) error
    GetByID(ctx context.Context, id string) (*Chunk, error)
    Delete(ctx context.Context, id string) error
}
```

Detection signals:
- SQL strings appear as arguments/return values on a Repository
- A Repository contains business logic instead of CRUD (= responsibility confusion with Application Service)

## 9. DTO / wire shape vs domain shape

- Insert a **DTO conversion** at each layer boundary:
  - `Interfaces` boundary: wire shape (proto message / JSON request) ⇄ Application DTO (`SearchInput` / `SearchOutput`)
  - `Application` boundary: Application DTO ⇄ Domain entity / Value Object
  - `Adapters` boundary: Domain ⇄ vendor SDK shape (Anti-Corruption Layer)
- Place DTO conversion helpers at the boundary layer (e.g. `toProtoResponse` inside `internal/interfaces/grpc/search_handler.go`)
- DTO conversion should preferably be a pure function (easy to test)

Detection signals:
- A Domain entity has proto field tags / JSON tags (= wire shape and domain shape are mixed together)
- Wire shape flows through the application layer unconverted (= missing DTO conversion)

## 10. Cross-cutting concerns

- **Logging / Tracing / Auth / Rate Limit / Recovery** are cross-cutting concerns; **place them at the interfaces / adapters boundary**
- gRPC: `UnaryServerInterceptor` / HTTP: middleware
- Do not import them directly into the Application / Domain layer (= keep them separate from business logic)
- Example: place context keys / logger factories in `internal/observability/`, and have each interceptor consume them

Detection signals:
- `slog.Info(...)` is called directly inside an Application Service / Domain Service (= cross-cutting concern leaking into business logic)
- An auth check is written inline inside a handler (= should be factored out into an interceptor / middleware)

## 11. Domain Event (optional)

- Publish state changes within an aggregate as events, and subscribe to them from an outer layer
- To avoid a reverse-direction dependency: the domain only publishes events; subscribing happens in application / adapter
- Watch out for over-introducing this: unnecessary during the Phase 1 prototype period; consider it in Phase 2 once audit / metrics / integrations increase

## 12. Summary of detection signals (for identifying refactor candidates)

When called from an agent, detect violations with the following grep patterns:

| Violation | Detection grep |
|---|---|
| Domain → outer-layer import | `grep -r 'import.*adapters\|import.*interfaces' internal/domain/` |
| Application → concrete adapter import | `grep -r 'import.*adapters/[a-z]\+/' internal/application/ \| grep -v 'application/ports'` |
| Adapter → interfaces import | `grep -r 'import.*interfaces' internal/adapters/` |
| SDK-specific type in a Port shape | `grep -rn 'pineconego\.\|openaigo\.\|aws\.' internal/application/ports/` |
| Direct logger call inside Application Service | `grep -rn 'slog\.Info\|slog\.Error' internal/application/ \| grep -v 'logger\.'` |
| Direct SDK type import inside handler / service | `grep -rn 'pineconego\|openaigo' internal/interfaces/ internal/application/` |
| SQL string in Repository | `grep -rn 'SELECT\|INSERT\|UPDATE\|DELETE' internal/application/ports/` |

## 13. Configuration injection (functional option + ConfigMap)

Expose configuration overrides in **three tiers**:

| Priority | Path | Purpose |
|---|---|---|
| 1 | **default const** (`defaultXxx`, hardcoded in code) | Phase 1 verification, a safe base value |
| 2 | **functional option** (injected via `WithXxx(...)` at construction time) | per-deployment override, the wiring path for global config |
| 3 | **proto field** (injected per request) | **Exception**, only when individual per-request handling is truly unavoidable (requires user approval) |

Normal operation uses (1) + (2). Extending the proto is a last resort.

Example:
```go
const defaultRenderDPI = 150
func WithDPI(dpi int) PDFOption { return func(pp *PDFParser) { pp.dpi = dpi } }

// cmd/api-server/main.go (wiring)
parser := adapters.NewPDFParser(vlm, adapters.WithDPI(cfg.Parser.DPI)) // ConfigMap value
```

Detection signals (refactor candidates):
- No `defaultXxx` const in the adapter / service → numeric literals scattered throughout the code
- `WithXxx(...)` Option is not exported → the value cannot be overridden from the cmd side
- An adapter struct field is public → direct assignment by the caller breaks immutability
- Adapter-internal values are exposed via a proto field → wire surface bloats

If the project has an ADR adopting functional options, refer to that as well.

---

## False positive criteria

In the following cases, do not treat a hit on this skill's detection signals as a violation:

- **Generated-code origin**: symbols / files generated by protoc / buf / openapi-generator / `go generate`, etc. (typically: the file starts with a `Code generated by ... DO NOT EDIT.` line). These should be fixed at the source schema, not by hand-editing the generated Go code
- **Language / library idiomatic patterns**: things like named returns with defer-recover in `func(...) (resp any, err error)`, fixed signatures such as `http.Handler`, or the convention of taking `context.Context` as the first argument take priority over this skill's rules
- **Intentional design exceptions**: design decisions whose intent is explicitly stated in code / docs (e.g. using `context.Background()` inside a library to detach a shutdown context from a signal-aware ctx)
- **Public API compatibility**: exported symbols that cannot be changed for backward compatibility (prefer proposing a migration strategy over a rename)

When in doubt, don't exclude it — flag it in the output as a "false positive candidate" and defer to the user's judgment.

## What this skill should output

When called from the code-refactor-advisor agent:
- A **per-layer responsibility map** for the target codebase (file × layer × responsibility)
- A list of **layer boundary / dependency direction violations** (file:line + description of the violation)
- Pointing out **missing Port / Adapter / ACL**
- Pointing out **Ubiquitous Language drift**
- A remediation approach (moving to a different layer / extracting a port / adding a DTO conversion layer / etc.)

## References

- Eric Evans, "Domain-Driven Design"
- Vaughn Vernon, "Implementing Domain-Driven Design"
- Robert C. Martin, "Clean Architecture: A Craftsman's Guide to Software Structure and Design"
- Alistair Cockburn, "Hexagonal architecture": https://alistair.cockburn.us/hexagonal-architecture/ (source of the Port-Adapter vocabulary; structurally near-identical to Clean Architecture)
- Mark Seemann, "Dependency Injection in .NET" (discussion of dependency direction)
- Refer to the project's ADR (the decision to adopt DDD + Clean Architecture) if one exists
