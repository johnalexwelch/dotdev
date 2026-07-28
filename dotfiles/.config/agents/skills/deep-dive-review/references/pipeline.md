# Grill consensus, delivery pipeline, ledger schema

## Specialist consensus loop

Extends `workflow-autonomous-backlog` §3.1 from a single critic to a role panel. The owning skill's grill (e.g. `improve-codebase-architecture` Step 3) runs in **accept-recommended** mode first and produces recommended answers with evidence. The panel then validates those answers **before** they become work.

Panel (read-only subagents — must NOT edit files, write artifacts, create ADRs, update CONTEXT.md, or author the final recommendation):

| Role | Guards against |
|---|---|
| architecture/depth | shallow deepening, collapsed seams, lost locality |
| ponytail (lazy/YAGNI) | over-engineering the *fix itself* — applies the ponytail audit lens (`delete`/`stdlib`/`native`/`yagni`/`shrink`) to the proposed change: could this be fewer lines, a stdlib/native call, or not exist at all? |
| security+risk | collapsed trust seam, auth/data/rollback risk, secret exposure |
| performance | hot-path regression, unmeasured perf claim |

Each reviewer returns one verdict:

- `APPROVE` — recommendation is evidence-backed, no gate tripped for this role.
- `REJECT` — a specific evidence gap or contradiction to revise (must name it).
- `NEEDS_HUMAN` — touches product behavior, public interface, data model, auth/payment, infra, rollout risk, ADR direction, or unresolved domain language.

**Loop to consensus:**

- Parent agent orchestrates rounds; reviewers do not free-chat. Each round passes only: finding summary, evidence refs, accepted answers, prior reviewer reasons, and what changed since last round.
- `max_rounds: 3`, no override. Consensus = every reviewer `APPROVE`.
- Same rejection class twice → halt `NEEDS_HUMAN`.
- Any single `NEEDS_HUMAN` → halt this finding, park it in the ledger as `needs_human` with the reason **and a required `unblock:` line** — the exact decision, the literal steps to clear it, and what the tool does once unblocked (or the verdict if declined). A parked finding is never a dead end: the human always gets a concrete way forward. It is surfaced for a human, never auto-shipped.

Only a fully-`APPROVE`d finding proceeds to Step 4.

## Delivery pipeline (mandatory order)

Each consensus-approved finding runs the full chain. Order is fixed. `/workflow-review`, the **final necessity gate**, and `/workflow-finalize` are **required gates** — nothing merges without all three.

1. `/workflow-router` — route the finding to the correct execution path.
2. `/to-prd` — PRD from the finding + grill decisions (carry the accepted answers + consensus record).
3. `/to-issues` — slice into grabbable **vertical-slice** issues (never horizontal "build the X layer").
4. `/triage` — label/state issues; runs its own redundancy check first (don't file dupes of existing issues).
5. `/workflow-autonomous-backlog` — implement: **pin behavior (characterization test) → apply → verify (tests + perf baseline) → reconcile tests → sync docs**. *Reconcile tests* = delete tests the change orphaned (zombies) and add tests for any new seam/interface it introduced — a green suite is necessary, not sufficient. *Sync docs* = docstrings, inline cross-refs, and any ADR/CONTEXT/user doc the change touches. Respects outage + delivery policy.
6. `/workflow-review` — **MUST.** Independent, risk-sized review gate.
7. **Final necessity gate** — **MUST, run-level.** After every selected finding reaches this point, one skeptical read-only reviewer sweeps the *combined produced diff* (not the pre-work hypothesis). See "Final necessity gate" below. `SHIP` proceeds; `REVERT` drops the branch and logs the finding `rejected`.
8. `/workflow-finalize` — **MUST.** PR body → reviewer comments → CI → reconcile → policy-gated final action (draft-wait in `approve` mode; mark-ready/auto-merge only if policy allows and all gates pass; protected repos stay human-only).
9. `/session-insight` — **LOG ONLY.** Reflect on how the run went and append improvement suggestions to the skill/session ledger. **Do not build them this run** — they are candidates for a future run. This keeps today's loop bounded.
10. `/cleanup-delivery` — tear down branches, worktrees, draft PRs, and stale labels for the shipped work.

On any gate failure: **revert, don't escalate** (danger-zones.md). Mark the finding `rejected` or `deferred` in the ledger with the failure reason; do not retry blind.

## Final necessity gate

Runs **once per run**, after all selected findings pass `/workflow-review` and before any `/workflow-finalize`. One read-only reviewer (no edits, no artifacts) re-audits the *actual produced diff* per finding against four questions — the guard the pre-work ranking can't do because the change didn't exist yet:

1. **Premise survived?** Re-verify the finding's evidence against the real diff. Classic failure: a "coverage=0, unlocks tests" deepen finding where the target was already covered by direct unit tests — the benefit evaporates once checked. Premise now false → **REVERT**.
2. **Needed building? (ponytail rung 1)** Did this need to exist at all? A change to working, covered code whose cost of inaction is **flat** (not decaying) is churn for aesthetics → **REVERT**. Deletion beats addition; a delegating shim added only to keep old tests passing is a smell, not a win.
3. **Tests reconciled?** No zombie tests orphaned; every new seam has a test. Else → back to implement, or **REVERT**.
4. **Docs synced?** Docstrings, cross-refs, and any touched ADR/CONTEXT/user doc updated. Else → back to implement.

Verdict per finding: `SHIP` (proceed to finalize) or `REVERT` (drop the branch; mark the ledger `rejected` with `reason: necessity gate — <premise-false | flat-cost | unnecessary-build>`; record it in the "looks bad but is fine" set so tomorrow skips it). This gate never edits code — it only ships or reverts. It is the last line against false positives and building where nothing needed building.

## Ledger schema — `~/.deep-dive/<repo-slug>.md`

The loop's only long-term memory. Two parts: a **Timeline** journal (chronological, one line per run — the "what did we do, are we looping?" view) and per-finding blocks (the settled-ground record). A new run reads both: the Timeline in Step 0 for loop detection, the blocks in Step 2 to skip settled findings.

```markdown
# Deep Dive ledger — <repo-slug>

## Timeline   (append-only, newest at bottom — read in Step 0 for loop detection)
- <YYYY-MM-DD> run(<mode>,b<N>)  scanned:<lenses> ranked:<n>  shipped:<ids+pr> reverted:<ids+reason> rejected:<ids+reason> deferred:<ids> parked:<ids>

## Findings   (one block per finding, appended each run)

### FIND-<id>  <lens: deepen|cut|debt|perf>  <short title>
- fingerprint: <lens>:<file>:<line>:<signal-slug>   # stable identity across runs — loop detection keys on this
- evidence: <file:line refs>
- c3: churn=<n> complexity=<n> coverage=<n%>  score=<n>
- verdict: done | rejected | deferred | needs_human
- reason: <why — required for rejected/deferred/needs_human>
- consensus: <round count, or needs_human role+reason>
- perf_baseline: <metric + value>   # perf findings only, tracked across runs
- pr: <url>                          # done findings only
- revisit: <YYYY-MM-DD or trigger>   # deferred findings only
- unblock: <decision> | <literal steps to clear it> | <what the tool does once unblocked, and the verdict if declined>   # REQUIRED on every needs_human finding
- history: <YYYY-MM-DD verdict> ; <YYYY-MM-DD verdict> ...   # appended, never overwritten — shows a finding's own arc (e.g. done → reverted)
- decision_log: <docs/decision-log.md#anchor>   # consequential not-dos only
```

### Loop detection (Step 0, keyed on `fingerprint`)

The Timeline plus per-finding `history` make redone/undone work visible. Flag and treat as `needs_human` (do not auto-reprocess) when:

- **undo** — a fingerprint previously `done` reappears as a finding. We may be reverting shipped work; a human confirms it's intended before re-touching.
- **re-raise** — a `rejected` fingerprint is scanned again. The ledger should have skipped it; recurrence means Step 2's filter or the fingerprint is off — fix that, don't rebuild.
- **chronic defer** — a `deferred` fingerprint bounced ≥3 runs without action. Escalate: decide or drop it, stop carrying it.
- **churn loop** — the same file appears in our own shipped PRs across ≥3 runs. Our changes are becoming the churn signal that re-nominates the file. Pause that file.

History is append-only: a finding's block accumulates its `history` line across runs, so `done → reverted → re-nominated` is legible at a glance rather than reconstructed from scattered run sections.

Rules:

- `done` — shipped, PR linked. Never re-raised.
- `rejected` — deletion test failed / false positive / no signal. Never re-raised (this is the "looks bad but is fine" record).
- `deferred` — real but not now; carries a `revisit` date/trigger. Skipped until due, then re-ranked.
- `needs_human` — parked at a human gate. Surfaced each run until a human resolves it; never auto-shipped.
- `perf_baseline` accumulates across runs so a regression shows as drift from history, not a one-sample scare.
