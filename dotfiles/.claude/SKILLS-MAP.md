# Personal Skills Map

Last updated: 2026-05-23. Built across the 2026-05-22 → 2026-05-23 design session.

**Goal**: when you want to do X, this tells you what to invoke. Reads as a cheat sheet, not a reference manual.

---

## When you want to...

### Starting a new project / repo onboarding
| You want to... | Invoke |
|---|---|
| Wire a repo for agent work (issue tracker, triage labels, domain docs, OpenWiki registration) | `setup-skills` |

### Think harder about something
| You want to... | Invoke |
|---|---|
| Challenge your thinking on a claim, draft, or interpretation | `analysis-council` |
| Quick claim check (~3 min) | `analysis-council --fast "<claim>"` |
| Full default (4–5 experts, 2 rounds) | `analysis-council "<topic>"` |
| Specific lenses only | `analysis-council --council skeptical-data-scientist,statistician` |
| Personas test specific claims with tools | `analysis-council --verify` |
| Stress-test a memo's structure (not its thinking) | `strategic-analysis-review` |

### Design analysis / metrics / experiments
| You want to... | Invoke | Then |
|---|---|---|
| Design an analysis from a question | `analysis-design` | → `analysis-council` for stress-test → `decision-memo` |
| Design a new metric | `metric-design` | → `metric-council` → `add-metric` |
| Design an A/B test | `experiment-design` | → `analysis-council` for stress-test |
| Design a dashboard | `dashboard-design` | → implement in Metabase/Looker |
| Write the decision memo | `decision-memo` | → `humanizer-exec` → `analysis-slop-cleaner` → send |

### Audit data
| You want to... | Invoke |
|---|---|
| Review a SQL query before running | `sql-review` |
| Audit a metric tree | `metric-tree-review` |
| Audit a dashboard for decision-fit | `dashboard-review` |
| Check if the data is ready for analysis | `data-readiness-check` (or embedded in `analysis-design`) |
| Trace lineage upstream/downstream | `lineage-audit` |
| Periodic data-quality audit | `data-quality-audit` |

### Vendor / build-vs-buy
| You want to... | Invoke |
|---|---|
| Stress-test a vendor decision | `vendor-council` |

### Incidents
| You want to... | Invoke |
|---|---|
| Triage an active incident | `incident-triage` |
| Run a post-incident retro | `incident-retro` |
| Write a runbook | `runbook-author` |

### Fiction / worldbuilding
| You want to... | Invoke |
|---|---|
| Challenge a world, region, culture, faction | `worldbuilding-council` |
| Deep-dive on a single element (city, culture, religion) | `worldbuilding-deep-dive` |
| Audit a multi-arc saga / generational story | `narrative-council` |
| Outline a novel / story / arc | `story-outline` |
| Design or audit a character's arc | `character-arc` |
| Design or audit a single scene | `scene-craft` |
| Audit pacing across a work | `pacing-review` |
| Per-unit mission cards | `narrative-purpose-guide` |
| Lightweight stress-test | `dnd-grill` |
| Stress-test against canon | `dnd-grill-with-canon` |
| Promote rough notes to canon | `dnd-lore-ingestion` |
| Design a D&D encounter | `dnd-encounter-design` |
| Session prep | `dnd-session-prep` |

### Polish / cleanup
| You want to... | Invoke |
|---|---|
| Strip AI patterns from prose | `humanizer` |
| Exec-tuned humanizer (lead with answer, compress) | `humanizer-exec` |
| Clean AI patterns from analysis output | `analysis-slop-cleaner` |
| Clean AI patterns from technical docs | `doc-slop-cleaner` |

### PRs / code
| You want to... | Invoke |
|---|---|
| Process all PR review comments | `pr-responder` |
| Review a diff | `review` or `code-review` |
| Receive review feedback critically | `receive-review` |

---

## Pipelines (multi-step flows)

### Decision pipeline (daily-driver CDO)
```
question → analysis-design → execute analysis → analysis-council (stress-test)
                                              → decision-memo → analysis-slop-cleaner → humanizer-exec → send
```

### Metric pipeline
```
"need a new metric" → metric-design → metric-council → add-metric → validate-metric-trees
```

### Experiment pipeline
```
hypothesis → experiment-design → analysis-council (stress-test) → implement → post-results → analysis-design → decision-memo
```

### Worldbuilding pipeline
```
loose idea → worldbuilding-council (breadth) → worldbuilding-deep-dive (depth per element) → dnd-lore-ingestion (promote to canon)
```

### Story pipeline
```
premise → story-outline → narrative-purpose-guide --from-outline (mission cards) → scene-craft per scene → pacing-review (mid-draft) → narrative-council (saga-level audit)
```

### Incident pipeline
```
alert → incident-triage (active) → resolve → incident-retro → runbook-author (for new patterns)
```

### Vendor pipeline
```
build-vs-buy question → vendor-council → decision-memo → strategic-analysis-review (high-stakes)
```

---

## Council selection (when to use which)

| Council | When to use | Round 1 dispatch |
|---|---|---|
| `analysis-council` | Challenge thinking, claim, draft, interpretation | Parallel |
| `metric-council` | Stress-test a new metric before implementation | Parallel |
| `vendor-council` | Build-vs-buy, vendor selection, renewal, risk audit | Parallel |
| `worldbuilding-council` | Challenge a world / region / culture / faction | **Waves** (foundational → derived) |
| `narrative-council` | Multi-arc saga, generational sweep, through-line audit | **Waves** |

All councils:
- 2 rounds by default (lens → response)
- Graph-first by default (auto-loads `graphify-out/`)
- Persist to `.council/<sub>/<date>-<slug>.md`
- Synthesize disagreement, don't force consensus

---

## Persona library (use via `--council <names>`)

### Analysis-side (8)
- `skeptical-data-scientist` — data integrity, sample selection, confounders, base rates
- `decision-scientist` — decision quality, EV, optionality, reversibility, decision-vs-outcome
- `statistician` — sample size, power, significance vs. importance, distributions
- `causal-reasoner` — DAGs, backdoor paths, mediators, counterfactual framing
- `counterfactual-check` — "compared to what?" — forces explicit counterfactuals
- `governance-reviewer` — COPPA, FERPA, GDPR, consent, child-data, purpose limitation
- `exec-audience-stand-in` — reads as the exec audience would, headline + skim + objection
- `ops-analyst` — operational reality, throughput, on-call burden, run-cost
- `economist` — unit economics, opportunity cost, elasticity, incentives (dual-use)

### Worldbuilding-side (9)
- `anthropologist` — kinship, status, ritual, food, taboo, group identity
- `cartographer` — terrain, water, trade routes, chokepoints, distance, settlement logic
- `historian` — origin events, schisms, succession, demographic shocks, living memory
- `linguist` — phonology, morphology, names, dialect, register (has web_fetch)
- `ecologist` — food webs, energy budgets, climate fit, carrying capacity
- `theologian` — cosmology, priesthood, doctrine, schism, religion-and-state
- `political-scientist` — selectorate, coalitions, succession, factions, legitimacy
- `military-strategist` — force structure, terrain, logistics, intel asymmetry, doctrine (dual-use for D&D encounters)
- `economist` — also pre-modern carrying capacity, surplus, trade gradients

Personas live in `~/.claude/skills/_personas/`. Each one has voice, lens, anti-patterns, and a falsifier prompt.

---

## Trigger phrases (what fires what)

| You say... | Fires |
|---|---|
| "challenge my thinking," "what am I missing," "pressure-test this" | `analysis-council` |
| "is this analysis right?" | `analysis-council` |
| "what would a skeptic say" / "skeptical data scientist" | `analysis-council` (highlights that persona) |
| "review this memo," "pressure-test this recommendation" | `strategic-analysis-review` |
| "humanize this," "de-AI this" | `humanizer` (or `humanizer-exec` for memos) |
| "design an analysis" | `analysis-design` |
| "challenge this world," "what's wrong with this setting" | `worldbuilding-council` |
| "outline this story / novel / arc" | `story-outline` |
| "this scene isn't working" | `scene-craft` |
| "review this query" / "check this dbt model" | `sql-review` |
| "review this dashboard" | `dashboard-review` |
| "triage this incident" / "help me triage" | `incident-triage` |
| "write a runbook for X" | `runbook-author` |
| "process the PR comments" | `pr-responder` |
| "build-vs-buy" / "should we buy X" | `vendor-council` |

---

## Architecture (foundation)

### Shared libraries (`_*` directories, never invoked directly)
- `_personas/` — 17 reusable expert lenses
- `_council-scaffolding/` — council pattern: dispatch, rounds, synthesis, persistence
- `_graph-first/` — graphify integration protocol: detection paths, query shape, context block format

### Modes
- **`--fast`** (councils): required personas only, 1 round
- **`--verify`** (councils): personas may use tool_access to test claims
- **`--graph`** (everything): force graphify ingestion first
- **`--no-graph`** (everything): force-skip even if graph exists
- **`--council <names>`** (councils): user-specified persona list
- **`--round-3`** (councils): force a third round when round 2 surfaced new challenges

### Outputs
- Councils → `.council/<sub>/<date>-<slug>.md` + JSON sidecar
- Designs → `.analyses/`, `.metrics/designs/`, `.experiments/`, `.dashboards/`
- Worldbuilding → `.worldbuilding/`, `.council/missions/`
- Incidents → `.incidents/`
- Runbooks → `.runbooks/`
- All auto-`.gitignore` on first write
- Fallback: `~/.council-sessions/<project-slug>/` if cwd not writable

### Composition
- Analysis: `analysis-design` → `analysis-council` → `decision-memo` → `humanizer-exec` + `analysis-slop-cleaner`
- Metric: `metric-design` → `metric-council` → `add-metric`
- Fiction: `worldbuilding-council` → `worldbuilding-deep-dive` → `story-outline` → `scene-craft` (embeds `narrative-purpose-guide`)
- Incident: `incident-triage` → resolve → `incident-retro` → `runbook-author`

---

## What this whole system is for

**You are a CDO**. Your job is decisions under uncertainty, communicated to executives, often based on data you don't fully control. The skills are organized around that loop:

1. **Frame** — `analysis-design`, `metric-design`, `experiment-design` (constructive)
2. **Challenge** — `*-council` (every council) (skeptical)
3. **Decide** — `decision-memo` (communicate)
4. **Polish** — `humanizer-exec` + `analysis-slop-cleaner` (audience-ready)
5. **Audit** — `*-review`, `*-audit` (when you're checking, not creating)
6. **Operate** — `incident-*`, `runbook-author` (when something breaks)
7. **Create** — fiction / worldbuilding skills (when you're playing)

The graph-first default means every skill consults what's already known before working — your knowledge graph is doing work for you continuously, not just when you ask.

---

## Maintenance

- Update this doc when you add or retire a skill
- The authoritative list is `~/.claude/skills/` (run `ls ~/.claude/skills/` to see what's currently active)
- Each skill's SKILL.md is its own contract — when in doubt, read it
- Personas can be added by dropping a new file in `~/.claude/skills/_personas/<name>.md`
- Councils can be added by creating `<name>-council/SKILL.md` + `roster.yml` and referencing `_council-scaffolding/SKILL.md`

For the architectural intent behind any specific skill, the SKILL.md frontmatter `description` is the canonical statement. This map is a memory aid, not a substitute.
