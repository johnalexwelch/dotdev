# Session Reflection: Rowan Soak Parallel Work via Taskflow

**Date**: 2026-08-11
**Goal**: Complete parallel work during Rowan LiteLLM soak — agent env prep, docs cleanup, delegate-mode grill for open decisions

## What Went Well

- Taskflow shorthand mode (`task` + `agent`) worked smoothly for complex single-agent delegation
- Delegate-mode grill achieved 100% consensus on 11 decisions (F67–F77) without human escalation
- Parallel agent env prep completed efficiently (mira, cleo, wren)
- Handoff skill produced clean, resumable documentation

## What Went Wrong / Friction

- **Forgejo URL guess was wrong** — presented `http://127.0.0.1:3000` when service was actually on `localhost:3001` via SSH tunnel. Should have verified with `lsof -i :3001` before presenting URLs.
- **Taskflow reduce phase interpolation failed** — multi-phase flow with `{steps.draft-questions.json}` in downstream phases produced empty context. Reduce phase's `from` field worked structurally but specialists couldn't access upstream output. Fell back to single-agent approach.
- **hypa_shell comment parsing bug** — `# Get Forgejo URL` as first line caused "No such file or directory" error. Workaround: use plain `bash` tool or avoid leading comments.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | "those urls are broken" | Assumed port 3000 from earlier session context; didn't verify SSH tunnel forwarding | No owning skill — ad-hoc URL presentation |
| 2 | "remove IRIS from consideration" | Included Iris in agent list despite user saying to remove it | Listening failure, not skill gap |

## Lessons

1. **Verify services before presenting URLs**: SSH tunnels, Docker port mappings, and dev servers have dynamic ports. Run `lsof -i :<port>` or `curl -s -o /dev/null -w "%{http_code}"` before claiming a URL works.

2. **Taskflow reduce-phase interpolation is fragile**: When specialists need upstream JSON output, the `{steps.X.json}` interpolation didn't propagate. A single-agent with full context in the task prompt is more reliable for grill workflows.

3. **Single-agent executor outperformed specialist routing for grills**: The delegate-mode grill concept (analyst + security-reviewer + risk-reviewer in parallel) added orchestration overhead without improving decision quality. A single executor wearing multiple "hats" in one task achieved the same consensus faster.

## Proposed Improvements

- [ ] `grill-with-docs/SKILL.md` — Add note: "For taskflow-based delegate mode, prefer single-agent executor with explicit 'wear specialist hats' instruction over multi-phase specialist routing. The orchestration overhead doesn't add value for most grill batches." (priority: med)
- [ ] `taskflow/SKILL.md` — Document limitation: "Reduce-phase `from` gathers outputs, but downstream `{steps.X.json}` interpolation may fail to propagate content. For reliable specialist handoff, use explicit `context` file paths or single-agent consolidation." (priority: med)

## Skill Extraction Candidates

*None this session.* The delegate-mode grill worked, but it's already documented in `grill-with-docs`. The taskflow limitation is a documentation fix, not a new skill.
