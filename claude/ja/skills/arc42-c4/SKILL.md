---
name: arc42-c4
description: Reference for architecture design docs combining arc42 (§1-12) with the C4 model (L1-L4) — which diagram goes in which section, top-level vs subsystem split. Use for "which section gets what", "§5 vs §6 vs §7", "ADR inside or separate". Reference skill, not a procedure.
---

# arc42-c4

arc42 (sections) and C4 (diagrams) are independent conventions; neither spec says which C4 diagram belongs in which arc42 section. **This skill pins that mapping as a house standard** to kill per-doc ambiguity. Project-specific doc maps live in the project's top-level design doc, not here.

Use when writing / reviewing an arc42 + C4 design doc, or deciding the ADR / runbook / README boundary. Supplies section judgment to `tech-docs-writer`; a review lens to `api-design-review`.

## arc42 §1-12

1 Introduction & Goals · 2 Constraints · 3 Context & Scope · 4 Solution Strategy · 5 Building Block View · 6 Runtime View · 7 Deployment View · 8 Crosscutting Concepts · 9 Architecture Decisions · 10 Quality Requirements · 11 Risks & Tech Debt · 12 Glossary

- **§5 vs §6 vs §7** (same blocks, different axis): §5 = static structure ("is X a part?") · §6 = behavior over time ("what order do parts talk for use case Y?", insight-bearing scenarios only) · §7 = physical placement ("which node runs X?").
- **§2 vs §4 vs §10** (same fact can appear in all three): §2 = limits you couldn't choose · §4 = fundamental choices you made · §10 = measurable quality scenarios. PostgreSQL: "policy mandates it" → §2; "we chose it for integrity" → §4; "reads < 50ms p95" → §10. §10 holds ends not means; §9 holds decision index not full ADRs.

## arc42 × C4 mapping (house standard — decisive)

| C4 | arc42 |
|----|-------|
| L1 System Context | **§3** |
| L2 Container | **§5** (top level) |
| L3 Component | **§5** (lower level / subsystem doc) |
| L4 Code | §5 deepest, or omit |
| dynamic diagram | **§6** |
| deployment diagram | **§7** |

The 4 numbered C4 levels are **all static**; runtime → §6, placement → §7. **Dedup:** container structure in §5, container-on-infra mapping in §7 — cross-reference, never paste twice.

## Multi-doc split (top-level ⇄ subsystem)

Fold line = container boundary. **Top-level doc** owns L1 + L2 (the subsystem map / hand-off seam). **Subsystem doc** (one per container) owns L3 (+ L4 if used). The Container diagram is the join: top lists all containers, each subsystem points at its own then expands to components. Subsystem docs may use a **mini** arc42 subset (full §1-12 only at top level).

## Boundary with adjacent conventions

arc42 = durable design-time "shape + rationale". Different audience / cadence → separate doc, arc42 only **links**.

| Convention | Location | arc42 touchpoint |
|-----------|----------|------------------|
| MADR (ADR) | `docs/adr/NNNN-*.md` | **§9 = index only** (id/title/status/link); full rationale, alternatives, consequences in the file |
| Diataxis (README/guides) | `docs/readme/` | link from §8 |
| SRE Playbook (runbook) | `docs/runbook/` | link from §7 / §11 |

Cut an ADR when a decision is costly to reverse, contested, or constrains the future.

## Common mistakes

Flow in §5, or §7 re-pasting §5's diagram · treating a C4 level as "runtime" (all 4 are static) · freely-chosen tech filed under §2 · means in §10 instead of measurable ends · full ADR body in §9 · L1/L2 duplicated in subsystem docs · re-litigating the C4↔arc42 mapping as "just convention" (it's pinned above).

## Related skills

`tech-docs-writer` (writes the doc) · `api-design-review` (reviews it) · `ddd-clean-architecture` (§5 / §8 layer boundaries).
