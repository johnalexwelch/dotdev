# Agents — Workflow Skill System

Vocabulary for dotdev's workflow-skill machinery: the router, gates, and
ledgers that plan, execute, review, and finalize work in this repo. See
`CONTEXT-MAP.md` at the repo root for the sibling `brain` context.

## Language

**Router** (`workflow-router`): the sole routing authority for incoming work.
Classifies a request, presents a Route Card, runs preflight, dispatches to the
target workflow skill. See `docs/adr/0002-sole-routing-authority.md`.
_Avoid_: "the dispatcher", "the classifier".

**Route Card**: the router's proposed classification + budget + gates for a
request, shown for user confirmation before any non-trivial dispatch.

**Budget**: the router's chosen execution shape for a request — `direct`,
`one-reviewer`, `multi-lane`, or `team`. Determines default review profile.

**Gate**: a named, evidence-block-producing checkpoint a workflow must satisfy
before proceeding (e.g. `WORKTREE_BASELINE_GATE`, `WORKFLOW_REVIEW_GATE`,
`WORKFLOW_FINALIZE_GATE`). A gate is satisfied only when its evidence block is
actually emitted — a skill claiming "basically ran" without the block is
treated as not run.

**Step Ledger**: the `WORKFLOW_STEPS` table a workflow skill maintains
(`required|conditional`, `pending|active|done|skipped|blocked|failed`) plus
the rules for when a conditional step may be skipped.

**Worktree Baseline**: the invariant that mutating workflows run inside a
worktree cut from a resolved base ref (never the primary checkout or local
`main`/`staging`), enforced by `WORKTREE_BASELINE_GATE`.

**Delivery Policy** (`REPO_DELIVERY_POLICY`): the repo-level rules a workflow
must follow when shipping change — review profile, PR sizing, finalize gate.

**State Cockpit** (`docs/executions/state.yaml`): the single machine-readable
record of the active run, letting any agent resume where a prior session
stopped. Schema owned by `_docs/state-cockpit.md`; do not duplicate it inline
in skills.

## Relationships

- A **Router** classification produces one **Route Card**, which the user
  confirms before dispatch.
- Every mutating workflow must satisfy the **Worktree Baseline** gate before
  any other gate.
- A workflow's **Step Ledger** is persisted into the **State Cockpit** on
  dispatch and read back on resume.

## Example dialogue

**Dev:** "Can `workflow-build-one` skip the worktree check if it's a tiny fix?"

> **Router:** "No — Worktree Baseline is a gate, not a suggestion. `direct`
> budget only applies to read-only work that mutates nothing; anything that
> commits or pushes needs at least `one-reviewer` and the gate."

## Flagged ambiguities

- "Audit Loop" (older prose/handoffs) has no execution route of its own —
  translate it into a real gate: code review → `workflow-review`, delivery
  closure → `workflow-finalize`. Do not treat "Audit Loop" as a distinct
  concept in this glossary.
