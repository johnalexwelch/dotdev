# Audit Mode Reference

Use audit-mode for refactor-scale work driven by a `/repo-audit` report.
The plan is anchored on stable `FIND-NN` IDs.

## Input Resolution

Resolution order:

1. If `audit_path` is set, load it and enter audit-mode.
2. If neither `audit_path` nor `brief` is set, look for the newest `docs/audits/*-repo-audit.md` and use it.
3. If no audit exists, stop and tell the user to run `/repo-audit` first or re-invoke with `brief="..."` for bug/feature work.

Abort if both `audit_path` and `brief` are set; they are mutually exclusive.

## Preflight

- Confirm the workspace is a git repo. If not, abort.
- Check the audit for `FIND-NN` IDs.
- If the audit lacks `FIND-NN` IDs, proceed but note in §2 that cross-references are position-based and recommend re-running `/repo-audit` for full traceability.
- Warn at the top of §4 if the audit is older than 14 days. Recommend re-running `/repo-audit` before execution.
- Derive the output slug from the audit's `path-slug` if the audit is scoped and the user did not override `output_path`.
- In draft mode, if `output_path` already exists and is not empty, ask whether to overwrite, date-suffix, or abort. Default to date-suffix (`<original>-v2.md`).
- Ensure `docs/plans/` exists.
- Read `README.md`, `CLAUDE.md`, and any root `*_SPEC.md` to pick up project conventions.

## Frame Extraction

Open the audit and extract:

- **Overall state** — one-paragraph honest read.
- **Findings (`FIND-NN`)** — the full list with severities. This drives task-to-finding cross-references in the plan.
- **Top three** — the critical items the plan must address first.
- **Biggest gaps and risks** — shapes rollback planning.
- **Implementation patterns** — the best-built piece, which new work should mirror.
- **Recommended next steps** — raw ordered backlog to turn into phases.

Keep this in working memory while drafting.

## Audit-Mode Drafting Rules

- §2 Problem cites concrete pain and `FIND-NN` evidence.
- §5 Addresses lines use `FIND-NN`, or `n/a` for hygiene phases.
- §8 Delete list accounts for every file flagged as legacy or superseded in the audit.
- §10 Definition of done includes "Every `FIND-NN` from the audit is either addressed or explicitly deferred to a future plan."
- A pilot/canary is not optional for refactor-scale audit plans unless explicitly waived in `constraints` with reasoning in §1.

## Audit-Mode Error Handling

| Failure | Behavior |
|---------|----------|
| Not in a git repo | Abort. |
| No audit found and no brief set | Stop. Tell user to run `/repo-audit` first or re-invoke with `brief="..."`. Do not audit inline. |
| Both `audit_path` and `brief` set | Abort. They're mutually exclusive. |
| Audit lacks `FIND-NN` IDs | Proceed but note position-based cross-references in §2. Recommend re-running `/repo-audit`. |
| Audit older than 14 days | Warn at top of §4. Recommend re-running `/repo-audit` before executing. |
| Existing plan at `output_path` | Ask: overwrite, date-suffix, or abort. Default date-suffix. |

## Audit-Mode Example Invocation

```text
User: /design-plan
Claude: [preflight — finds docs/audits/2026-04-20-repo-audit.md with
         FIND-01 through FIND-14]
        [asks: what does done look like? what are your constraints?]
User: Ship a working refactor that kills the legacy scripts and moves
      memory to Obsidian. Solo dev, no hard deadline, tests must stay
      green every commit.
Claude: [drafts plan, self-reviews]
        [writes docs/plans/2026-04-20-design.md]

        6-phase plan. Pilot validates one workflow end-to-end before
        legacy deletion. Deletes 3,946 lines. Resolves FIND-01 through
        FIND-09 and FIND-13.

        Phases:
          §5.0 Phase 0 — Preflight (4 auto, 1 human)
          §5.1 Phase 1 — Pilot: /morning slash command (5 auto, 2 human)
          §5.2 Phase 2 — Skill scaffolding (/prep, /triage) (8 auto, 1 human)
          §5.3 Phase 3 — Replace legacy scripts (6 auto, 0 human)
          §5.4 Phase 4 — Integration consolidation (7 auto, 1 human)
          §5.5 Phase 5 — Memory → Obsidian split (4 auto, 2 human)
          §5.6 Phase 6 — Docs + test catch-up (3 auto, 0 human)

        Two §9 open questions need your call before Phase 1:
          - Which memory files go to Obsidian vs. stay in repo?
          - Keep launchd or move to a simpler scheduler?

        Full plan: docs/plans/2026-04-20-design.md
```
