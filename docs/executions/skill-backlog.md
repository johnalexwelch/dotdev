# Skill Backlog
<!-- maintained by skill-backlog; do not hand-edit status fields -->
<!-- First harvest: 2026-07-17. Implementation pass: 2026-07-17 (C1–C5 + process tighten). -->

## Clusters (MECE)

| cluster | theme (failure mode) | occ sessions | open items | rank signal |
|---------|----------------------|--------------|------------|-------------|
| C1 | Canonicality-over-compatibility | 1 | 0 | implemented 2026-07-17 |
| C2 | Cross-session agent habits (CLAUDE.md) | 1–2 | 0 | implemented 2026-07-17 |
| C3 | Worktree self-cwd safety | 1 | 0 | implemented 2026-07-17 |
| C4 | Finalize→cleanup hard coupling | 1 | 0 | implemented 2026-07-17 |
| C5 | Onboarding discoverability (SKILLS-MAP) | 1 | 0 | implemented 2026-07-17 |
| C6 | PR-body artifact backfill | 1 | 1 deferred | wait for recurrence |
| CZ | Closed / already landed / reject | — | — | — |
| CP | skill-backlog process tighten | 1 | 0 | implemented 2026-07-17 (this run's critique) |

## Ledger

| id | first_seen | occ | sources | owning skill/file | summary | priority | status | action | cluster | resolution |
|----|-----------|-----|---------|-------------------|---------|----------|--------|--------|---------|------------|
| SB-001 | 2026-07-09 | 1 | 2026-07-09-router-exclusivity-grill | grill-with-docs | Expert-judgment Qs: recommend alongside open question | med | implemented | — | CZ | already in grill-with-docs |
| SB-002 | 2026-07-09 | 1 | 2026-07-09-router-exclusivity-grill | grill-with-docs | Gating decisions: cover recovery/escape-hatch first | med | implemented | — | CZ | already in grill-with-docs |
| SB-003 | 2026-07-13 | 1 | 2026-07-13-wayfinder-74-shell-friction | (none) | Meta: "none require a skill edit" | low | rejected | reject | CZ | non-proposal |
| SB-004 | 2026-07-13 | 1 | 2026-07-13-wayfinder-74-shell-friction | (none) | Optional shell-usage guidance line | low | rejected | reject | CZ | personal reflex |
| SB-005 | 2026-07-16 | 1 | 2026-07-16-skill-path-and-fix-verification | session-insight | Stale Stow source path | high | implemented | — | CZ | already landed |
| SB-006 | 2026-07-16 | 1 | 2026-07-16-skill-path-and-fix-verification | session-insight | Handoff edge-context re-verify | med | implemented | — | CZ | already landed |
| SB-007 | 2026-07-16 | 1 | 2026-07-16-skill-path-and-fix-verification | setup-worktree | Audit `--show-toplevel` | low | implemented | — | CZ | already uses absolute-git-dir |
| SB-008 | 2026-07-16 | 1 | 2026-07-16-skill-path-and-fix-verification | handoff | Share absolute-git-dir idiom | low | implemented | — | CZ | already folded |
| SB-009 | 2026-07-16 | 1 | 2026-07-16-toon-usage-audit | cleanup-delivery | Verify removals against running system | high | implemented | — | CZ | already landed |
| SB-010 | 2026-07-17 | 1 | 2026-07-17-canonical-paths-workflow-connectivity | workflow-router | Canonicality-over-compatibility preflight | high | implemented | implement | C1 | Canonicality Gate added to workflow-router Preflight |
| SB-011 | 2026-07-17 | 1 | 2026-07-17-canonical-paths-workflow-connectivity | workflow-effectiveness-audit | Duplicate mirrors after symlink removal | high | implemented | fold | C1 | Folded into SB-012 (cleanup-delivery owns the check) |
| SB-012 | 2026-07-17 | 1 | 2026-07-17-canonical-paths-workflow-connectivity | cleanup-delivery | Symlink inventory + duplicate-path drift report | med | implemented | implement | C1 | Canonicalization section + template in cleanup-delivery |
| SB-013 | 2026-07-17 | 1 | 2026-07-17-canonical-paths-workflow-connectivity | session-insight | Post-migration semantic sanity | med | implemented | fold | C2 | Folded into SB-014 (CLAUDE.md habit) |
| SB-014 | 2026-07-17 | 1 | 2026-07-17-openwiki-onboarding-habits | docs/agents/habits.md | Agent Habits: wired-tools, mutating regen tools, semantic sanity | high | implemented | implement | C2 | Moved to durable `docs/agents/habits.md`; AGENTS.md+CLAUDE.md point; openwiki-scheduled restores pointer |
| SB-015 | 2026-07-17 | 1 | 2026-07-17-killswitch-finalize-cleanup-guard | cleanup-delivery | Self-cwd guard before worktree remove | high | implemented | implement | C3 | Step 5 + Safety Checks in cleanup-delivery |
| SB-016 | 2026-07-17 | 1 | 2026-07-17-killswitch-finalize-cleanup-guard | workflow-finalize | Require Load-and-run cleanup-delivery | med | implemented | implement | C4 | Completion section tightened |
| SB-017 | 2026-07-17 | 1 | 2026-07-17-killswitch-finalize-cleanup-guard | describe-pr / workflow-finalize | Backfill `.pr-bodies/` from gh when missing | low | deferred | defer | C6 | Wait for recurrence |
| SB-018 | 2026-07-17 | 1 | 2026-07-17-openwiki-onboarding-habits | dotfiles/.claude/SKILLS-MAP.md | Starting a new project → setup-skills | med | implemented | implement | C5 | Section added to SKILLS-MAP |
| SB-019 | 2026-07-17 | 1 | this-run process critique | skill-backlog | Process: ground-truth, failure-mode cluster, non-proposal filter, fold pass, dual-runtime landing | high | implemented | implement | CP | skill-backlog rewritten; workflow-skill + session-insight sync path fixed |

## Open

- **SB-017** (C6) — deferred until it recurs.
- Claude runtime symlink still broken (`~/.claude/skills` → missing `dotfiles/.claude/skills`) — infra, not a skill-backlog item; reported via workflow-skill dual-runtime check.
