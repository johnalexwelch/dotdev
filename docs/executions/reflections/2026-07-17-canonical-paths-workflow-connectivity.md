# Session Reflection: Canonical Paths And Workflow Connectivity

**Date**: 2026-07-17
**Goal**: tighten workflow coupling and make `dotdev` the canonical, non-symlink source of truth.

## What Went Well

- Rapid convergence from broad ask ("review all workflows") to concrete, severity-ranked findings and direct fixes.
- Correct ownership split emerged clearly: AFK policy in `run-backlog`, per-issue execution in `workflow-build-one`/`workflow-debug`, governance in `workflow-effectiveness-audit`.
- Migration execution was decisive: symlink inventory -> replacement -> re-scan -> zero symlinks.

## What Went Wrong / Friction

- I edited workflow files before confirming path-canonicality assumptions; later we had to pivot on the source-path model.
- Bulk path replacement caused one wording regression in `session-insight` ("Do not edit through canonical path") that needed a corrective patch.
- I gave a "done" signal on de-symlinking while hidden coupling risk remained (`.claude/docs` duplicate), which required a second cleanup step.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | "we shouldnt have simlinks in dotdev" | I optimized for compatibility before explicitly honoring repo-level canonicality policy | `workflow-router/SKILL.md` (preflight policy check) |
| 2 | "what about other simlinks in dotdev" | I fixed the immediate symlink but did not proactively run full-repo symlink inventory first | `workflow-router/SKILL.md` + `cleanup-delivery/SKILL.md` |
| 3 | "please" (full canonical-path migration) | I stopped at local fixes instead of proposing complete path-standardization pass upfront | `session-insight/SKILL.md` (better closure checklist) |

## Lessons

1. **Canonicality first, not compatibility first**: when user intent says "source of truth," default to eliminating indirection (symlinks), then preserve behavior.
2. **Migration completion needs coupling check**: a symlink removal is incomplete until duplicate-path drift risk is checked and resolved.
3. **Bulk rewrite needs post-pass semantic lint**: string replacement should always be followed by a targeted "did this sentence still mean the same thing?" pass.

## Proposed Improvements

- [ ] `dotfiles/.config/agents/skills/workflow-router/SKILL.md` - add explicit preflight question for path/layout changes: "Is canonicality required over compatibility?" before filesystem mutations (priority: high).
- [ ] `dotfiles/.config/agents/skills/workflow-effectiveness-audit/SKILL.md` - add a filesystem integrity check for "duplicate canonical mirrors after symlink removal" as a known gap pattern (priority: high).
- [ ] `dotfiles/.config/agents/skills/session-insight/SKILL.md` - update attached/runtime copy to remove stale symlink claim and add a "post-migration semantic sanity check" rule for bulk path rewrites (priority: medium).
- [ ] `dotfiles/.config/agents/skills/cleanup-delivery/SKILL.md` - add a "repo symlink inventory + duplicate-path drift report" template for canonicalization tasks (priority: medium).
