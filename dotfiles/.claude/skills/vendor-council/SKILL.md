---
name: vendor-council
model: opus
description: "Convenes a council to evaluate a vendor build-vs-buy, selection, renewal, or risk decision: unit economics, contract/governance risk, operational fit, counterfactuals. Graph-first from prior vendor decisions/contracts in graphify-out. Use before any significant vendor commitment."
---

# Vendor Council

Vendor decisions are usually one-way doors made on incomplete info; most evaluations under-weight governance, operational reality, and the counterfactual. This council brings those lenses in.

**Mechanics:** follow `council-scaffolding`. Deltas below.

## When to invoke
Build-vs-buy, selection between 2–4 candidates, renewal (esp. cost/contract changes), risk audit (post-change/post-incident). Routing: broad analysis → `analysis-council`; pricing alone → `analysis-council --council economist,decision-scientist`; governance-only → `governance-reviewer` inline. High-stakes (>$100k or >2y) should also route to `strategic-analysis-review` before committing.

## Roster
Required: `economist`, `decision-scientist`, `governance-reviewer`, `ops-analyst`. Optional: `skeptical-data-scientist`, `counterfactual-check`, `exec-audience-stand-in`, `statistician`. Give personas: vendor description, proposed terms, alternatives, the decision being made.

## Graph context (graph-first)
Detect graphify-out (`.council/` → cwd → `docs/`/`vendors/`/`contracts/graphify-out/`). Extract vendor + category + alternatives + internal teams + capability areas; pull prior decisions on this vendor and in the category (with outcomes), existing internal capability, cross-vendor dependencies, constraining ADRs, contract-term precedents. Tag `[GRAPH]`. `--no-graph` skips.

## Synthesis template
Headline (≤8 lines: ship / pick alternative / renegotiate / abandon) · **Recommendation** (one sentence) · **Where experts disagreed** · **Major risks** (contract/governance · operational · economic · reversibility) · **Counterfactual ("what if we don't")** · **Falsifiers** · **Verdict** (proceed / proceed-with-revisions / renegotiate / reject) · **Per-expert reads**.

## Post-process
`humanizer: true` (synthesis), `domain_cleaner: slop-cleaner --mode analysis`. Persist to `.council/vendor/`.
