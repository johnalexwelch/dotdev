# Session Reflection: Cost Audit → Skills Cleanup Sprint

**Date**: 2026-08-25
**Goal**: Analyze July-August cost increases; identify root causes; implement cost controls and simplify skill system

## What Went Well

- **Data-driven root cause analysis**: Traced $729 cost spike to single session (102 subagents) without speculation
- **Progressive discovery**: Cost audit → workflow compliance problem → skill bloat → simplification sprint
- **User-driven prioritization**: Deleted skills based on actual usage (zero-invocation patterns), not assumptions
- **Hook-based enforcement**: Moved prose rules into workflow-guard.sh (Rules A-H) for mechanical enforcement
- **Canonical chain clarification**: User stated their workflow (grill → to-prd → to-issues → triage → tdd) and we enforced it

## What Went Wrong / Friction

- **CodeMapper unavailable**: `cm` command not found, fell back to grep/find (minor delay)
- **Screenshot access blocked**: Could not read user's temp-file screenshot of Claude costs; worked around with alternate data sources
- **i-have-adhd deletion mistake**: Deleted it, then user said they wanted it — had to restore and make it always-on
- **Multiple verification rounds**: Several skills required checking callers before deletion; could have batch-checked upfront

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|-------------------------|------------|-------------------|
| 1 | "I want i-have-adhd kept and made default-on" | Assumed disabled=unused without asking | session-insight (verify preference before deleting behavior skills) |
| 2 | "OMC should not be in use" | Stale global CLAUDE.md still referenced OMC | CLAUDE.md maintenance |
| 3 | "to-prd is part of my canonical workflow chain" | Assistant didn't ask about actual usage before proposing deletions | skill-system-audit (ask about actual usage patterns) |
| 4 | "Delete workflow-feature and workflow-skill" | Assistant was conservative; user wanted more aggressive cleanup | workflow-router (prefer simpler over preserve-all) |

## Lessons

1. **Verify preferences before deleting behavior/persona skills**: Skills like i-have-adhd and caveman affect output style — deletion should require explicit confirmation even when metadata says "disabled."

2. **Prose rules drift into non-enforcement**: The Aug 17 session had ROUTE_CARD in its context but spawned 102 subagents anyway. Prose guidance is a suggestion; hook enforcement is a gate. The 8 new Rules (A-H) are the fix.

3. **Skill count is a cost driver**: 105 skills → 34 skills. Every skill is context tokens. Trimming 67% of skills isn't just cleanup — it's cost reduction.

4. **Canonical workflow chains should be explicit**: User stated "grill → to-prd → to-issues → triage → tdd". This wasn't documented as THE chain; multiple parallel workflows existed. Making it explicit let us delete the alternatives.

5. **Disabled skills aren't dead weight by default**: `disable-model-invocation: true` means "not auto-routed from prompts" but the skill can still be loaded by other skills. Need to verify caller graph before deletion.

6. **Cost analysis surfaces compliance problems**: Started as "why did costs jump?" — ended as "the routing gate was prose, not enforced." Cost anomalies are often workflow anomalies.

## Proposed Improvements

- [ ] `workflow-router/SKILL.md` — Add explicit canonical chain at top of classification table: "grill-with-docs → to-prd → to-issues → triage → tdd → workflow-deliver → workflow-finalize" (priority: high)
- [ ] `session-insight/SKILL.md` — Before proposing deletion of behavior/persona skills (output mode, style, tone), require explicit user confirmation (priority: med)
- [ ] `skill-system-audit/SKILL.md` — When auditing skill usage, ask user about their actual invocation patterns before proposing deletions based on metadata alone (priority: med)
- [ ] `docs/agents/habits.md` — Add: "Prose rules in skills are advisory. For hard gates, check workflow-guard.sh Rules 0, A-H." (priority: med)

## Skill Extraction Candidates

- **Proposed skill**: `cost-audit` · **target**: `dotfiles/.config/agents/skills/cost-audit/SKILL.md` · **invocation**: user
  - **Trigger / leading word**: "cost audit", "analyze spend", "why did costs jump"
  - **Inputs**: Claude Code sessions (~/.claude/projects/), pi_sessions.csv, codex_sessions.csv
  - **Steps**:
    1. Aggregate Claude Code sessions by month/model/project
    2. Identify top cost drivers (model, project, date range)
    3. For anomalies, drill into session-level detail (subagent count, message count, compactions)
    4. Trace root cause to specific workflow/decision
    5. Propose mitigation (model routing, parallelism cap, session budget)
  - **Success criteria**: Root cause identified with dollar attribution; actionable mitigation proposed
  - **Constraints / pitfalls**: Claude Code sessions are in ~/.claude/projects/; pi_sessions.csv may not exist; model pricing changes
  - **Verification evidence**: Traced $729 to 102-subagent session; identified 27% of Aug 17-19 spend from one deterministic-skills run
  - **Quality gate**: googleable=No · specific=Yes · real-effort=Yes
  - **Open questions**: Should this integrate with workflow-ledger for run-level cost attribution?

## Session Statistics

- Skills deleted: 71 (from ~105 to 34)
- Hook Rules added: 8 (A-H)
- Backlog items closed: 30 (18 superseded, 12 folded)
- High-priority queue: 8 items
- workflow-router trimmed: ~50% (41KB → ~20KB usable)
- Commits: 6 on branch docs/reflection-test-discovery-gap
