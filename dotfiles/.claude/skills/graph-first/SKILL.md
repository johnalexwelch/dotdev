---
name: graph-first
description: Canonical graph-first reference protocol for loading context from graphify-out when present. Loaded by council, constructive, audit, incident, and fiction skills. Never invoked directly.
user-invocable: false
disable-model-invocation: true
---

# Graph-First Protocol (Foundation)

This is a **library**, not a workflow. Every skill that benefits from prior context references this protocol. If you're invoking it directly, you probably want a specific skill instead.

## Contract

Consumes: existing graphify-out directories, optional caller-provided `--graph` or `--no-graph` intent
Produces: graph context-loading protocol, query shape, context block format, and fallback rules for consuming skills
Requires: graphify output only when the caller opts into graph context; otherwise none
Side effects: none unless the consuming skill explicitly runs graphify after `--graph`
Human gates: none

## Detection paths

When a skill enters its graph-first step, it checks these locations in order for an existing `graphify-out/` directory:

1. `.council/graphify-out/` in cwd
2. `graphify-out/` in cwd
3. Domain-specific paths (each skill names its own):
   - Code/decisions: `docs/graphify-out/`, `decisions/graphify-out/`
   - Lore/fiction: `campaign/graphify-out/`, `lore/graphify-out/`, `world/graphify-out/`, `manuscripts/graphify-out/`
   - Metrics: `metrics/graphify-out/`
   - Vendor/contracts: `vendors/graphify-out/`, `contracts/graphify-out/`
   - Incidents: `incidents/graphify-out/`, `runbooks/graphify-out/`
   - Dashboards: `dashboards/graphify-out/`
4. Fallback: `~/.council-sessions/<project-slug>/graphify-out/`

If found → proceed to query.
If not found AND `--graph` flag is set → run `graphify` on the relevant source dir first, then proceed.
If not found AND `--graph` NOT set → skip context block (see fallback section).

## Query shape

Each skill extracts a set of **entities** from the topic/input and queries the graph for each. Standard query shape per entity:

- The entity's own node
- 1–2 hop neighbors (skill-defined depth)
- Edges with their canon/source/timestamp
- Edges flagged as contested, contradicted, or stale
- Cross-references to other entities in the same input

The specific entity types and hop-depth are skill-specific. The skill's own SKILL.md lists them.

## Context block format

Every graph-first skill bundles its query results into a markdown block prefixed to the dispatched persona prompt OR inlined at the relevant process step. The block uses this standard structure (skills may add domain-specific sections):

```markdown
## <Domain> context (from knowledge graph)
Entities found: <list>
Direct neighbors: <list with refs/sources>
Contested or contradicted edges: <list>
Cross-references: <list>
<Optional domain-specific section, e.g. "Timeline trace" for narrative or "Prior decisions" for vendor>
```

## Tagging in synthesis

Any finding or recommendation that builds on graph context is tagged `[GRAPH]` (or `[GRAPH-<modifier>]` for specific subtypes like `[GRAPH-TIMELINE]`, `[GRAPH-LINEAGE]`, `[GRAPH-PRIOR-DECISION]`).

Synthesis output should weight `[GRAPH]`-tagged findings explicitly — they're grounded in canon, not lens-only.

## Fallback when no graph exists

If `graphify-out/` is not found AND `--graph` is not passed:
- Skip the context block (don't fabricate context)
- Proceed with the skill's normal flow
- Add a one-line note in the skill's output: "No knowledge graph detected — <skill> ran without prior-<domain> context. Consider `graphify` on `<domain-source-dir>/` and re-invoking."

## Flag semantics

- **(default, no flag)**: auto-detect — use graph if present, skip if not
- **`--graph`**: force graphify ingestion first if no graph exists; then use it
- **`--no-graph`**: force-skip even if graph exists (use for clean-slate review, or when the canon shouldn't constrain a fresh take)

## Cost and budget

Graph queries are cheap by default (read-only lookups against existing nodes/edges). No special budget needed unless `--graph` triggers ingestion of a large source dir — that's a one-time cost the user has already opted into by passing the flag.

## When NOT to use graph-first

Skills that produce fresh artifacts with no meaningful prior context (e.g., a one-off SQL review of a one-off ad-hoc query) can skip graph integration entirely. The protocol is opt-in per skill — each skill's SKILL.md declares whether it's graph-first.

## Composition with council scaffolding

For council-style skills (`analysis-council`, `worldbuilding-council`, etc.), the graph query happens at step 2.5 of the dispatch process — after roster resolution, before round 1 dispatch — so the context block is included in every persona's prompt. See `council-scaffolding/SKILL.md` for the council process steps.

For non-council skills, the graph step happens at the natural "load context" moment in that skill's process (often step 1.5 or before the first analytical step).
