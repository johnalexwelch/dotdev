---
name: metric-tree-review
description: Audits a metric tree (or a candidate addition) for definitional clarity, math consistency, cross-tree coherence, and whether the tree actually decomposes the parent metric. Catches double-counted leaves, missing components, conflated influences-vs-components, and "metric soup" trees that don't compose. Use when adding to or restructuring metric trees.
---

# Metric Tree Review

## Purpose

A metric tree should let an executive look at the parent metric and walk down through its drivers to find what changed. Many trees fail this — they list metrics by topic ("engagement metrics," "retention metrics") without composing. This skill catches the structural problems.

## When to invoke

- Adding a new metric or sub-tree
- Auditing an existing tree before promotion
- "Does this metric tree actually decompose its parent?"
- After `audit-metric-trees` flags a gap

Routing:
- Add a single metric → `add-metric` (this can review after)
- Validate gap SQL → `validate-metric-trees`
- Manage tree structure broadly → `manage-metric-trees`

## What it checks

| Category | Checks |
|----------|--------|
| **Decomposition validity** | Does parent = sum/product/ratio of children, or some named formula? If the tree claims a math relationship, does the math actually hold? |
| **Components vs. influences** | Components multiply / sum to the parent. Influences are correlates. Conflating these is the #1 tree bug. |
| **Leaf cleanliness** | Are leaves measurable and instrumented? Or are they aspirational? |
| **Double-counting** | Two sibling metrics that contain the same underlying events. |
| **Coverage gaps** | Parent claims to be decomposed but children don't add up — what's missing? |
| **Cross-tree leakage** | Same metric appearing in two trees with different definitions. |
| **Definitional drift** | A metric's SQL has drifted from its YAML description, or its semantics have drifted from intent. |
| **Naming ambiguity** | "DAU" without specifying user type, "engagement" without specifying event class. |
| **Time-window consistency** | Parent is monthly, children are weekly — what's the rollup? |
| **Stability of denominator** | A ratio whose denominator can change is unstable for trend analysis. |

## Process

### 1. Identify the tree (or sub-tree)

What's the parent metric? What are the claimed children? Read the YAML / config.

### 2. Test the decomposition

Pick the relationship — additive, multiplicative, ratio, or named formula. Walk through the math on a sample period. Does the parent equal the expected function of the children?

Common failure: "drivers of X" are listed but don't actually compose. Flag this.

### 3. Component vs. influence check

For each child, classify:
- **Component**: mathematically composes into parent. If you change this child, parent changes by definition.
- **Influence**: correlated with parent but not part of its definition. Useful, but should live in a different structure (driver analysis, not metric tree).

A clean tree has components only at the top levels; influences belong in driver analyses.

### 4. Double-count and coverage scan

- For each pair of sibling leaves, do they share underlying events?
- Do the children plus any "other / unattributed" bucket sum to the parent?

### 5. Cross-tree consistency

If the same metric appears in another tree, do the definitions match? Same SQL, same time window, same filters?

### 6. Definitional clarity

- Is the metric named precisely? "Active users" vs. "active teachers logged in to web in the last 7 days."
- Does the SQL match the prose definition?

### 7. Output

```markdown
## Metric Tree Review: <tree name>

### Headline
<one sentence: composes correctly | has decomposition bugs | structural issues>

### Decomposition check
- Parent: <metric>
- Relationship: <additive | multiplicative | ratio | named formula>
- Math holds: yes | no | unable-to-verify
- Discrepancy: <if any>

### Bugs (must fix)
- **<metric>**: <bug — component-vs-influence confusion / double-count / coverage gap / drift / etc.>
  - Why it matters: <how the tree misleads>
  - Fix: <concrete change>

### Smells (worth fixing)
- ...

### Cross-tree consistency
- <metric X appears in tree Y with different definition>

### Open questions
- ...

### Confidence
- <high | medium | low>
```

## Rules

- Math must hold. If parent ≠ f(children), the tree doesn't decompose — say so plainly.
- Components and influences belong in different structures. Don't accept "drivers of" as a substitute for components.
- Naming is half the work. "DAU" with no definition is not a metric, it's a wish.
- Don't accept the tree's claimed relationship without checking. SQL drifts from intent.

## Graph context (GRAPH-FIRST — default behavior)

See `_graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:
- **Full tree structure** as a graph (parents, children, claimed math relationships)
- **Cross-tree appearances** of the same metric — definitional drift surfaces here
- **Downstream dashboards** consuming any node in the tree (impact scope)
- **Prior tree audits** on this or adjacent trees — patterns of failure
- **Related metrics outside this tree** that may belong inside it

Insertion point: step 5 (cross-tree consistency) is graph-driven. Tag cross-tree findings as `[GRAPH-CROSSTREE]`.

`--no-graph` skips. `--graph` forces graphify on `metrics/` first.

## Contract

Consumes: metric tree YAML / config + optional sample period data
Produces: structured review with decomposition check + bugs + smells
Requires: nothing (does not execute SQL; flags need for `validate-metric-trees` if SQL needs warehouse verification)
Side effects: none
Human gates: none

## Context

Typical workflows: pre-promotion review, post-restructure audit, dbt model PR review
Pairs well with: add-metric (upstream), validate-metric-trees (downstream SQL check), audit-metric-trees (gap-finding), manage-metric-trees (structural changes)
