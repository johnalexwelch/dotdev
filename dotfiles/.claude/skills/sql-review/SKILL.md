---
name: sql-review
model: sonnet
description: "Reviews a SQL query, view, or dbt model for correctness, performance, and clarity: join cardinality, window pitfalls, NULL handling, time-zone bugs, fanout, missing GROUP BY, unsafe DELETE/UPDATE, and warehouse-specific gotchas. Use before queries hit production."
---

# SQL Review

## Purpose

Stress-test a SQL query before it's run on production data or merged into a model. Most SQL bugs are silent — they return numbers that *look* right but are subtly wrong (joined wrong, double-counted, off by a time zone). This skill is the second pair of eyes.

**Mechanics:** follow `review-scaffolding` for the review discipline (lead with what changes results, a concrete fix per finding, raise the unsure as an open question, state confidence) and severity vocabulary. The checks, grain-tracing process, and bug/smell/perf/clarity output below are SQL-specific; the DELETE/UPDATE-without-WHERE halt is a hard gate.

## When to invoke

- "Review this query"
- "Check this dbt model"
- "Is this SQL right?"
- Before any unfamiliar query is run at scale
- Before a model is merged

Routing:
- Pattern audit across many models → `metric-tree-review` or `lineage-audit`
- Performance tuning specifically → use this with `--focus=perf`
- Data correctness across the warehouse → `data-quality-audit`

## What it catches

| Category | Checks |
|----------|--------|
| **Join cardinality** | Does the join actually preserve grain? Fanout from one-to-many joins inflates aggregates. Look for joins without uniqueness on the right side. |
| **Window functions** | PARTITION BY columns explicit? ORDER BY for cumulative? Frame clause (ROWS vs RANGE) appropriate? |
| **NULL handling** | NULL = NULL is false. `WHERE x != 'foo'` excludes NULLs. NULL-safe equality where needed. |
| **Time zones** | UTC vs. local? Date boundaries — does "yesterday" mean what you think? `DATE_TRUNC` time-zone-aware? |
| **GROUP BY completeness** | Every non-aggregated column in SELECT must be in GROUP BY. Some dialects allow it silently and return wrong rows. |
| **DISTINCT placement** | `COUNT(DISTINCT x)` vs `COUNT(x)` — which is intended? Distinct in subquery vs. outer query. |
| **Date arithmetic** | INTERVAL types, daylight savings, month-length variation, leap years. |
| **CTE materialization** | Some dialects re-execute CTEs per reference. Performance and consistency implications. |
| **Predicate placement** | WHERE vs ON vs HAVING — wrong placement on outer joins changes results. |
| **Type coercion** | Implicit string-to-number, date-to-string, boolean handling. |
| **Unsafe mutations** | DELETE / UPDATE without WHERE, missing transaction, no LIMIT during test. |
| **Dialect-specific** | Redshift sort/dist keys; BigQuery `_PARTITIONTIME`; Snowflake `QUALIFY`; Postgres array gotchas. |

## Process

### 1. Read the query

Parse intent from comments + structure. What's the expected grain of the result? What's the expected row count?

### 2. Trace grain through joins

For each join:
- What's the cardinality on each side?
- Does the join preserve, expand, or contract grain?
- Is fanout intended or accidental?

Flag any join where the right side isn't unique on the join key.

### 3. Walk filters and predicates

- Are WHERE filters on the right side of outer joins accidentally turning them into inner joins?
- Are NULL-bearing predicates handled?
- Are date-bound filters using inclusive vs exclusive correctly?

### 4. Check aggregates and windows

- Every non-aggregated column in GROUP BY?
- COUNT vs COUNT DISTINCT chosen correctly?
- Window function PARTITION BY explicit?
- Frame clause appropriate for cumulative vs sliding?

### 5. Dialect-specific scan

If the user mentions Redshift / BigQuery / Snowflake / Postgres, run dialect-specific checks.

### 6. Output

```markdown
## SQL Review

### Headline
<one sentence: looks correct | has likely bugs | needs clarification before run>

### Bugs (must fix)
- **Line X**: <bug>. Why: <how the result is wrong>. Fix: <what to do>.
- ...

### Smells (worth fixing)
- <issue>: <why>. Optional fix.

### Performance notes
- <expected scan size / cost flag / index recommendation>

### Clarity nits
- <readability improvements that won't change results>

### Open questions
- <ambiguities that the reviewer can't resolve from the query alone>

### Confidence
- <high | medium | low — based on whether the data shape was inferable>
```

## Rules

- Lead with bugs that change results. Performance and clarity are secondary.
- If unsure whether something is a bug, raise it as an "open question," not a bug.
- Suggest a concrete fix for each bug, not just a critique.
- Don't rewrite the whole query unless asked — point at the specific lines.
- If the query is a DELETE / UPDATE without a WHERE clause, stop and confirm intent before any other review.

## Graph context (GRAPH-FIRST — default behavior)

See `graph-first/SKILL.md` for the canonical protocol.

For this skill, query the graph for:
- **Tables / models referenced** by the query — their grain, owner, freshness
- **Lineage** upstream (where do these tables come from) and downstream (what consumes this query's output)
- **Prior bugs** filed against the same models — recurring footguns
- **Similar queries** that have been reviewed — common review patterns

Insertion point: step 2 (trace grain through joins) is graph-augmented when lineage is available. Tag findings using graph data as `[GRAPH-LINEAGE]`.

`--no-graph` skips. `--graph` forces graphify on the dbt project / warehouse first.

## Contract

Consumes: SQL query, view definition, or dbt model
Produces: bug + smell + perf + clarity report with concrete fixes
Requires: nothing (does not execute the query)
Side effects: none unless the user asks to apply fixes
Human gates: dangerous mutations halt for confirmation

## Context

Typical workflows: pre-execution review, dbt model PR review, ad-hoc analysis sanity check
Pairs well with: metric-tree-review (if many models), data-quality-audit (warehouse-wide), debug-query (when the query is already failing)
