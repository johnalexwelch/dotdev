---
name: airflow-failure-rca
layer: judgment
disable-model-invocation: true
description: 'Evidence-first root-cause triage for Airflow task failures: counts rank, logs diagnose — no fix is prescribed without a real error_detail. Use when investigating airflow failures, "why is this DAG failing", resilience hotspots, or a task instance failing repeatedly.'
---

## Contract

Consumes: Airflow REST API v2 base URL + token (the internal host needs VPN); optional time window and DAG/task filters
Produces: ranked offender list; per-offender diagnosis citing a real `exc_type`/`exc_value` from a specific task instance; classification per offender (code/config bug · monitor-firing-correctly · transient infra); fix proposals gated on classification
Requires: HTTP access to the Airflow API (curl or equivalent)
Side effects: read-only API calls; no DAG, task, or config mutation
Human gates: fix proposals are recommendations only — applying any fix routes through the normal delivery workflow

## Context

Typical workflows: standalone triage; feeds incident-triage or a resilience audit
Pairs well with: diagnose (single hard bug after RCA points at code), incident-retro

# Airflow Failure RCA

**Evidence-first** triage: failure *counts* say that something failed and how often — never *why*. Counts RANK, logs DIAGNOSE, and no fix gets prescribed without the failure's `error_detail`. A resilience audit without log evidence is a guess list (2026-08-04: 8 retry-based recommendations, ~all overturned once logs were read — the flagship "add retries" target already had `retries=5` and was dying at `try_number=6` on `InvalidResourceStateFault`).

## Process

### 0. Verify `error_detail` availability (fleet check)

The structured `error_detail` field may be a dojo task-listener extension rather than generic Airflow. Run this check on the **first log fetch of step 2** (any failed TI from the step-1 pull works): confirm the "Task failed with exception" event carries `error_detail[0]` with `exc_type`/`exc_value`. If absent on this fleet, fall back to parsing the traceback from the flat log text — the discipline (logs before fixes) is unchanged, only the extraction.

Done when: one sample log confirms which extraction path this installation supports.

### 1. Rank — batch-pull and order the offenders

Pull `failed` + `upstream_failed` task instances for the window in one batch. Rank by (dag, task) volume, and separately group `upstream_failed` by day/run to expose cascades — many distinct (DAG, day) failures collapsing onto few days at synchronized run-times is a shared-fate signature, not many independent bugs.

This step is **ranking only, not diagnosis**. Nothing here justifies a fix.

Done when: a ranked offender list exists, with cascade clusters marked.

### 2. Diagnose — pull the log evidence per offender

For each top offender, fetch the log of the **last real attempt** and extract `exc_type`, `exc_value`, and the last stack frames (via `error_detail[0]` or the step-0 fallback). API pitfalls that make this one-shot instead of three attempts:

| Pitfall | Rule |
|---|---|
| `error_detail` location | It is a per-event field on the "Task failed with exception" log *item*, not in the flat log text |
| Mapped tasks (`expand_kwargs`) | Include `&map_index=N` (from the TI) or the log fetch returns empty |
| `run_id` in URLs | URL-encode it — `:` and `+` break the path otherwise |
| Attempt numbering | Treat it as uncertain — `try_number` in the API can be one past `max_tries`; if the log fetch at `try_number` returns empty, retry the adjacent index rather than concluding "no log" |

Done when: every top offender has a captured `exc_type`/`exc_value` from a specific TI (non-empty log for mapped tasks).

### 3. Read retry semantics before touching retry config

Compare `try_number` vs `max_tries`: `try_number > max_tries` means all retries were burned — the fault outlasted the retry window, so **do not add more retries**. "Add retries" is almost always the wrong reflex: it masks real outages (delays going red), and does nothing when retries already exist or the fault is deterministic (auth, schema, code). Retry tuning fits only genuinely transient infra — a minority.

Done when: each offender is marked retry-exhausted / retry-never-configured / failed-first-try, from API fields, not config guesses.

### 4. Classify, then (and only then) prescribe

Classify each offender from its log evidence:

| Class | Signature | Fix direction |
|---|---|---|
| Code/config bug | Deterministic exception (schema drift, lock timeout, auth/PAM misconfig, bad SQL) | Fix the code/config; retries are noise |
| Monitor firing correctly | The "failing" task is an assertion/canary and its check is genuinely red | Fix the *upstream* condition; retrying hides the signal — a monitor failing is a signal, not a bug |
| Transient infra | Fault outside the DAG that self-heals (instance rebooting, host unreachable, spot loss) | Retry/backoff tuning, or dependency-aware scheduling for shared-fate cascades |

Done when: every proposed fix cites a real `exc_value` from a specific TI — not a count, not a config guess.

### 5. Report

Deliver: ranked list, per-offender classification + evidence quote, fix proposals. If costs are estimated, use explicit editable knobs (eng $/hr, triage min/incident, compute $/hr) — separate human-triage cost and data-trust cost from compute noise; no fake precision.

Done when: the report contains zero fix proposals lacking cited log evidence.
