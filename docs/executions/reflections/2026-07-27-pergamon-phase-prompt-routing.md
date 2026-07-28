# Session Reflection: Pergamon Phase Prompt Routing
**Date**: 2026-07-27
**Goal**: Evaluate and correct a Pergamon phase work-order prompt using the workflow router and repo source of truth.

## What Went Well
- The first pass checked Pergamon's canonical docs before accepting the attached prompt's phase claim. Evidence: the prompt said runtime secret management was Phase 4, but `docs/roadmap.md`, D-005, `platform/secrets/README.md`, and the Phase 3 final review all placed runtime vault work in Phase 5.
- The correction stayed small. The final answer retitled the work order to Phase 5, updated PRD numbering to `005.x`, added vault product selection, and tightened Phase 6/8 boundaries instead of redesigning the whole roadmap.
- The user's supplied holistic roadmap was treated as routing input, then reconciled with the earlier repo evidence instead of replacing it blindly.

## What Went Wrong / Friction
- The initial `workflow-router` response emitted a full route card and halted for `workflow-roadmap`, which was procedurally valid but heavier than the user likely needed for a prompt-evaluation/correction loop.
- Once the user clarified "correct it please," the work naturally became prompt revision, but the earlier route card had framed it as roadmap dispatch. That mismatch suggests the router could distinguish "evaluate/correct a prompt" from "mutate project roadmap artifacts" more explicitly.

## Corrections
| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | "ill pass you the remaining phases so we can evaluate things holistically" | The first evaluation correctly found the Phase 4/5 conflict, but did not wait for the user's broader roadmap context before presenting a next workflow. | `workflow-router` |
| 2 | "correct it please" | The immediate user need was prompt correction, not dispatch into roadmap execution. | `prompt-builder` / `workflow-router` boundary |

## Lessons
1. **Prompt correction is not always workflow dispatch**: When a user asks to evaluate a prompt and names the router, the router should classify whether the output is a conversational prompt rewrite or a project artifact mutation. Only the latter needs full dispatch.
2. **Canonical docs still win, but user-provided roadmap can be reconciliation input**: The repo source of truth caught the phase error; the user's holistic roadmap confirmed the intended corrected shape.
3. **Phase-boundary prompts need ownership checks**: The useful review lens was not prose quality alone, but whether each phase owned exactly one layer and did not pull adjacent phase work forward.

## Proposed Improvements
- [ ] `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/workflow-router/SKILL.md` — Add a rule under workflow intake: if the request is to evaluate or rewrite a prompt/work order and no repo artifact mutation is requested, route as `direct` or `prompt-builder` output; emit a full non-direct route card only if the user asks to create/update project artifacts, issues, PRDs, or roadmap files. Evidence: this session's first route card was valid but too heavy for "correct it please." (priority: med)
- [ ] `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/prompt-builder/SKILL.md` — Add a phase-boundary checklist for repo-specific work-order prompts: verify canonical roadmap, decision log, prior phase review, artifact ownership, adjacent-phase boundaries, and numbering before rewriting. Evidence: the corrected Pergamon prompt needed Phase 5 numbering, D-005 alignment, Phase 6 identity boundary, and Phase 8 hardening boundary. (priority: med)
