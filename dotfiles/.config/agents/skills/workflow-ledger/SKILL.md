---
name: workflow-ledger
layer: kernel
user-invocable: false
disable-model-invocation: true
description: Kernel library owning workflow run state, step transitions, and gate stamps via scripts/ledger.sh. Use when a workflow skill needs to record steps, stamp or check a gate (diagnose/fix/review/finalize), reconcile a stale run, or verify local CI parity — never hand-write ledger state files (live state or per-run snapshots) or gate blocks.
---

# Workflow Ledger

Deterministic kernel for workflow enforcement (D-006). One script owns run state; gates are stamped by checks, not prose. Absorbs the former `_docs/step-ledger.md` (reporting protocol), `_docs/state-cockpit.md` (state model), and `_docs/human-gate-taxonomy.md` (gate types).

Full contract with exit codes and test-enforced refinements: `docs/executions/plans/2026-08-19-workflow-ledger-spec.md` (repo) and `test/test-ledger.sh` headers. This doc is the operator summary.

## State model

- **Live state**: `$(git rev-parse --git-dir)/ledger/state.yaml` — survives `reset --hard`; per-worktree automatically. Owned by `ledger.sh`; a hook blocks direct Edit/Write.
- **Committed snapshot (per-run)**: `docs/executions/runs/<run_id>.yaml`, written and committed (`chore(ledger): …`) only by `init`/`set` (when it revokes a gate)/`stamp`/`unstamp`/`flush`/`close` — of which only the gate actions (`init`/`stamp`/`close`) also advance `last_seen_sha` — the PR-visible audit record. One file per run: concurrent runs never commit a shared path, which ends the cross-PR merge conflicts the old single snapshot caused (#167/#174/#180/#181).
- **Legacy record**: `docs/executions/state.yaml` is frozen history — never written or read by new runs, and it satisfies no gate.
- Every write is schema-validated; corrupt state is exit 6, never silently rewritten.

## CLI

```
ledger.sh init <run_id> --workflow <w> --kind <k> --steps <csv> [--budget <b>] [--route "<classification>|<selected-flow>|confirmed"] [--force]
ledger.sh set <step> <status> [--evidence "..."] [--reason "..."]
ledger.sh stamp <gate> [--attest k=v ...] [--override --reason "..."] [--human] [--gate-type <t>]
ledger.sh unstamp <gate> --reason "..."   # revoke a stamp (exit 1 if unstamped, 4 without a reason, 10 if the publish failed and the revocation was rolled back)
ledger.sh flush                   # publish steps/metadata to the snapshot with no gate semantics (exit 1 on a closed run, 6 if gate state diverges from the record)
ledger.sh check <gate>            # exit 0 iff stamped, checks passed/overridden, fresh (see Freshness)
ledger.sh check-snapshot <gate> [--file <path>]   # CI mode: same stamp+freshness verdict against a committed per-run snapshot, minus the live-state drift compare; --file names the run file (the finalize-stamp CI job passes candidates from the PR diff), else the live run's file, else exactly one runs/*.yaml
ledger.sh reconcile [--apply]     # ledger vs git ground truth; prints true frontier
ledger.sh preflight --skill <name>
ledger.sh review-floor [--base <ref>]   # prints fast|standard|full — the minimum profile; a path-pattern hit appends +security (floor is then at least standard, e.g. standard+security)
ledger.sh verify-local            # runs docs/executions/ci-commands.yaml at HEAD
ledger.sh show | close

relay.sh --handoff <file> [--max-legs N=5] [--repo <path>] [--stop-file <path>]
```

`relay.sh` is the handoff relay runner: it chains headless `claude -p` legs through a handoff file, continuing only on AFK-eligible exit_reasons (`completion-with-follow-ups`, `halt-for-continuation`) and stopping on completion (incl. the live ledger `<git-dir>/ledger/state.yaml` reaching `status: done` during the relay — a pre-existing `done` at launch is stale and ignored), human gates (NEEDS_HUMAN / needs-human / maintainer-decision / operator-runtime / secret-custody / `blocker:`), no-progress (handoff sha unchanged), max-legs, the stop-file kill switch, or a leg error — distinct exit codes 0/2/3/4/5/6, plus 1 for usage errors. Operator doc: the handoff skill's "Relay" section. Tested by `test/test-relay.sh`.

Transition rules are code, not convention: required steps cannot be `skipped` (exit 3); `completed|skipped|blocked|failed` require evidence/reason (exit 4); `kind: bug` auto-inserts required `diagnose`/`fix` steps.

**Revocation.** A gate stamp may only stand while its same-named step is `completed`: `set diagnose|fix|review|finalize <anything-else>` revokes that gate, and `unstamp <gate> --reason` is the explicit path. Both delete the stamp, append `{gate, action, reason, timestamp, head_sha, revoked_head_sha, gate_type, revoked_checked}` to `overrides[]`, and publish — so `check <gate>` cannot keep returning OK after an unwind, in live state or in the PR-visible record. The entry supersedes the stamp rather than erasing it: `head_sha` is the revocation-time HEAD, while `revoked_head_sha`/`gate_type`/`revoked_checked` preserve the revoked stamp's own identity and digests, so a revoke → re-stamp cycle is diffable. Revocation is **atomic**: if publishing the snapshot fails, live state, the snapshot file, and the committed record are all restored to the stamp standing (exit 10, message says the revocation did not apply) — a revocation that cannot reach the record must not remove authority either, because `check-snapshot` and the CI finalize-stamp job read only the record. Revocation is not terminal: the gate can be re-earned by stamping again.

**Publishing without a gate.** `flush` publishes `steps` and metadata to the committed snapshot and commits it, carrying no gate authority in either direction. It cannot refresh or stale a stamp (a snapshot-only commit is freshness-exempt) and it leaves `last_seen_sha` alone, so it cannot launder drift out of `reconcile`. Nor can it *publish* a stamp: `stamps` and `overrides` are in the durable tuple, and `flush` **refuses** (exit 6, naming the divergent key) when live state and the committed record disagree there. Refuse, not repair — the only ways that divergence arises are a hand-edited live state or a kernel bug, and publishing either would make it canonical and silence the `snapshot_current` tamper check. `flush` also refuses a closed run (exit 1): a settled audit record is not reopened by a no-gate publish. This is how a corrected `set --evidence` string ships; hand-editing the script-owned snapshot is not (a hook blocks it).

**Route evidence (D-006 Phase 5b).** `init --route` records the confirmed ROUTE_CARD's classification and selected flow as a top-level `route:` field (workflow-router passes it at ledger-persist). Absent: init succeeds with a `WARNING: no route evidence — invoke workflow-router` line; `LEDGER_REQUIRE_ROUTE=block` escalates absence to a refusal (exit 11) — the same warn-then-flip pattern as entry enforcement. Malformed route strings (not `<classification>|<selected-flow>|confirmed`) are schema-invalid (exit 6) at init and on every load.

## Gates — checked vs attested

A stamp is writable only when every **checked** field passes at stamp time; **attested** fields are recorded verbatim. The model keeps judgment; it loses the ability to report a state that isn't true.

| Gate | Checked (script computes) | Attested |
|---|---|---|
| `diagnose` | `repro_cmd` runs now and exits non-zero (captured) | root_cause, repro_cmd |
| `fix` | same repro_cmd now exits 0; regression test file exists | rationale |
| `review` | worktree verify; chosen profile ≥ `review-floor` — attest the bare word (`fast\|standard\|full`), never the printed `+security` token, which is refused; a `+security`-flagged floor adds a required security lane on top; every required lane file exists with `verdict:` line and an mtime no older than this run's init (a stale lane file from an earlier session is refused); every lane verdict normalizes (CR/trailing space/case) to `approve` — `REQUEST_CHANGES`, `NEEDS_HUMAN`, and any unrecognized token refuse the stamp; the **first** `verdict:` line wins, so a reviewer quoting `verdict: REQUEST_CHANGES` in prose cannot sink a legitimately-approving lane; per-lane `model:` ≥ floor; digests recorded | verdict, review_profile, lanes, model_floor |
| `finalize` | `check review` fresh; `git status --porcelain` empty; `verify-local` passed at HEAD; committed snapshot's durable content (run identity, stamps, overrides) matches live state (`snapshot_current`; `check finalize` re-compares it, since a snapshot-only commit is freshness-exempt); via `forge.sh`: CI green, PR state (`open`\|`draft` passes), threads resolved (`no_pr` noted when no PR) | post_mortem, describe_pr, pr_number |

**Freshness is strict, with one content-verified exemption**: `check` fails `STALE` on any commit after the stamp unless that commit touches *only* this run's own committed snapshot file, `docs/executions/runs/<run_id>.yaml` (verified via `git diff-tree` contents — never by commit subject, which is forgeable). A stamp's own snapshot commit is therefore exempt; nothing else is — a commit touching a different run's file or the legacy `state.yaml` reads STALE. **Overrides are audited, not prevented**: `--override --reason` stamps with a loud `OVERRIDDEN` marker and an `overrides[]` audit entry; use only on explicit user instruction. The same freshness rule applies: a stale override fails `check` with `OVERRIDE_STALE: … recorded reason: <reason>` — an expired authorization, distinguishable from a gate that never passed.

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

Merge shapes (`gh pr merge|ready`, `git-forge`/`tea` merge, curl `/pulls/*/merge`) are blocked without a fresh finalize stamp in opted-in repos (`docs/executions/` present). Direct Edit/Write to ledger state is blocked — the git-dir live state, any `.yaml`/`.yml` under `docs/executions/runs/` at any depth (the kernel only authors flat, allowlist-named files, so anything else there is by definition hand-written), and the legacy `state.yaml`. stderr-suppression on mutating git/gh commands is blocked. Entry warn fires on tracked-code edits with no active run (`LEDGER_ENTRY_ENFORCE=block` escalates; default flips in Phase 5).

## Contract

Consumes: run metadata from the invoking workflow; gate attestations; `docs/executions/ci-commands.yaml` (verify-local); lane review files
Produces: live run state, committed state snapshots, stamp/check results with exit-code API
Requires: git, python3 (yaml); gh or Forgejo token via scripts/forge.sh for finalize forge checks
Side effects: writes git-dir ledger state; commits `chore(ledger):` snapshots; runs repro/verify commands during stamps
Human gates: `--human` for maintainer/operator/secret-custody gate types; `--override` only on explicit user instruction

## Context

Typical workflows: workflow-router (init/reconcile/preflight), workflow-deliver (kind-templated steps; diagnose/fix stamps for kind=bug; records the review stamp for workflow-review's verdict), workflow-review (review-floor only — `layer: judgment`, never stamps), workflow-finalize (check review + finalize stamp + verify-local), run-backlog/execute-prd (read state for AFK monitoring)
Pairs well with: setup-worktree (worktree verify is a review checked field), skill-system-audit (reads stamps for the D-006 scoreboard)
