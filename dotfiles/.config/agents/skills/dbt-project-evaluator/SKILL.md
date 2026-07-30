---
name: dbt-project-evaluator
model: sonnet
description: 'Checks a dbt project against the dbt-labs dbt_project_evaluator rules and produces a categorized, actionable findings report — by default evaluated locally from manifest.json (fast, no warehouse) and scoped to the models touched by the current change plus their upstream/downstream lineage; full-project or warehouse package runs on explicit request. Covers staging/marts layering violations, direct joins to source, rejoined upstream concepts, fanout, undocumented or untested models, naming convention breaks, unused sources. Use when checking a dbt project structure or conventions, evaluating changed dbt models against best practices, auditing dbt project health, or the user asks to run, install, or interpret dbt_project_evaluator.'
---

# dbt Project Evaluator

## Purpose

`dbt_project_evaluator` (dbt-labs) defines the structural rules — this skill evaluates them and turns raw violations into a report someone can act on. The package's rule definitions are the single source of truth for what counts as a violation; `scripts/evaluate_manifest.py` mirrors them locally (from `manifest.json`, no warehouse) because materializing the package's recursive DAG models in the warehouse hangs for hours on large projects. Never invent rules beyond what the package defines.

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

### 2. Determine touched models

The default run is **scoped**: findings are reported only for the models the current change (PR/branch diff) touches, plus everything upstream and downstream of them. Run project-wide (`--full`) only when the user explicitly asks for a full audit.

Derive touched models from git: `git diff --name-only <base>...HEAD -- models/` (or the project's model paths from `dbt_project.yml`), mapped to model names by filename. Prefer `dbt ls --select state:modified --output name` when a comparison manifest already exists. If the diff touches no model files, say so and stop — don't fall back to a full-project run silently.

Completion criterion: a concrete list of touched model names, or an explicit "nothing touched" stop.

### 3. Evaluate from the manifest (default fast path — no warehouse)

The structural rules only need graph metadata, and all of it is in `manifest.json`. Running the actual package materializes recursive DAG models in the warehouse and can hang for hours on large projects — so the default path never touches the warehouse:

```bash
dbt parse   # writes target/manifest.json locally, seconds even on large projects
python3 scripts/evaluate_manifest.py target/manifest.json --changed <touched models...>
```

The script computes every rule over the **full graph** (fanout/rejoining need global context), walks lineage from the touched models itself (no `dbt ls` needed), then filters findings to the scope set. Out-of-scope failures come back as counts only. Its `not_covered` list names the package rules it doesn't implement — carry that list into the report verbatim, and check the project's `dbt_project.yml` vars for package overrides (custom prefixes, thresholds) that would change what counts as a violation.

Completion criterion: script ran cleanly and produced JSON with `findings`, `out_of_scope_counts`, and `scope_size`; any `changed_not_found` entries investigated (renamed/deleted models are expected there, typos are not).

### 4. Full package run (only on explicit request)

When the user asks for the package's own warehouse-materialized run (e.g. to match CI exactly): confirm `dbt-labs/dbt_project_evaluator` is in `packages.yml` — if absent, route the addition through normal delivery (branch + PR), never edit in place, and pause there. Then `dbt build --select package:dbt_project_evaluator` against a dev/CI target — never prod without the user naming it — after warning that this can run very long on large projects. Filter failing-test rows to the scope set by querying the `fct_*` tables (check each table's actual model-name-bearing columns; they vary).

Completion criterion: run completed with full output captured, or the packages.yml change is in flight and the user knows why it's paused.

### 5. Map findings to rule categories

Map each in-scope finding to its rule category — see `references/rule-categories.md` for the full table (test/rule name → category → what it means → typical fix). Group under those categories; do not invent categories the package doesn't define.

Completion criterion: every finding is mapped to a category with at least one in-scope model attached; out-of-scope counts and `not_covered` rules are carried forward, none dropped.

### 6. Report

```markdown
## dbt Project Evaluator: <project>
Scope: <N touched models + M lineage models | full project>

### Summary
| Category | Passed | Failed |
|---|---|---|
| <category> | N | N |

### Findings (grouped by category, worst first)

#### <category>
- <model/source name> — <what the test found, with the count if available>
  - Fix: <concrete remediation — e.g. "move the join in stg_x to int_x", "add a primary key test to fct_y">

### Out of scope
- <N failures on models outside the scope set — one line per rule with its count>

### Not evaluated
- <rules from the script's not_covered list, or package models that errored/were skipped>
```

Completion criterion: every category with at least one failure appears with a concrete fix per finding; categories with zero failures appear only in the summary table, not repeated in Findings.

## Reference

See `references/rule-categories.md` for the dbt_project_evaluator test-name-to-category mapping and remediation patterns per category — load it at step 5, not before.

## Contract

Consumes: a dbt project path (or cwd); optionally a git base ref for scoping, an explicit full-project request, or an explicit warehouse package-run request (with target/profile)
Produces: categorized findings report (markdown) with per-finding remediation
Requires: `dbt` CLI on PATH (only `dbt parse` for the default path); warehouse target only for the explicit package run
Side effects: default path writes `target/manifest.json` locally, nothing else; explicit package run may propose a `packages.yml` addition (routed through normal delivery, not committed directly) and runs `dbt build` against the chosen target
Human gates: confirming the dbt project when ambiguous; the warehouse package run itself (explicit request + non-prod target confirmed); reviewing the `packages.yml` PR if the package wasn't already installed

## Context

Typical workflows: standalone project health check; pre-refactor sanity check alongside `lineage-audit`
Pairs well with: sql-review (per-query issues), lineage-audit (blast radius), data-quality-audit (data-level issues)
