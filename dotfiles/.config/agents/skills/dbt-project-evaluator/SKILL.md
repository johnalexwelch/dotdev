---
name: dbt-project-evaluator
model: sonnet
description: 'Runs the dbt-labs dbt_project_evaluator package against a dbt project and turns its test output into a categorized, actionable findings report: staging/marts layering violations, direct joins to source, rejoined upstream concepts, fanout, undocumented or untested models, naming convention breaks, unused sources. Use when checking a dbt project structure or conventions, auditing dbt project health or best-practice adherence, or the user asks to run, install, or interpret dbt_project_evaluator.'
---

# dbt Project Evaluator

## Purpose

`dbt_project_evaluator` (dbt-labs) already encodes these structural rules as dbt tests — this skill runs it and turns raw pass/fail rows into a report someone can act on. Never hand-derive these rules from first principles; the package is the single source of truth for what counts as a violation.

## When to invoke

- "Check our dbt project against dbt_project_evaluator"
- "Audit dbt project conventions / best practices"
- "Is our dbt project structured correctly?"
- "Run dbt_project_evaluator"

Routing:

- A specific query/model's correctness → `sql-review`
- Blast radius of changing one asset → `lineage-audit`
- Warehouse data quality (nulls, freshness, row counts) → `data-quality-audit`
- This skill is scoped to *structural/convention* rules the package tests for — it doesn't replace those three.

## Process

### 1. Locate the target dbt project

Search upward from cwd, then the repo root, for `dbt_project.yml`. If none is found, or more than one exists and the user didn't name a path, ask which project (`AskUserQuestion` with the candidate paths).

Completion criterion: one confirmed path to a `dbt_project.yml`.

### 2. Confirm the package is installed

Read `packages.yml` (or `dependencies.yml`) next to `dbt_project.yml`. Look for `dbt-labs/dbt_project_evaluator` (or the `package: dbt_labs/dbt_project_evaluator` form).

- **Present**: note the pinned version, proceed.
- **Absent**: this needs a file change (`packages.yml`) — treat it as a real code change, not a side effect of running an audit. Follow the repo's normal delivery routing (branch/worktree + PR) to add the pinned entry rather than editing `packages.yml` in place on the current branch. Tell the user a `dbt deps` run will be needed once it lands, and stop this step there — do not silently commit or run `dbt deps` against an unreviewed dependency addition.

Completion criterion: package confirmed installed (with version), or a routed change is in flight and the user knows why the audit is paused.

### 3. Run the evaluator

Once the package is present and `dbt deps` has been run:

```bash
dbt build --select package:dbt_project_evaluator
```

Fall back to `dbt test --select package:dbt_project_evaluator` if the project's `dbt build` isn't set up to materialize the package's seeds. Target a dev/CI profile — never point this at a production target without the user explicitly confirming that target by name first.

Completion criterion: the command has run to completion (pass or fail) and you have its full output, not a truncated tail — dbt's summary line undercounts when output is piped through a pager.

### 4. Map failures to rule categories

Every failing test name maps to one rule category — see `references/rule-categories.md` for the full table (test name pattern → category → what it means → typical fix). Group findings under those categories; do not invent categories the package doesn't define.

For each failing test, capture: the model(s) named in the failure, the category, and the row/record count if the test output includes one (fanout and duplicate-source tests usually do).

Completion criterion: every failing test in the run is assigned to a category and has at least one named model attached — no failure left as a bare test name.

### 5. Report

```markdown
## dbt Project Evaluator: <project>

### Summary
| Category | Passed | Failed |
|---|---|---|
| <category> | N | N |

### Findings (grouped by category, worst first)

#### <category>
- <model/source name> — <what the test found, with the count if available>
  - Fix: <concrete remediation — e.g. "move the join in stg_x to int_x", "add a primary key test to fct_y">

### Not evaluated
- <any package models that errored/were skipped, and why>
```

Completion criterion: every category with at least one failure appears with a concrete fix per finding; categories with zero failures appear only in the summary table, not repeated in Findings.

## Reference

See `references/rule-categories.md` for the dbt_project_evaluator test-name-to-category mapping and remediation patterns per category — load it at step 4, not before.

## Contract

Consumes: a dbt project path (or cwd), optionally a target/profile name
Produces: categorized findings report (markdown) with per-finding remediation
Requires: `dbt` CLI on PATH, dbt profile configured for a non-prod target
Side effects: may propose a `packages.yml` addition (routed through normal delivery, not committed directly); runs `dbt deps` / `dbt build` or `dbt test` against the chosen target
Human gates: confirming the dbt project when ambiguous; confirming the target if it isn't obviously non-prod; reviewing the `packages.yml` PR if the package wasn't already installed

## Context

Typical workflows: standalone project health check; pre-refactor sanity check alongside `lineage-audit`
Pairs well with: sql-review (per-query issues), lineage-audit (blast radius), data-quality-audit (data-level issues)
