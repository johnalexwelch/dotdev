# Handoff — Skill Backlog High-Priority Queue Implementation

Exit: completion with follow-ups
exit_reason: completion-with-follow-ups
Target: claude
Generated: 2026-08-25T16:30:00Z

## Start here (resuming agent)

> You are resuming multi-session work in `dotdev`. Recover state before acting:
>
> 0. **Work happens in `/Users/alexwelch/dotdev`.** Verify cwd.
> 1. Read this handoff's "High-priority queue" section — it defines the 8 items to implement.
> 2. Read `/Users/alexwelch/dotdev/docs/executions/skill-backlog.md` section "2026-08-25 Triage Summary" for full context.
>
> Then do Next step 1: Implement SB-099 (habits.md proxy vs ground-truth line). Work through the queue in order — each item is small and focused.

## Where we are

Session completed a major skills cleanup (71 skills deleted, workflow-router simplified 50%, Hook Rules A-H added). Triaged the skill-backlog: marked 18 items superseded (target skills deleted), 12 items folded (covered by session work), identified 8 high-priority items for implementation, deferred ~20 low-value items.

The high-priority queue is ready for implementation — all items are small, focused edits to existing files.

## What was done this session

- Analyzed July-August cost data: identified $729 deterministic-skills session with 102 subagents as root cause
- Added Hook Rules A-H to workflow-guard.sh (parallelism cap, PR body gate, diff warning, model routing, duplicate issue warning, secrets warning, cross-repo warning)
- Deleted 71 skills across multiple cleanup passes
- Simplified workflow-router by 50% (removed catalog-tier section, trimmed classification table)
- Updated workflow-router with canonical chain: grill-with-docs → to-prd → to-issues → triage → tdd
- Moved pattern-doc skills to _docs/ (council-scaffolding, review-scaffolding, graph-first, write-a-skill, etc.)
- Made i-have-adhd and caveman always-on in global CLAUDE.md
- Triaged skill-backlog: closed 30 items (18 superseded + 12 folded)
- Committed all changes to branch `docs/reflection-test-discovery-gap`

## What is NOT done

8 high-priority backlog items ready for implementation (see queue below).

## High-priority queue

| Priority | ID | Target | Summary | Effort |
|----------|-----|--------|---------|--------|
| 1 | SB-099 | `/Users/alexwelch/dotdev/docs/agents/habits.md` | Add one-liner: proxy (spec/prior/config) vs ground truth (repo/running state/API) — verify before fixes | 5 min |
| 2 | SB-113 | `/Users/alexwelch/dotdev/docs/agents/habits.md` | Add: before accepting tool/format as constraint, verify it's a real requirement | 5 min |
| 3 | SB-100 | `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/i-have-adhd/SKILL.md` | Add rule: when claiming "fixed", show verification command + output | 5 min |
| 4 | SB-111+112 | `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/ponytail/SKILL.md` OR habits.md | YAGNI applies to features, NOT correctness guards; blast-radius opt-in for enforcement | 10 min |
| 5 | SB-054 | `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/improve-codebase-architecture/SKILL.md` | Distinguish "missing-tests → write red→green" from "invariant-is-judgment-call → human gate" | 10 min |
| 6 | SB-105 | `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/handoff/SKILL.md` | Add env-assumption notes: when origin is self-hosted, state `gh` won't work + name right tool | 10 min |
| 7 | SB-108 | `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/cleanup-delivery/SKILL.md` | Add reconcile ACTION for stale-behind primary (today only reports) | 15 min |
| 8 | SB-052 | `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/_docs/herdr/SKILL.md` | Document herdr commands: worktree list/create/open/remove, pane split/run | 15 min |

**Total estimated effort: ~75 minutes**

## Implementation notes

### SB-099 + SB-113 (habits.md)

Add to the "Ground truth over speculation" section if it exists, or create one:

```markdown
- **Proxy vs ground truth**: Specs, prior sessions, config examples, and verbal claims are proxies. Repo state, running services, and live APIs are ground truth. Verify ground truth in the first iteration, before fixes or durable fan-out.
- **Inherited constraints**: Before accepting a tool/format/paradigm as a constraint, verify it's a real requirement — not just "what the user happened to be using." (Evidence: Obsidian assumption cost weeks in Warren.)
```

### SB-100 (i-have-adhd)

Add to rules section:

```markdown
- **Show verification evidence.** When claiming "fixed", show the verification command and its output. Never say "fixed" without evidence.
```

### SB-111+112 (ponytail/habits)

If ponytail skill exists, add there; otherwise add to habits.md:

```markdown
- **YAGNI boundary**: YAGNI applies to features and optimizations, NOT correctness guards. Dedup, validation, and trust-boundary error handling earn their keep from line 1.
- **Blast radius for enforcement**: When output is enforcement (CI gate/lint blocking others), default to opt-in single-target scope. Confirm blast radius before repo-wide — "please do" approves the idea, not the blast radius.
```

### SB-054 (improve-codebase-architecture)

Add a decision checkpoint before marking a slice human-gated:

```markdown
Before marking a slice as human-gated, distinguish:
- **Missing tests** → write red→green tests, then proceed (not a human gate)
- **Invariant is a judgment call** → genuine human gate (document what decision is needed)
```

### SB-105 (handoff)

Add to Rules section:

```markdown
- **Env-assumption notes**: When origin is self-hosted (Forgejo/Gitea), state that `gh` won't work and name the right tool (tea, curl, API). Always include IP alongside LAN hostnames — resuming machine may lack /etc/hosts entry.
```

### SB-108 (cleanup-delivery)

Current behavior reports stale-behind primary but takes no action. Add a reconcile action:

```markdown
When primary checkout is stale AND behind authoritative remote:
1. Report the state (already done)
2. Offer reconcile ACTION: safety-patch uncommitted changes, then `git fetch && git reset --hard origin/main`
3. Gate on user approval before executing
```

### SB-052 (herdr docs)

Document the herdr CLI commands that exist:

- `herdr worktree list` — list open worktrees
- `herdr worktree create` — create worktree + pane
- `herdr worktree open` — open existing worktree in pane
- `herdr worktree remove` — remove worktree (targets open workspace IDs only; use plain `git worktree remove` for orphaned)
- `herdr pane split` — split current pane
- `herdr pane run` — run command in pane
- Note: auto-naming extension exists (`herdr-task-naming.ts`)

## Next steps

1. Implement SB-099 + SB-113 (habits.md — two lines, one file)
2. Implement SB-100 (i-have-adhd verification rule)
3. Implement SB-111+112 (ponytail/habits YAGNI + blast-radius)
4. Implement SB-054 (improve-codebase-architecture test-gap vs human-gate)
5. Implement SB-105 (handoff env-assumption notes)
6. Implement SB-108 (cleanup-delivery reconcile action)
7. Implement SB-052 (herdr command docs)
8. Update skill-backlog.md: mark all 8 items as `implemented`
9. Commit and push to `docs/reflection-test-discovery-gap`

## Files to read first

- `/Users/alexwelch/dotdev/docs/executions/skill-backlog.md` — full backlog with triage summary
- `/Users/alexwelch/dotdev/docs/agents/habits.md` — target for SB-099, SB-113, possibly SB-111+112
- `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/i-have-adhd/SKILL.md` — target for SB-100
- `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/improve-codebase-architecture/SKILL.md` — target for SB-054
- `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/handoff/SKILL.md` — target for SB-105
- `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/cleanup-delivery/SKILL.md` — target for SB-108
- `/Users/alexwelch/dotdev/dotfiles/.config/agents/skills/_docs/herdr/SKILL.md` — target for SB-052
