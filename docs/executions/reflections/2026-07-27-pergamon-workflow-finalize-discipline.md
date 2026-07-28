# Session Reflection: Pergamon Workflow Finalize Discipline
**Date**: 2026-07-27
**Goal**: Reflect on the issue #58 session mechanics and identify concrete improvements to workflow skills and handoff/finalize habits.

## What Went Well
- The session eventually followed the requested workflow chain: `workflow-router`, `workflow-build-one`, `workflow-review`, `workflow-finalize`, and `handoff`.
- The finalization respected the human gate. Even though the user said "merge", issue #58 carried `needs-human-review`, so the work was routed to a draft PR instead of direct merge.
- The agent used live checks instead of static claims at the end: PR state was read from GitHub, the local worktree was checked clean, and the QA URL was verified through `/healthz`.
- Browser/mobile QA became explicit after the user corrected that the agent can launch and traverse sites. That produced concrete runtime evidence instead of asking the user to do all validation.
- Validation was split into a focused `chorus-operator-surface-check` plus full `just validate`, answering the user's concern that full validation on every small change was too slow.
- The handoff skill was followed carefully at the end: repo copy, stable global mirror under `/Users/alexwelch/.chorus/handoffs/pergamon/`, and a resume line.

## What Went Wrong / Friction
- The user had to explicitly restate the workflow stack: "PLEASE ENSURE THAT WE ARE FOLLOWING /workflow-router and go through /workflow-build-one ... this hasnt been happening for the last few iterations." This indicates workflow invocation was not reliably automatic across iterations.
- The user had to prompt capability use: "You have the ability to launch sites and traverse them." The agent should have treated runtime/browser traversal as part of acceptance validation for an operator surface.
- The "merge" instruction needed policy arbitration. The agent correctly did not merge, but the workflow could make this less conversationally awkward by explicitly treating `needs-human-review` as a hard override of ordinary merge language.
- Finalization had several manual confirmation steps: mirror handoff, state update, PR body, PR status, checks status, runtime health, clean status. These were correct, but the sequencing is repetitive and easy to drift on.

## Corrections
| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | "PLEASE ENSURE THAT WE ARE FOLLOWING /workflow-router and go through /workflow-build-one ... /workflow-review ... /workflow-finalize" | Workflow-router/build/finalize gates were not prominent enough as mandatory entry/exit checks on Pergamon issue work. | `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/workflow-router/SKILL.md` |
| 2 | "You have the ability to launch sites and traverse them" | Browser QA capability was treated as optional/user-owned instead of agent-owned when the deliverable is a runnable surface. | `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/user-journey-qa/SKILL.md` |
| 3 | "is there a way we can speed up validation... do we need to?" | Validation guidance did not push early enough for a layered validation ladder: focused check first, full validation at gates. | `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/workflow-build-one/SKILL.md` |
| 4 | "ok so merge and then lets handoff..." while the issue still had `needs-human-review` | Finalize workflow needs an explicit rule for natural-language merge requests that conflict with issue labels. | `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/workflow-finalize/SKILL.md` |

## Lessons
1. **Workflow names in the user prompt are hard requirements**: When the user names workflow skills, the agent should make the gate sequence visible in state and final output, not merely comply internally.
2. **Human-review labels override merge verbs**: "Merge" is not sufficient authority when the issue or PR carries `needs-human-review`; finalize should create/keep a draft PR and say so plainly.
3. **Validation should be a ladder**: For repeated iteration, a focused target should run after small changes; full validation belongs at review/finalize boundaries or after shared/infrastructure changes.
4. **Runnable surfaces require agent-side traversal**: If the agent can launch and inspect the surface, it should own basic route traversal, viewport checks, and health checks before asking the user for QA.
5. **Handoff is part of finalize, not cleanup**: When remaining work is human-gated, the handoff should be committed with `state.yaml` so the next session has durable state and does not re-derive context.

## Proposed Improvements
- [ ] `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/workflow-router/SKILL.md` — Add a "named workflow stack" rule: if the user names `workflow-router`, `workflow-build-one`, `workflow-review`, `workflow-finalize`, or `handoff`, record the required sequence in `docs/executions/state.yaml` before implementation/finalization and report the gate verdicts in the final response. Evidence: user correction that this "hasnt been happening for the last few iterations." (priority: high)
- [ ] `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/workflow-finalize/SKILL.md` — Add a "merge verb vs human gate" clause: if the user says merge but the issue/PR has `needs-human-review`, finalization must stop at draft PR or ready-for-human state, cite the label, and hand off human QA steps. Evidence: issue #58 was draft-human-gated despite a merge request. (priority: high)
- [ ] `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/workflow-build-one/SKILL.md` — Add a validation-ladder default: define focused validation after narrow changes, full validation at review/finalize gates, and live/runtime validation only when the change affects deployed surfaces or integrations. Evidence: user asked whether full validation was needed for every change, and the session benefited from `chorus-operator-surface-check`. (priority: high)
- [ ] `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/user-journey-qa/SKILL.md` — Add a runnable-surface default: when a local or tunneled URL exists and browser tooling is available, agent must perform smoke traversal across key routes and desktop/mobile viewports before declaring "ready for user QA." Evidence: user reminded the agent it could launch/traverse sites. (priority: med)
- [ ] `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/handoff/SKILL.md` — Add a workflow-finalize reminder: when handoff is caused by a human-gated PR, include PR state, issue label state, validation commands, QA URL, stop commands for any running preview, and commit the repo copy with `state.yaml` if the current branch is the delivery branch. Evidence: final handoff required several manual confirmation steps. (priority: med)

## Skill Extraction Candidates
- **Proposed skill**: `runtime-surface-qa` · **target**: `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/runtime-surface-qa/SKILL.md` · **invocation**: model
  - **Trigger / leading word**: Invoked by `user-journey-qa` or `workflow-review` when a deliverable exposes a local, tunneled, preview, or production URL.
  - **Inputs**: URL, expected health endpoint or readiness signal, key routes, viewport list, expected source/build identity, stop/cleanup command if the runtime was launched by the agent.
  - **Steps**:
    1. Confirm the runtime is reachable through the authoritative URL and record the health/readiness payload.
    2. Traverse declared key routes using browser automation or Playwright.
    3. Check desktop and mobile viewport layout for blank screens, console errors, excessive horizontal scroll, clipped content, and route load failures.
    4. Capture at least one desktop and one mobile screenshot when the surface is visual.
    5. Record QA evidence in a durable execution artifact and summarize what remains for human QA.
    6. If the runtime is left up, record the exact URL, process/service identity, and stop commands in the handoff.
  - **Success criteria**: Health/readiness passes, key routes render, no blocking console errors, no mobile clipping in the checked viewport, screenshots or equivalent visual evidence exist, and human QA scope is explicitly narrowed.
  - **Constraints / pitfalls**: Do not confuse a static build pass with a live runtime pass; verify source/build identity when the runtime can serve stale assets; do not leave long-running processes undocumented.
  - **Verification evidence**: The session verified `/healthz`, traversed desktop and mobile routes through `http://127.0.0.1:4178/`, checked `scrollWidth`/clipping, and left stop commands in the handoff.
  - **Quality gate**: googleable=No · specific=Yes · real-effort=Yes
  - **Open questions**: Whether this should be a new standalone skill or folded into `user-journey-qa` as a dedicated "runtime surface" section.
