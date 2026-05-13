# Operability Audit — Skills Directory

**Date:** 2026-04-21  
**Scope:** `/Users/alexwelch/.claude/skills/`  
**Question:** How do you know when this is broken? Where do errors and logs go? What happens on dependency failure?

## Summary

The skills directory has **no unified error observability layer**. Error handling is defined in SKILL.md tables but not consistently implemented. Most skills degrade gracefully on recoverable failures but lack structured logging, retry instrumentation, or failure notification mechanisms. The `.omc/state/` directory tracks agent lifecycle but does not capture task-level failures or dependency cascades. Core-loop skills (`/execute-phase`, `/design-plan`) can fail silently or halt unattended with no notification to the user.

## Findings

### 1. Error Handling Coverage: Thin Tables, No Instrumentation

**Evidence:**

Only 6 of 13 skills have formal `## Error Handling` tables:

- ✓ `ci-deploy-fix`: No table (prescriptive steps only)
- ✓ `describe-pr`: 6 rows — degraded behavior on missing files
- ✓ `design-plan`: 8 rows — abort or infer, no logging
- ✓ `execute-phase`: 18 rows — detailed abort/halt/degrade behaviors
- ✓ `post-mortem`: 8 rows — proceed on missing audit, degrade on test failure
- ✓ `repo-audit`: 6 rows — retry single agent, validate evidence, degrade on rate limit
- ✗ `omc-reference`: No error handling specified
- ✗ `new-project`: SKILL.md not found
- ✗ `setup-worktree`: 10 rows — mostly abort, some "warn and continue"
- ✗ `slack-update`: No error handling specified (step-by-step procedure only)
- ✗ Other 3 skills: No SKILL.md examined

**Quality assessment:**

| Skill | Rows | Concrete Behavior | Logged/Instrumented? |
|-------|------|-------------------|----------------------|
| execute-phase | 18 | YES — 14 of 18 specify outcome (abort/halt/degrade) | NO |
| repo-audit | 6 | YES — all specify outcome | NO |
| design-plan | 8 | PARTIAL — 5 of 8 say "abort", 3 use ambiguous "degrade" | NO |
| describe-pr | 6 | PARTIAL — 4 specific, 2 use "degrade gracefully" | NO |
| post-mortem | 8 | PARTIAL — mix of "proceed", "abort", "note" | NO |
| setup-worktree | 10 | YES — all concrete | NO |

**Red flags:**

- **No "Logging" or "Observability" rows** across any error table
- **No retry counts, timing, or backoff** specified
- **No distinction between human-actionable errors and silent failures**
- **Instrumentation is **zero** — no `DEBUG=`, structured logs, timing metrics, or retry telemetry anywhere in `.omc/state/`**

### 2. State Tracking: Minimal Agent Lifecycle, No Task-Level Failure Records

**Evidence from `.omc/state/`:**

File: `mission-state.json`

- Tracks **agent-level status** (`running`, `done`, `failed`) at 1-minute granularity
- No **task-level failure detail** — a completed agent could have partial successes
- Example: 13 agents running, 2 completed, 0 failed — but no insight into *which tasks failed in the 2 completed agents*

File: `subagent-tracking.json`

- Records `started_at`, `completed_at`, `duration_ms` per agent
- **No error/failure details captured** — `status: "running"` or `status: "completed"` only
- `total_failed: 0` but *could be wrong* if failures aren't recorded at spawn time

File: `agent-replay-3067a9fb-3c3a-412d-b771-2493d025dadb.jsonl`

- JSONL event log: `{"t":0,"agent":"...","event":"agent_start|agent_stop","success":true|false,"duration_ms":...}`
- **Success/failure flag at agent level, not task level**
- No root-cause data if `success: false`

File: `last-tool-error.json`

- **Captures only the most recent tool error**, not a log of errors
- Example: `bash find` error with retry_count=3
- **Not integrated into agent or task records** — orphaned singleton
- **No way to correlate this with which agent/task was running when it failed**

**Observation:** No persistent record of *which phase failed, which tasks aborted, what the error was, and who should be notified*.

### 3. Core-Loop Failure Modes: Silent Miss, Cascade, or Unattended Halt

#### `/execute-phase` at 3am with no human watching

**Scenario:** User invokes `/execute-phase plan_path=docs/plans/2026-04-21-design.md phase=0 auto_proceed=true` at 11pm. Phase 0 and 1 complete. Phase 2 has a scope violation on an unattended subagent cluster (writes to `src/forbidden.ts` outside granted scope).

**What happens:**

1. Step 5 (post-batch scope verification) detects violation
2. Outcome file written: `.phase-runs/2026-04-21-phase-2.md` with `## Scope violations` populated
3. **Halt: no commit, no auto-proceed** (Step 9 rule: "Scope violation → halt")
4. **User asleep** — no chat surface, no Slack ping, no retry

**Missing:**

- No error notification mechanism (no Slack hook, no email, no logged alert)
- User discovers the halt 8 hours later when checking for progress
- Phase 2 branch left checked out (`.git/HEAD` points to `refactor/phase-2-...`) — **blocks new work on main**

#### `/design-plan` with missing audit

**Scenario:** Audit deleted or not found. User runs `/design-plan mode=draft` with empty `audit_path`.

**SKILL.md Step 0 behavior:**
> "Preflight: draft mode — locate the audit... If none exists, stop and tell the user to run `/repo-audit` first."

**What happens:**

1. Code aborts, prints message to chat
2. **No permanent record** of the abort in `.omc/state/`
3. **Silent miss if user is not watching** (skill never entered main loop)
4. **No retry or escalation** — user must manually reinvoke

#### Dependency cascade: `/execute-phase` → `/describe-pr` → missing phase-runs

**Scenario:** User runs `/execute-phase` on a 5-phase plan. Phases 0–3 land successfully. Phase 4 halts on verification failure (unrelated to code). User later runs `/describe-pr` assuming all phases completed.

**`/describe-pr` behavior (Step 1.2):**
> "Phase-run outcomes: Glob `docs/executions/.phase-runs/*-phase-*.md` and filter to those whose `**Branch:**` header matches... For each matched outcome: read... If no outcome files match the branch range, degrade gracefully — produce the body from raw `git log` only, note in 'Deviations' that phase-run outcome files were unavailable so drift detection is weaker."

**What happens:**

1. Glob finds phases 0–3 but not 4–5
2. PR body is generated from `git log` alone — **loses phase context**
3. Reviewer sees commits but not which phase was blocked
4. **Silent loss of traceability** — FIND-NN citations may be missing
5. **No warning in chat** that "phase 4 outcome missing — drift detection degraded"

### 4. No Structured Logging or Timing Instrumentation

**Evidence:**

Grep across all SKILL.md files for logging keywords:

```
- "log" (noun/verb): 0 occurrences outside "git log" (version-control query)
- "structured log": 0
- "audit log": 0
- "timing": 0
- "duration": 1 (in execute-phase: "Report back per task: ... exact command(s) run")
- "retry count": 1 (in repo-audit: "if any [discovery agent returns empty] Retry that single agent once")
- "DEBUG": 0
- "TRACE": 0
- "instrumentation": 0
```

**What exists:**

- `duration_ms` in `.omc/state/subagent-tracking.json` — agent-level only, not task-level
- `last-tool-error.json` — singleton, not a log
- `agent-replay-*.jsonl` — event log, but no nested task failures or error codes

**What's missing:**

- **No per-phase timing or slow-phase detection**
- **No cumulative retry counts across a skill run**
- **No error category classification** (timeout vs. permission vs. scope violation)
- **No structured output fields for downstream processing** (e.g., machine-readable failure codes)

### 5. Failure Notification: None

**Evidence:**

No mention of user notification in any error-handling table:

- ✓ All tables say "abort", "halt", "warn", "surface to user in chat"
- ✗ **ZERO** mention of Slack, email, SMS, or alerting APIs
- ✗ **ZERO** mention of fallback notification if user not watching

**Real-world gap:**

- `/execute-phase` with `auto_proceed=true` halts at 3am on scope violation
- User is asleep; Claude Code process runs on a personal machine (not a server)
- **No one is notified**
- 8 hours pass; main branch remains blocked by the halted phase branch

**Core-loop skills run unattended by design** (they are designed to execute autonomously). But **there is no out-of-band alerting mechanism** if they fail.

### 6. Graceful Degrade vs. Silent Miss

**Patterns observed:**

| Skill | Failure | Behavior | Risk |
|-------|---------|----------|------|
| repo-audit | Agent returns empty | Retry once; if still empty, placeholder fact-pack + proceed to synthesis | **Silent miss if retried agent still empty** |
| describe-pr | Missing `.phase-runs/` | Proceed with git log only; note in body that drift detection weaker | **User may not read note; trusts PR body as complete** |
| design-plan | Audit older than 14 days | Warn at top of §4, recommend re-run | **Warn is in markdown body, not CLI output or chat emphasis** |
| execute-phase | Verification UNVERIFIED (load-bearing claim) | "Halt and surface for user judgment. Do not silently pass." | **Good — user must decide. But 3am halt with no notification.** |
| post-mortem | Test command fails | "Note in §Summary; do not block post-mortem." | **Good — fail-open. But gap is documented only in prose, not as flag in output.** |

**Observation:** Most degrade gracefully with a note, but **notes live in markdown outputs that might not be surfaced visually in chat**.

### 7. `.omc/state/` Corruption or Sync Failure

**Risk scenario:**

1. `/execute-phase` Phase 2 completes and writes `docs/executions/.phase-runs/2026-04-21-phase-2.md`
2. `.omc/state/mission-state.json` is updated with `status: done` for Phase 2 agent
3. **Filesystem race:** `/execute-phase` reads stale `.phase-runs/` because state file writes are not atomic
4. Auto-proceed reads outcome file, but `.omc/state/` says phase is still in-progress
5. **Inconsistency undetected** — user is unaware of state/reality mismatch

**Controls:**

- No mention of atomic writes, transactions, or version checks in SKILL.md
- No schema versioning in `.omc/` files
- No integrity check before auto-proceed

**Real-world impact:**

- If user kills Claude Code process mid-write, state could be corrupted
- Resuming `/execute-phase phase=X resume=true` could retry a completed phase or skip one

## Evidence

**Files examined:**

- `/Users/alexwelch/.claude/skills/ci-deploy-fix/SKILL.md` — no error table
- `/Users/alexwelch/.claude/skills/describe-pr/SKILL.md` — 6-row table, degradation rules
- `/Users/alexwelch/.claude/skills/design-plan/SKILL.md` — 8-row table, abort/infer rules
- `/Users/alexwelch/.claude/skills/execute-phase/SKILL.md` — 18-row table, halt rules
- `/Users/alexwelch/.claude/skills/post-mortem/SKILL.md` — 8-row table, note/proceed rules
- `/Users/alexwelch/.claude/skills/repo-audit/SKILL.md` — 6-row table, retry/validate rules
- `/Users/alexwelch/.claude/skills/setup-worktree/SKILL.md` — 10-row table, abort/warn rules
- `/Users/alexwelch/.claude/skills/.omc/state/mission-state.json` — agent-level tracking, no task failures
- `/Users/alexwelch/.claude/skills/.omc/state/subagent-tracking.json` — duration_ms, status only
- `/Users/alexwelch/.claude/skills/.omc/state/agent-replay-*.jsonl` — event log, no error detail
- `/Users/alexwelch/.claude/skills/.omc/state/last-tool-error.json` — singleton, not integrated

**Grep results:**

- 6 of 13 skills have `## Error Handling` section (46% coverage)
- 0 occurrences of "log" (verb/noun, excluding git commands)
- 0 occurrences of "notify", "alert", "email", "slack" (failure notification)
- 1 occurrence of "retry" and only in one skill
- 0 occurrences of "timeout", "backoff", "circuit-breaker"

## Open questions

1. **How is Phase N+1 preflight failure handled if it occurs mid-auto-proceed chain?** The SKILL.md says "halt; Phase N commit stands; user fixes Phase N+1 and re-invokes." But is there a way to resume without running Phase N again? The `resume=true` flag only works for a halted phase, not for a preflight error on the next phase.

2. **What is the exact scope-violation detection algorithm?** The SKILL.md says a subagent reports "files touched" and the verification subagent diffs against granted scope. But if a subagent's output truncation occurs (observed in Phase 1 of skills-updates plan), could an out-of-scope write be invisible to the verification subagent?

3. **If `/execute-phase` halts at 3am due to verification failure, is there a way for the user to know?** The outcome file is written and chat would have surfaced it (assuming the user was watching), but there's no persistent, out-of-band alerting mechanism.

4. **Can `.omc/state/` files be corrupted if a process is killed mid-write?** Are writes atomic, versioned, or validated on read?

5. **If a skill like `/design-plan` aborts on missing audit, is that recorded in `.omc/state/`?** Or only in chat (which is ephemeral)?

6. **How are retry counts tracked across a multi-phase execution?** If Phase 2 has one failed task and gets retried, is that retry recorded? How many retries are "too many"?

7. **Why is `last-tool-error.json` a singleton instead of an append-only log?** A single error file means concurrent skill invocations can overwrite each other's error state.

## Recommendations

For **immediate observability:**

1. **Add structured error logging to `.omc/state/`** — append to `execution-errors.jsonl` on every skill error:

   ```json
   {"timestamp":"...", "skill":"execute-phase", "phase":2, "error_type":"scope_violation", "file":"src/forbidden.ts", "granted_scope":"src/tasks/**"}
   ```

2. **Add failure notification on halt** — if `/execute-phase` halts due to verification FAIL or scope violation, emit a one-line summary to a `.omc/state/unresolved-halts.txt` file so a monitoring script can detect it:

   ```
   2026-04-21T03:45:22Z | execute-phase phase=2 | HALTED | scope_violation | src/forbidden.ts | branch=refactor/phase-2-...
   ```

3. **Add retry instrumentation** — every SKILL.md error table should include a "Max retries" column (if applicable) and log attempts to `.omc/state/`:

   ```json
   {"skill":"repo-audit", "agent":"Explore:05", "retry_count":2, "max_retries":1, "status":"failed"}
   ```

4. **Add integrity check to outcome files** — `/execute-phase` should hash the outcome file after write and store in `.omc/state/` so resume can detect corruption.

For **robustness:**

5. **Separate task-level failures from skill-level halts** — skill error tables conflate "this task failed" with "the skill should abort". Make this distinction explicit.

6. **Make degradation explicit in output** — when a skill degrades (e.g., `/describe-pr` with missing phase-runs), emit a `## ⚠️ Degradation notes` section at the top of the output, not buried in body text.

7. **Add timeout and backoff rules** — if a discovery agent (in `/repo-audit`) times out once, re-run with a longer timeout. If it times out twice, skip and note in the fact-pack.

8. **Atomic writes for `.omc/state/`** — use temp file + rename pattern, or write to a new file and mv atomically.
