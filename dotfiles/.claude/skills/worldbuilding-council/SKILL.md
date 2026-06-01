---
name: worldbuilding-council
description: "Convenes a council of worldbuilding experts (anthropology, geography, economy, history, religion, politics, military) to stress-test a fictional world, culture, polity, or setting. Graph-first from graphify-out canon. Use for \"challenge this world\", \"interrogate this faction/culture\", or multi-domain consistency review."
---

# Worldbuilding Council

Multi-lens council on a fictional world or part of one. Inconsistencies are story fuel, not failures — the synthesis names them and asks how to make them load-bearing.

**Mechanics:** follow `council-scaffolding` for the dispatch contract. Deltas below. Differs from analysis-council in: wave-based round 1, post-process disabled, inconsistency framed as opportunity.

## When to invoke
"Challenge this world/region/culture/polity/faction", "what's broken in this setting", "interrogate this worldbuilding", before locking major lore. Routing: quick continuity → `dnd-review --mode continuity`; single scene → `dnd-grill`; one element deep → `worldbuilding-deep-dive`.

## Roster
Required: `cartographer`, `anthropologist`, `historian`, `political-scientist`. Smart-pick optional per `roster.yml.dispatch_signals`.

## Round 1 — waves (dependency order)
Worldbuilding personas depend on each other, so round 1 runs in waves (each wave sees prior waves' output), then round 2 is fully parallel:
- Wave A: cartographer, anthropologist, ecologist, economist
- Wave B (sees A): historian, linguist
- Wave C (sees A+B): theologian, political-scientist
- Wave D (sees A+B+C): military-strategist

## Graph context (graph-first, default on)
Canon coherence is the point. Detect graphify-out (`.council/graphify-out/` → `graphify-out/` → `campaign/`/`lore/`/`world/graphify-out/`). Extract settlement/faction/character/location/event/deity/language names; prefix each persona with known relationships (with canon source), contested edges, dependencies; tag `[GRAPH]`. `--no-graph` skips; `--graph` ingests canon dir first.

## Synthesis template
Headline (≤10 lines) · **Where experts disagreed** · **Inconsistencies worth keeping (story fuel)** · **Inconsistencies worth fixing (breaks the world)** · **Open questions for the author** · **Confidence** · **Per-expert reads**. Surface dependencies ("if economist's X holds, political-scientist's Y breaks"); don't force consensus on contested lore.

## Post-process
`humanizer: false`, `domain_cleaner: null` (voice matters more than tells). Persist to `.council/worldbuilding/`.
