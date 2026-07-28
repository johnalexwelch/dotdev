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
- Any single `NEEDS_HUMAN` → halt this finding, park it in the ledger as `needs_human` with the reason. It is surfaced for a human, never auto-shipped.

Only a fully-`APPROVE`d finding proceeds to Step 4.

## Delivery pipeline (mandatory order)

Each consensus-approved finding runs the full chain. Order is fixed. `workflow-review` and `workflow-finalize` are **required gates** — nothing merges without both.

1. `/workflow-router` — route the finding to the correct execution path.
2. `/to-prd` — PRD from the finding + grill decisions (carry the accepted answers + consensus record).
3. `/to-issues` — slice into grabbable **vertical-slice** issues (never horizontal "build the X layer").
4. `/triage` — label/state issues; runs its own redundancy check first (don't file dupes of existing issues).
5. `/workflow-autonomous-backlog` — implement: **pin behavior (characterization test) → apply → verify (tests + perf baseline)**. Respects outage + delivery policy.
6. `/workflow-review` — **MUST.** Independent, risk-sized review gate.
7. `/workflow-finalize` — **MUST.** PR body → reviewer comments → CI → reconcile → policy-gated final action (draft-wait in `approve` mode; mark-ready/auto-merge only if policy allows and all gates pass; protected repos stay human-only).
8. `/session-insight` — **LOG ONLY.** Reflect on how the run went and append improvement suggestions to the skill/session ledger. **Do not build them this run** — they are candidates for a future run. This keeps today's loop bounded.
9. `/cleanup-delivery` — tear down branches, worktrees, draft PRs, and stale labels for the shipped work.

On any gate failure: **revert, don't escalate** (danger-zones.md). Mark the finding `rejected` or `deferred` in the ledger with the failure reason; do not retry blind.

## Ledger schema — `~/.deep-dive/<repo-slug>.md`

The loop's only long-term memory. One block per finding, appended each run. A new run reads this and skips anything settled.

```markdown
## <YYYY-MM-DD> run  (mode: approve|auto, budget: N)

### FIND-<id>  <lens: deepen|cut|debt|perf>  <short title>
- evidence: <file:line refs>
- c3: churn=<n> complexity=<n> coverage=<n%>  score=<n>
- verdict: done | rejected | deferred | needs_human
- reason: <why — required for rejected/deferred/needs_human>
- consensus: <round count, or needs_human role+reason>
- perf_baseline: <metric + value>   # perf findings only, tracked across runs
- pr: <url>                          # done findings only
- revisit: <YYYY-MM-DD or trigger>   # deferred findings only
```

Rules:
- `done` — shipped, PR linked. Never re-raised.
- `rejected` — deletion test failed / false positive / no signal. Never re-raised (this is the "looks bad but is fine" record).
- `deferred` — real but not now; carries a `revisit` date/trigger. Skipped until due, then re-ranked.
- `needs_human` — parked at a human gate. Surfaced each run until a human resolves it; never auto-shipped.
- `perf_baseline` accumulates across runs so a regression shows as drift from history, not a one-sample scare.
