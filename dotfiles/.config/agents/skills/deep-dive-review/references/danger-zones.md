# Danger zones — hard NEVER-DO list for AFK runs

Bounded-autonomy guardrails (Ouro Loop pattern). These are absolute. An AFK loop that breaks one of these does damage faster than a human can catch it.

## NEVER

- **Never apply without a green behavior pin.** No deepening/refactor becomes work until current behavior is captured in a characterization test at the interface. If behavior can't be pinned, that untestability *is* the finding — surface it, don't refactor blind.
- **Never collapse a trust seam.** Validation, authorization, sanitization, rate/quota checks look like pass-throughs but are load-bearing. They survive as explicit, testable seams or the finding is `needs_human`.
- **Never make a perf change without a profiler trace.** No speculative tuning. No perf claim without a before/after measurement that beats noise.
- **Never regress a hot path** for a refactor. Before/after captured; after within before's budget.
- **Never run on a dirty tree.** Abort preflight if uncommitted changes exist — the loop never entangles its work with human WIP.
- **Never escalate on failure — revert.** A failed verify/gate reverts the change and marks the ledger. No blind retries, no "try a different approach" spirals.
- **Never auto-merge a protected repo.** `human-only` in `repo-delivery-policy.md` overrides `--mode auto`, always.
- **Never skip `/workflow-review` or `/workflow-finalize`.** Both are required gates for every finding.
- **Never build `/session-insight` suggestions in the same run.** Log only; they are future candidates.
- **Never re-raise a `done` or `rejected` ledger entry.** That is oscillation — the failure mode the ledger exists to prevent.
- **Never process more than `--budget N` findings per run.** One run a day, bounded.

## HALT to `NEEDS_HUMAN` when a finding touches

product behavior · public interface · data model · auth/payment · infrastructure · rollout risk · ADR direction · unresolved domain language.

Park it in the ledger with the reason. Surface for a human. Do not proceed.

## One-finding blast radius

Each finding is its own PR (isolatable, revertable). A run may ship several, but a single bad change can never be entangled with the others — revert is always one PR wide.
