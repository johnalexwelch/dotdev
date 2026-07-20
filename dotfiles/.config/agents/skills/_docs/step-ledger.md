# Step Ledger Protocol

Canonical progress-reporting protocol for workflow skills. Skills reference this
doc with `follow \`_docs/step-ledger.md\`` (D-003 library grammar) and keep only
their own `WORKFLOW_STEPS` table rows and any skill-specific skip/gate rules.
Persistence of the ledger (router `state.yaml` writes) is owned by
`_docs/state-cockpit.md`; this doc owns only the in-conversation reporting
protocol.

## Template

At the start of every run, display a step ledger before executing or
dispatching any step. Use the exact step names from the invoking skill and
include conditional or optional steps.

```markdown
WORKFLOW_STEPS:
| Step | Required? | Status | Evidence / Skip Reason |
|------|-----------|--------|------------------------|
| <step name> | required|conditional|optional | pending|completed|skipped|blocked|failed|not_applicable | <evidence, reason, or -> |
```

## Rules

- Initialize every known step as `pending`; conditional steps remain `pending`
  until their trigger is evaluated.
- As each step finishes or is skipped, update the ledger with the new status
  and evidence or reason.
- A step may be `skipped` only when the invoking skill explicitly makes it
  optional/conditional or a routing decision stops the workflow; record the
  exact reason.
- Do not mark required gates as skipped. If a required gate cannot run, mark it
  `blocked` or `failed` and halt according to the invoking workflow.
- At every halt, STOP, handoff, and final completion, include the final ledger
  in the response or artifact.
- The final ledger must distinguish `completed`, `skipped`, `blocked`,
  `failed`, and `not_applicable`, and every non-completed status must include a
  reason.

Skills may add their own rules below their table (e.g. which steps can never be
skipped, gate blocks required for `completed`). Skill-specific rules extend
this protocol; they never relax it.
