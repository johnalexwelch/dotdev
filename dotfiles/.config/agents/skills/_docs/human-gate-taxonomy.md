# Human-Gate Taxonomy

Classification of human-approval gates in AFK execution workflows. Distinguishes gates by their blocking power and satisfaction mechanism.

## Governing Principle

**Default = AFK.** Only three gate types block AFK execution by default. `reviewer-validation` gates NEVER block AFK and must not receive `needs-human-review` by themselves. They are satisfied by independent reviewer consensus via `workflow-review`, required verification, CI, and the repo's merge policy.

## The Four Gates

| Gate Type | Description | Blocks AFK? | How Satisfied |
|-----------|-------------|------------|---------------|
| **maintainer-decision** | User/maintainer approval of architectural, product, or security decision. Requires explicit sign-off. | ✅ YES | User approves PR or issue before merge |
| **operator-runtime** | Runtime operational action: secret provisioning, deploy gate, live mutation, incident response. Requires human operator to execute or validate. | ✅ YES | Operator confirms action in workflow; recorded in PR/issue |
| **secret-custody** | Secret management decisions: rotation, access grants, new key material. Requires explicit human custody/audit. | ✅ YES | Operator or DRI approves before secret is deployed |
| **reviewer-validation** | Independent code/design review validation. Agent may implement and validate; reviewers ensure quality via PR review, commands, screenshots, or checks. | NO | Non-authoring approval + all required checks green (verified by `workflow-review`) |

## Usage in Skills

When a skill detects a human gate, it MUST classify the gate type:

- **to-issues**: splits `Human review` output into `Maintainer/operator gate` (types 1–3) vs `Reviewer validation` (type 4); only types 1–3 may apply `needs-human-review`
- **describe-pr**: notes gate type when reviewing AFK PR eligibility; `reviewer-validation` alone does not make a PR un-AFK
- **prompt-builder**: emits `execution_mode`, `human_review_gate`, and `acceptance_gate` separately; allows "AFK implementation with human PR review" (execution AFK + reviewer-validation gate)
- **setup-skills**: defaults new projects to AFK-capable; maps per-repo label vocabulary to gate types

## Evidence

Decision history: `docs/executions/reflections/2026-07-26-pergamon-afk-human-gates.md` (root cause: conflation of maintainer approval with code review).

Related decisions: D-005 (worktree baseline deepening); see `_docs/decision-log.md` for the full archival.
