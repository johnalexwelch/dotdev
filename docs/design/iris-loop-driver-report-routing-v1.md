# IRIS optimization loop — M3 loop-driver + morning report + routing + state, v1

**Status:** locked 2026-07-28 by 5-round 3-specialist consensus (systems-coherence / IRIS-domain / risk). Map #118. DL-0024. Third and final design surface; joins measure (DL-0022) + explore (DL-0023). Portable loop = DL-0021.

Loop lives in **dotdev**; system-under-test is **IRIS** (`classdojo/iris`, separate repo). `[tunable]` = build constant. **OPEN** = human-input, non-blocking for design but blocking for its route type at runtime.

**Purpose.** Assemble the candidate-generator's ranked top-5 into a morning report, gate it on genuine human approval, route approved items to their real IRIS targets, and persist loop state across runs. **v1 is manual; auto mode is deferred.**

## A. State — single source of truth

Committed JSON `loop/state.json` on a dedicated **`loop-state` branch** in dotdev (not main — DL-0011 blocks direct main pushes; a first-run preflight `gh api repos/johnalexwelch/dotdev/rulesets` confirms the branch is exempt from main-protection). Tracks: baseline pointer `{pinned IRIS commit, judge model, capture date, per-case pass map, P10 floor, permutation null}`; per-case quarantine clocks; approved-not-yet-landed; pending-implementation (Type 4/5 issue items awaiting landing); **landed ledger** `{id, type, diff hash, approval ts, landed ts, merge entry {repo, sha=mergeCommit.oid} OR issue entry {repo, issue_url, closed_at, human_confirmed}, human_edited (immutable)}`; change-counter; sentinel net time-series; suite version; fixture-gap pointer.
Every run reads → appends → commits. Validate schema + **SHA-256 checksum of canonicalized JSON**; refuse to run on malformed/mismatched state. Hand-edits go through `loop state edit` (validate + rehash; blocks changes to `human_edited` on existing entries) or `loop state rehash`. **v1: single-operator + single-machine file lock** (distributed lock deferred).

## B. Run / idempotency

Manual `loop run`, keyed `{suite version + baseline pointer + IRIS-commit + date}`. Lifecycle `started → stub_posted → routed → emitted`.

- **Emitted trigger:** when every candidate has an approve/reject record, the final such invocation triggers `emitted` — commit the full report, update the stub issue, advance quarantine clocks. If candidates remain undecided at the next `loop run`, reconcile expires them and fires `emitted` for the prior run first.
- Same-key re-run is idempotent; a crashed run resumes via the §E crash-resume probe. **Quarantine clocks advance only at `emitted`.**
- **STALE-RUN check** at run start: any run with `status≠emitted` and `date≠today` → warn, listing the stale key + routed-but-open URLs, and surface any candidate with an approval record but no route URL (`loop approve` to retry routing / `loop reject` to abandon). Visibility only.

## C. Morning report — read-only, NOT the approval surface

`loop/reports/YYYY-MM-DD.md` + a dotdev issue (label `loop-report`), two-stage: (1) `stub_posted` — lightweight stub (dedups on date-in-title); (2) `emitted` — full report committed + stub updated with route URLs. Full candidate detail is also emitted to the operator's terminal at `loop run` time (CLI is the live decision surface; the committed report is the async audit artifact). Sections:

1. **Header** — date, IRIS commit, baseline freshness + changes-since-baseline, judge model, suite version, counts, budget.
2. **Loop-health** — sentinel net vs prior run (PASS/HALT), generator≠judge. On FAILURE: emit health section only + **zero candidates** (precedes candidate processing; no `--force`/`--skip-health`).
3. **Top-5** (net desc) — rank, net, type + blast tier, hypothesis, rendered diff, target cluster, full confounder card (cluster N, holdout N, permutation p, FDR q, cross-lane note, SOLE-DOMAIN + flags), fully-resolved route URL. HIGH-blast/cross-lane as a distinct callout above the approval commands.
4. **Cannot-validate** — separate, below the 5; informational; **not `loop approve`-eligible in v1**.
5. **Fixture-gap** queue status (count, oldest age, backlog-halt).
6. **Blind-spot lines** — metric-disambiguation EVAL-INVISIBLE count + examples; budget-exceeded clusters.
7. **Staleness alert** — approvals >30d unlanded; Type 4/5 shown with `[PENDING-IMPLEMENTATION]` (review prompt, not error).
8. **Cumulative-regression banner** — suspect batch + IRIS SHA delta (prior baseline vs refresh); persists until rollback or `loop dismiss-regression <date>` + rationale.
9. **Baseline-refresh-pending banner** at `change-counter == threshold−1` (section-level; cards omit the per-candidate flag this run).
10. **Footer** — `loop approve/reject/edit <date> <id>`; "pending approvals expire when the next `loop run` completes reconcile."

## D. Approval gate — CLI, per-candidate

- **Pre-approval validation:** for Type 2, verify `iris-habit-targets.yaml` is populated for the candidate's scope *before* writing the approval record; else fail `ROUTE-UNRESOLVED-OD2` (no record written).
- `loop approve <date> <id>` writes `{authenticated operator identity, ts, exact diff hash}`; fails `APPROVAL-DEADLINE-EXPIRED` if a newer run key exists. **Routing executes immediately within `loop approve`** (path-existence check, two-phase creation, URL written) before the command returns. **Routing-phase retry:** `loop approve` on an already-approved candidate stuck at `status=routing` with no URL retries only routing.
- `loop reject <date> <id>` writes an explicit rejection to the ledger (audit trail, not delete); also closes a stale approved-not-yet-landed / pending-implementation entry.
- `loop edit <date> <id>` opens the diff in `$EDITOR`; on save validate + rehash, write `{original_hash, edited_hash, human_edited:true}`, then require a separate `loop approve`.
- **DEFAULT = REJECT:** no approval record by deadline = not routed. No rubber-stamp by omission, no batch-approve, **no `--auto-approve` in v1.** Deadline = when the next `loop run` completes reconcile.

## E. Routing — approved → target, one artifact per candidate, never batched, two-phase

Write `status=routing, routing_id=<id>` before creation. **Crash-resume probe** on resume: PRs via `gh pr list --head loop/<date>-<id> --repo classdojo/iris --state open`; issues via `gh issue list --repo classdojo/iris --label loop/<date>-<id> --state open`; if found, record URL + continue; else create. **Path-existence validation** (Types 1/2/3): `gh api repos/classdojo/iris/contents/<path>?ref=<iris-commit>`; if missing, abort `ROUTE-TARGET-STALE` before two-phase (candidate stays approved-not-yet-landed). Write the artifact URL to state before advancing.

- **Type 1** prompt/instruction → PR into iris at the path from `iris-prompt-targets.yaml`, branch `loop/<date>-<id>`, body = hypothesis + confounder card + report link + `[HUMAN-EDITED]` if applicable.
- **Type 2** reflection/habit → PR into iris (v1 PR-only), scoped `{scope, scope_key}`, path from `iris-habit-targets.yaml`.
- **Type 3** tool schema/description → PR into iris at the path from `iris-tool-targets.yaml`; requires a `{target_tool_path}` field.
- **Type 4** retrieval-corpus → human-judgment ISSUE in iris (EVAL-INVISIBLE), label `loop/<date>-<id>` → PENDING-IMPLEMENTATION.
- **Type 5** code → ISSUE in iris (triage-labeled), label `loop/<date>-<id>` → PENDING-IMPLEMENTATION.
- **Fixture-gap** → ISSUE in iris (fixtures live at `backend/src/iris/eval/`), label `fixture-audit` + `loop/<date>-<id>`, links to the dotdev report; created during `emitted`, gated by backlog-halt.

## F. Landed → ledger → baseline

`loop reconcile` runs automatically as the **first step of every run**.

- **PR landing:** merged PRs in iris with branch prefix `loop/` AND `base:default-branch`; extract candidate id from the branch, verify `{repo, mergeCommit.oid}` not already in the ledger (squash-safe dedup) + secondary duplicate-candidate-id check (conflict warning, not silent increment), mark landed, increment change-counter.
- **Issue landing** (Type 4/5): (a) auto-detect requires **closed AND a `loop-landed` label** → verify `issue_url` not already in the ledger, mark landed + increment; closed-without-label → `loop status` prompt, *not* auto-counted (blocks won't-fix/duplicate closures from false increments); or (b) explicit `loop mark-landed <date> <id>` → verify not already landed, mark + increment.
- At `change-counter == [5 tunable]` OR a judge/IRIS model bump: **propose** a baseline refresh (never auto); human confirms → capture records a new baseline pointer + resets quarantine clocks + re-quarantines the pre-refresh holdout set (DL-0023 §E).

## G. Provenance — measuring the measurer

At each refresh, the DL-0023 §J delta-vs-last-baseline check attributes per-case regressions to the batch of ≤5 landed candidates since the last refresh (batch granularity — known limitation); human-edited candidates are included with a `[HUMAN-EDITED]` flag. A newly-regressed case raises CUMULATIVE-REGRESSION + surfaces the suspect batch (IRIS SHA delta) for a human rollback decision (revert the suspect iris PRs + `loop set-counter <n>` + re-capture). Persists in the loop-health banner until rollback or `loop dismiss-regression <date>` + rationale (dismissal ≠ rollback).

## H. Secrets / access

Scoring needs warehouse creds + LLM keys (`--execute --e2e`). v1 uses the operator's local creds from env/secret store; **keys never enter state, reports, PR/issue bodies, or logs.** Preflight verifies write access to iris (branch + PR + issue) *before* scoring; failure aborts with a credential error (`preflight failed: {service}` — no usernames/hostnames/warehouse names). Secret-pattern scrubbing via a curated deny-list (`sk-*`, `sk-ant-*`, `AKIA*`, `xoxb-*`, `postgres://`, `mysql://`, `mongodb://`, `hooks.slack.com`, and any `[A-Za-z0-9]{20,}` adjacent to key/token/secret/password) on all LLM outputs before report/PR. **OPEN:** local vs CI runner.

## I. Auto mode — deferred (slice 6)

v1 is fully human-gated; no auto-approval path exists until the loop has a multi-run track record and a trusted sentinel/health signal.

## J. Recovery runbook

- **Loop PR fails IRIS CI** → `loop reject <date> <id>`; do *not* hand-push to the `loop/` branch — let the generator re-propose.
- **ROUTE-TARGET-STALE** → candidate stays approved-not-yet-landed; resolve the target yaml (OD-1) + re-run `loop approve`, or `loop reject`.
- **ROUTE-UNRESOLVED-OD2** → populate `iris-habit-targets.yaml` then `loop approve` (pre-approval error, no stuck state).
- **Stuck `status=routing`, no URL** → re-run `loop approve` to retry routing, or `loop reject`.

## Open decisions — RESOLVED 2026-07-28 (ground-truth from `classdojo/iris` @ staging)

- **OD-1 — iris prompt paths (RESOLVED, PR-routable):** `iris-prompt-targets.yaml` =
  - `system_prefix` → `backend/src/iris/analyst/prompts.py::AGENT_SYSTEM_PROMPT_PREFIX` (global, cached, HIGH blast — all lanes)
  - `findings_prose` → `backend/src/iris/analyst/prompts.py::GENERAL_ANSWER_SYSTEM_PROMPT` + `INTERNAL_CONTEXT_ANSWER_SYSTEM_PROMPT`
  - `sql_generation` → `mcp-servers/iris/skills/iris-query/SKILL.md` (canonical skills root per `prompts.py::_CANONICAL_PRINCIPAL_DS_SKILLS_RELPATH`; the `backend/src` copy loads *from* here). ⚠ CODEOWNER-gated (OD-3).
- **OD-2 — habit/reflection store (RESOLVED — DESIGN AMENDMENT):** habits/notes are **DB-backed, not files.** IRIS has an `AgentNote` model (`backend/src/iris/db/models.py`) with `NoteScope` = user/table/domain/global (**exactly DL-0023's {scope, scope_key}**), `NoteApprovalStatus` = pending/approved, and `memory/notes.py::append(...)`. **Type 2 therefore does NOT route as a PR:** it calls `notes.append(scope, scope_key, content, approval_status=pending)`; "landing" = a human approving the note in IRIS's existing pending→approved workflow. Replaces the `iris-habit-targets.yaml`/PR path in §D/§E/§F; strictly simpler (reuses IRIS's scope + approval machinery). See §E/§F-amended.
- **OD-3 — branch protection / CODEOWNERS (RESOLVED):** `.github/CODEOWNERS` pins `/mcp-servers/iris/skills/` → **@zach-dojo**. `sql_generation` (Type-1 skill) PRs need @zach-dojo review before merge — `loop approve` is NOT sufficient to land; a second (Zach) gate exists for skill edits (confirms BN-3). `prompts.py` has no observed CODEOWNER rule. Branch-protection API 404'd to the loop token (no admin read) — treat as "CI must pass + CODEOWNER review for skills."
- **OD-4 — runner (RESOLVED: local for v1):** operator's **local machine.** Warehouse + LLM secrets stay local, approval gate is interactive CLI — CI adds secret-management with no benefit. CI deferred to auto-mode.

### §E-amended — Type 2 routing (supersedes the §E Type 2 line)

**Type 2** → `notes.append(scope, scope_key, content, approval_status=pending)` against the IRIS note store (NOT a PR). Two-phase: write `status=routing` → `append` → record the returned note UUID in state before advancing. Crash-resume probe = query the note store for an existing pending note with the same content hash + scope before re-appending. The yaml lookup and `ROUTE-UNRESOLVED-OD2` no longer apply to Type 2; the §D pre-approval check becomes "note-store reachable."

### §F-amended — Type 2 landing (supersedes issue-landing for Type 2)

**Type 2 landing** = the recorded note UUID transitions pending→approved in the IRIS store. `loop reconcile` queries the note store by stored UUID; approved → mark landed `{note_uuid, approved_at}` + increment (dedup on UUID). Still-pending → staleness alert like other unlanded approvals. No merge-commit / `loop-landed`-label path for Type 2.

## Build-notes (implementation guidance, non-blocking)

- BN-1: emitted-transition mutations (quarantine advance, `status=emitted`, final report) must be a single atomic state write before the stub-issue update.
- BN-2: Type 3 would benefit from a symmetric `{target_tool_path}` pre-approval guard (current design surfaces the error at routing time — visible, not silent).
- BN-3: if iris has CODEOWNER-required review, loop PRs need extra GitHub approval before merge — document the expectation.
- BN-4: an optional secondary path-existence check at HEAD (in addition to the pinned commit) would surface target drift before PR creation rather than at merge CI.
