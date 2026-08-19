---
name: workflow-ledger
layer: kernel
user-invocable: false
disable-model-invocation: true
description: Kernel library owning workflow run state, step transitions, and gate stamps via scripts/ledger.sh. Use when a workflow skill needs to record steps, stamp or check a gate (diagnose/fix/review/finalize), reconcile a stale run, or verify local CI parity — never hand-write state.yaml or gate blocks.
---

# Workflow Ledger

Deterministic kernel for workflow enforcement (D-006). One script owns run state; gates are stamped by checks, not prose. Absorbs the former `_docs/step-ledger.md` (reporting protocol), `_docs/state-cockpit.md` (state model), and `_docs/human-gate-taxonomy.md` (gate types).

Full contract with exit codes and test-enforced refinements: `docs/executions/plans/2026-08-19-workflow-ledger-spec.md` (repo) and `test/test-ledger.sh` headers. This doc is the operator summary.

## State model

- **Live state**: `$(git rev-parse --git-dir)/ledger/state.yaml` — survives `reset --hard`; per-worktree automatically. Owned by `ledger.sh`; a hook blocks direct Edit/Write.
- **Committed snapshot**: `docs/executions/state.yaml`, written and committed (`chore(ledger): …`) only by `init`/`stamp`/`close` — the PR-visible audit record.
- Every write is schema-validated; corrupt state is exit 6, never silently rewritten.

## CLI

```
ledger.sh init <run_id> --workflow <w> --kind <k> --steps <csv> [--budget <b>] [--force]
ledger.sh set <step> <status> [--evidence "..."] [--reason "..."]
ledger.sh stamp <gate> [--attest k=v ...] [--override --reason "..."] [--human] [--gate-type <t>]
ledger.sh check <gate>            # exit 0 iff stamped, checks passed/overridden, fresh (see Freshness)
ledger.sh reconcile [--apply]     # ledger vs git ground truth; prints true frontier
ledger.sh preflight --skill <name>
ledger.sh review-floor [--base <ref>]   # prints fast|standard|full — the minimum profile; a path-pattern hit appends +security (floor is then at least standard, e.g. standard+security)
ledger.sh verify-local            # runs docs/executions/ci-commands.yaml at HEAD
ledger.sh show | close
```

Transition rules are code, not convention: required steps cannot be `skipped` (exit 3); `completed|skipped|blocked|failed` require evidence/reason (exit 4); `kind: bug` auto-inserts required `diagnose`/`fix` steps.

## Gates — checked vs attested

A stamp is writable only when every **checked** field passes at stamp time; **attested** fields are recorded verbatim. The model keeps judgment; it loses the ability to report a state that isn't true.

| Gate | Checked (script computes) | Attested |
|---|---|---|
| `diagnose` | `repro_cmd` runs now and exits non-zero (captured) | root_cause, repro_cmd |
| `fix` | same repro_cmd now exits 0; regression test file exists | rationale |
| `review` | worktree verify; chosen profile ≥ `review-floor` — attest the bare word (`fast\|standard\|full`), never the printed `+security` token, which is refused; a `+security`-flagged floor adds a required security lane on top; every required lane file exists with `verdict:` line and an mtime no older than this run's init (a stale lane file from an earlier session is refused); per-lane `model:` ≥ floor; digests recorded | verdict, review_profile, lanes, model_floor |
| `finalize` | `check review` fresh; `git status --porcelain` empty; `verify-local` passed at HEAD; committed snapshot's durable content (run identity, stamps, overrides) matches live state (`snapshot_current`; `check finalize` re-compares it, since a snapshot-only commit is freshness-exempt); via `forge.sh`: CI green, PR state, threads resolved (`no_pr` noted when no PR) | post_mortem, describe_pr, pr_number |

**Freshness is strict, with one content-verified exemption**: `check` fails `STALE` on any commit after the stamp unless that commit touches *only* the committed snapshot file (verified via `git diff-tree` contents — never by commit subject, which is forgeable). A stamp's own snapshot commit is therefore exempt; nothing else is. **Overrides are audited, not prevented**: `--override --reason` stamps with a loud `OVERRIDDEN` marker and an `overrides[]` audit entry; use only on explicit user instruction. The same freshness rule applies: a stale override fails `check` with `OVERRIDE_STALE: … recorded reason: <reason>` — an expired authorization, distinguishable from a gate that never passed.

## Gate types (AFK semantics)

| gate_type | Blocks AFK? | Stampable by |
|---|---|---|
| `reviewer-validation` (default) | no | agent |
| `maintainer-decision` | yes | `--human` only (exit 8 otherwise) |
| `operator-runtime` | yes | `--human` only |
| `secret-custody` | yes | `--human` only |

## Step-ledger reporting protocol

Workflow skills still display an in-conversation `WORKFLOW_STEPS` table (step | required? | status | evidence) at run start, on every transition, and at every halt/handoff/completion — but the durable record is `ledger.sh set`, not the table. The table is a render of the ledger; never let them diverge (run `ledger.sh show` to regenerate).

## Hook integration (workflow-guard.sh)

Merge shapes (`gh pr merge|ready`, `git-forge`/`tea` merge, curl `/pulls/*/merge`) are blocked without a fresh finalize stamp in opted-in repos (`docs/executions/` present). Direct writes to state.yaml are blocked. stderr-suppression on mutating git/gh commands is blocked. Entry warn fires on tracked-code edits with no active run (`LEDGER_ENTRY_ENFORCE=block` escalates; default flips in Phase 5).

## Contract

Consumes: run metadata from the invoking workflow; gate attestations; `docs/executions/ci-commands.yaml` (verify-local); lane review files
Produces: live run state, committed state snapshots, stamp/check results with exit-code API
Requires: git, python3 (yaml); gh or Forgejo token via scripts/forge.sh for finalize forge checks
Side effects: writes git-dir ledger state; commits `chore(ledger):` snapshots; runs repro/verify commands during stamps
Human gates: `--human` for maintainer/operator/secret-custody gate types; `--override` only on explicit user instruction

## Context

Typical workflows: workflow-router (init/reconcile/preflight), workflow-deliver (kind-templated steps; diagnose/fix stamps for kind=bug; records the review stamp for workflow-review's verdict), workflow-review (review-floor only — `layer: judgment`, never stamps), workflow-finalize (check review + finalize stamp + verify-local), run-backlog/execute-prd (read state for AFK monitoring)
Pairs well with: setup-worktree (worktree verify is a review checked field), skill-system-audit (reads stamps for the D-006 scoreboard)
