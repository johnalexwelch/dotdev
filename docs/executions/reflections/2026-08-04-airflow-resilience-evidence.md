# Session Reflection: Airflow resilience audit — proxy fixes vs log evidence

**Date**: 2026-08-04
**Goal**: Use 30 days of Airflow failure history to find resilience hotspots and propose fixes.

## What Went Well

- Fast fleet-wide triage: one batch pull of failed/upstream_failed TIs (5,911 over 30d) ranked offenders and exposed cascade structure.
- Cost model with explicit editable knobs (eng $/hr, triage min/incident, compute $/hr) instead of fake precision — separated real cost (human triage ~$36k/yr, data trust) from noise (compute ~$1.7k/yr).
- Cascade signature recognized from data alone: 212 distinct (DAG,day) DMS failures collapsing onto **3 days** at synchronized run-times → shared-fate hypothesis, later confirmed by logs.

## What Went Wrong / Friction

- **Reached for "add retries" as the default fix across ~8 candidates without reading a single task log.** Failure *counts* + a glance at config were treated as sufficient to prescribe a fix.
- The flagship recommendation (#2 DMS: "add retries") was **flat wrong** — the DMS factory already sets `retries=5, retry_delay=90s`. Failures died at `try_number=6` (all retries exhausted). Only reading logs revealed the true cause: `InvalidResourceStateFault … instance is not Active` (shared replication instance mid-reboot).
- Pulling logs took two iterations to get right (missed `error_detail` structured field first; then missed `map_index` for mapped canary tasks) — worth encoding so it's one-shot next time.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | "always get hard evidence" (after DMS retry fix proven wrong) | Prescribed fixes from proxy (counts+config) instead of ground truth (task logs) | new: airflow failure root-cause skill |

## Lessons

1. **Logs are the spec for failures.** Failure counts and config say *that* something failed and *how often* — never *why*. Every one of 8 "resilience" items had a distinct real cause once logs were read; ~none was the retry-tuning I first proposed (vacuum-on-MV bug, masking schema drift, delete lock timeout, Spark timeout, 2 monitors correctly firing, an unreachable host, a PAM auth misconfig). A resilience audit without log evidence is a guess list.
2. **"Add retries" is almost always the wrong reflex.** It masks real outages (delays red), and does nothing when retries already exist or the fault is deterministic (auth, schema, code). Retry only fits genuinely transient infra — a minority.
3. **A monitor failing is a signal, not a bug.** Several top "failures" were monitors doing their job; the fix is upstream, and retrying them would hide the signal.

## Proposed Improvements

- [ ] New skill `airflow-failure-rca` (see extraction candidate) — codify evidence-first triage: counts to *rank*, logs to *diagnose*, before any fix. (priority: high)
- [ ] Fold a one-line guard into any resilience/debug flow: "never prescribe a fix for a task failure without its `error_detail`/log." (priority: med)

## Skill Extraction Candidates

- **Proposed skill**: `airflow-failure-rca` · **target**: `~/dotdev/dotfiles/.config/agents/skills/airflow-failure-rca/SKILL.md` · **invocation**: model|user
  - **Trigger / leading word**: "airflow failures", "why is this DAG failing", "resilience hotspots", "task instance failing"
  - **Inputs**: Airflow REST API v2 base + token; optional time window and DAG/task filters
  - **Steps**:
    1. Batch-pull failed + upstream_failed TIs for the window; rank by (dag,task) volume and by cascade (upstream_failed grouped by day/run) — *ranking only, not diagnosis*. ✓ ranked list produced.
    2. For each top offender, fetch the log of the last real attempt and extract the structured `error_detail[0]` (`exc_type`, `exc_value`, last frames). ✓ real exc_type/exc_value captured per task.
    3. For **mapped** tasks (`expand_kwargs`), include `&map_index=N` (from the TI) or the log fetch returns empty. ✓ non-empty log for mapped canary tasks.
    4. Use `try_number` vs `max_tries` to detect retry-exhausted vs config: `try_number > max_tries` ⇒ all retries burned ⇒ fault outlasted the retry window (do NOT add more retries). ✓
    5. Classify each: real code/config bug · monitor-firing-correctly · transient infra. Prescribe fix only after classification. ✓
  - **Success criteria**: every proposed fix cites a real `exc_value` from a specific TI, not a count or a config guess.
  - **Constraints / pitfalls**: `error_detail` is a per-event field on the "Task failed with exception" log item, not in the flat text; mapped tasks need `map_index`; run_id must be URL-encoded (`:` and `+`); `try_number` in the API can be one past `max_tries`; internal host needs VPN.
  - **Verification evidence**: this session — DMS root cause (`InvalidResourceStateFault … not Active`) + 7 other distinct causes extracted, overturning the initial retry-based audit.
  - **Quality gate**: googleable=No · specific=Yes · real-effort=Yes
  - **Open questions**: does a generic Airflow install expose `error_detail` identically, or is it partly a dojo task-listener extension? (verify before generalizing beyond this fleet)
