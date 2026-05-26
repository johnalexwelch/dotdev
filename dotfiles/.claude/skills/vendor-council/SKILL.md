---
name: vendor-council
description: Convenes a council to evaluate a vendor build-vs-buy decision, vendor selection between candidates, vendor renewal, or vendor risk audit. Lens on unit economics, governance / contract risk, operational fit, decision asymmetry, and counterfactual ("what if we just built / bought / kept the alternative"). Graph-first by default — auto-loads prior vendor decisions, existing contracts, internal capabilities, and related ADRs from `graphify-out/` when present so experts see this decision in the context of the company's vendor history. Use before any significant vendor commitment.
---

# Vendor Council

## Purpose

Vendor decisions are usually one-way doors (high switching cost) made on incomplete information. Most evaluations fail by under-weighting governance, operational reality, and counterfactual. This council brings those lenses in.

## When to invoke

- Build-vs-buy decisions ("should we build X or buy it from Y?")
- Vendor selection between 2–4 candidates
- Vendor renewal (especially with significant cost or contract changes)
- Vendor risk audit (after vendor change, after incident)

Routing:
- Stress-test an analysis broadly → `analysis-council`
- Pricing / unit economics alone → `analysis-council --council economist,decision-scientist`
- Governance-only check → use `governance-reviewer` persona inline

## Process

### 1. Parse invocation

Identify:
- Decision type: build-vs-buy | selection | renewal | audit
- Vendor candidates (1+ for build-vs-buy and audit; 2+ for selection)
- Stakes: cost, contract length, switching cost, data sensitivity
- Decision deadline

### 2. Resolve roster

Defaults:
- Required: `economist`, `decision-scientist`, `governance-reviewer`, `ops-analyst`
- Optional: `skeptical-data-scientist`, `counterfactual-check`, `exec-audience-stand-in`, `statistician`

### 2.5. Load vendor-and-decision-history context (GRAPH-FIRST — default behavior)

Auto-detect graphify-out in this order:
1. `.council/graphify-out/` in cwd
2. `graphify-out/` in cwd
3. `docs/graphify-out/`, `vendors/graphify-out/`, `contracts/graphify-out/`

**If found (or `--graph` is passed)**:
- Extract entities: vendor name, product category, alternative vendors named, internal team names, related capability areas, similar past decisions.
- Query the graph for:
  - **Prior decisions on this vendor** (renewal history, prior evaluations, prior switches in/out)
  - **Prior decisions in the same product category** — patterns from similar build-vs-buy choices
  - **Existing internal capability** in the category (what we already have or have built)
  - **Cross-vendor dependencies** — does this vendor depend on / integrate with / compete with vendors we already use?
  - **Related ADRs** that constrain vendor choice (data residency, security baseline, etc.)
  - **Contract terms history** — what we've agreed to before in similar categories
- Bundle into a **vendor-history context block** prefixed to every persona's dispatch prompt:
  ```
  ## Vendor and decision-history context (from knowledge graph)
  Prior decisions on this vendor: <list>
  Prior decisions in the same category: <list with outcomes>
  Existing internal capability: <list>
  Cross-vendor dependencies: <list>
  Constraining ADRs: <list>
  Notable contract-term precedents: <list>
  ```
- Tag findings that depend on graph context as `[GRAPH]` in the synthesis.

**If no graph + no `--graph` flag**: skip context block. Add note in synthesis: "No vendor-history graph detected — council reviewed this decision without prior-vendor context. Consider graphify on `docs/adr/` and contract docs for richer priors."

**If `--no-graph`**: force-skip.

### 3. Dispatch round 1 (parallel)

Each persona evaluates the vendor through their lens. Provide them: vendor description, proposed contract terms, alternatives considered, the decision being made.

### 4. Dispatch round 2 (parallel)

Response-to-experts pass.

### 5. Synthesize

```markdown
# Vendor Council on: <decision>

## Synthesis
<≤8 lines: ship the vendor / pick alternative / renegotiate / abandon>

## Recommendation
<single sentence>

## Where experts disagreed
- ...

## Major risks identified
- **Contract / governance**: <risk>
- **Operational**: <risk>
- **Economic**: <risk>
- **Decision reversibility**: <risk>

## Counterfactual ("what if we don't")
<one paragraph on the alternative path — build internally, pick the alternate vendor, stay status quo, accept the gap>

## What would change the recommendation
- <falsifier 1>
- <falsifier 2>

## Verdict
- proceed | proceed with revisions | renegotiate | reject

## Per-expert reads
### economist (confidence: ...)
...
```

### 6. Post-process

- humanizer: true (synthesis only)
- domain_cleaner: analysis-slop-cleaner

### 7. Persist

`.council/vendor/<YYYY-MM-DD>-<vendor-slug>.md` + JSON sidecar.

## Contract

Consumes: vendor description + proposed terms + alternatives + decision being made
Produces: council synthesis with verdict + per-expert reads
Requires: subagent dispatch, _personas/
Side effects: writes to .council/vendor/
Human gates: high-stakes decisions (>$100k or contract length >2y) should also route to `strategic-analysis-review` for memo polish before committing

## Context

Typical workflows: pre-contract decision, vendor renewal, build-vs-buy
Pairs well with: analysis-design (if the decision needs supporting data analysis first), decision-memo (downstream — write the recommendation memo), strategic-analysis-review (for high-stakes review of the memo)
