# Handoff — Wayfind the dotdev setup overhaul

Exit: manual (seed a /wayfinder charting session)
Target: claude (or pi)
Generated: 2026-07-09

## Start here (resuming agent)

> You are resuming multi-session work in `johnalexwelch/dotdev`. No `state.yaml`
> exists — boot off "Files to read first" (bottom of this doc) to rebuild context.
>
> This effort is deliberately handed to **`/wayfinder`**: the pile of changes is
> too big and too interdependent to hold in one session. `wayfinder` is installed
> and operational in this repo (PR #67).
>
> **Do Next step 1: name the destination with the user, then run `/wayfinder` in
> chart mode.** Do NOT start fixing findings directly — wayfinder charts them into
> a map first (that is the whole point; charging at the destination is the
> anti-pattern the skill exists to prevent).
>
> **STOP before charting to surface one human decision:** FIND-09 — a real SSH
> private key is in git history (`449613f`, deleted in `3d0a778` without a rewrite).
> It should be rotated regardless, and whether to rewrite history (destructive,
> breaks clones) is the user's call. Raise this first; it may be its own Tier-0
> ticket or a pre-map action.

## Where we are

A full six-specialist audit of the dotdev setup is complete and written up. Skill-pack drift vs `mattpocock/skills` was reconciled and the `wayfinder` skill was installed and wired into this repo's delivery funnel — all on **PR #67** (draft). What remains is a large, interdependent set of setup fixes and improvements that no single session should implement blind. The next move is to *chart* them with `/wayfinder`, not to start fixing.

## What was done this session

- **PR #67** (draft, branch `claude/wayfinder-skill-setup-aptvd9`): reconciled skill drift (codebase-design, improve-codebase-architecture, tdd, triage, setup-skills, write-a-skill, handoff, prototype), added `git-guardrails` + `spec-review`, and added the **`wayfinder`** skill adapted to our funnel. Lint suite clean (0/0).
- **`wayfinder` operational here**: `dotfiles/.claude/skills/wayfinder/SKILL.md` (top-of-funnel, explicit-invoke, map never `ready-for-agent`, decisions mirror to `decision-log`, cleared route hands off per-effort).
- **`docs/agents/issue-tracker.md`** created (GitHub tracker + triage labels + **Wayfinding operations** section — the concrete `gh` ops wayfinder consults).
- **`docs/audits/2026-07-09-setup-audit.md`** — the full findings, FIND-09…FIND-29. **This is the fog for the charting session.**

## What is NOT done

Everything in `docs/audits/2026-07-09-setup-audit.md` (FIND-09…FIND-29) — do not duplicate here; read it. Headlines: leaked SSH key (FIND-09), broken macOS install path (FIND-11–13), machine-rename footgun (FIND-15), fresh-machine clone failures (FIND-16–17), ~10 doc-drift facts (FIND-20), router-bypass on 13 skills (FIND-21), uncaptured/dangling tools — cursor, hunk, trino, opencode (FIND-22–24), uncaptured MCP fleet (FIND-25), pi context-stack overlap (FIND-26), Codex/opencode skill wiring (FIND-27), nvim recovery (FIND-28), repo-wide Lint debt (FIND-29).

## Blockers requiring human input

- **FIND-09 (Tier-0):** rotate the leaked SSH key now; decide yes/no on a git-history rewrite (destructive). Needed before/at charting.
- **Destination not yet named.** `wayfinder` step 1 is naming what "done" looks like for this overhaul (e.g. "a robust, reproducible, multi-harness dotdev"). The user must set this — it fixes scope.
- **FIND-21:** which of the 13 internal skills should become `disable-model-invocation` (router-exclusive) is a design call for the user.
- **FIND-25:** wiring the MCP fleet needs the user's actual endpoints/credentials.

## Key decisions made (context for the map's Notes)

- `wayfinder` = top-of-funnel, explicit-invoke; decisions mirror to `decision-log`; cleared route routes per-effort (to-prd→to-issues→triage for features; design-plan→execute-phase for refactors).
- Skill layout stays **flat** (only cross-harness-safe option; SKILL.md is a vendor-neutral standard).
- nvim: **navigation-first rebuild**, not wholesale restore (old config in `johnalexwelch/dotfiles`, chezmoi `master`, `dot_config/nvim/lua/awelch/*`); salvage `keymaps.lua`+`options.lua`, drop `lazygit.nvim` (moving to hunk), wire hunk as git difftool.
- **Deliberate exclusions** (don't re-flag): dbt absent from Brewfile (work-installed, collision); setup-skills Section C skipped for dotdev (no DDD domain).

## Next steps

1. Raise FIND-09 with the user (rotate + history-rewrite decision).
2. **Name the destination** for this overhaul with the user.
3. Run **`/wayfinder`** in chart mode, using `docs/audits/2026-07-09-setup-audit.md` as the fog — sharp findings become tickets, coarse ones go to "Not yet specified".
4. Then work the map one ticket per session; each cleared route hands into the funnel per its Notes.

## Ready-to-use prompt (charting session)

> `/wayfinder` — I want to chart the dotdev setup overhaul. Destination: <name it with me first>. The fog is already written up in `docs/audits/2026-07-09-setup-audit.md` (FIND-09…FIND-29) — treat sharp findings as tickets and coarse ones as "Not yet specified". Consult `docs/agents/issue-tracker.md` → "Wayfinding operations" for how the map/tickets/labels work here. FIND-09 (SSH key) is Tier-0 — handle its human decision before or as the first ticket. Do not implement anything this session; chart the map and stop.

## Suggested skills

- `wayfinder` — chart the map (this is the entry point).
- `decision-log` — record decisions as tickets resolve.
- `to-prd` / `design-plan` — where cleared routes hand off, per-effort.
- `git-guardrails` — relevant to the FIND-09/security stretch of the map.

## Files to read first

- `docs/audits/2026-07-09-setup-audit.md` — the fog (FIND-09…FIND-29).
- `docs/agents/issue-tracker.md` — Wayfinding operations (how the map/tickets work here).
- `dotfiles/.claude/skills/wayfinder/SKILL.md` — the skill you're about to run.
- `AI_ENVIRONMENT.md`, `SETUP_WRITEUP.md` — current setup writeups (note: drift-flagged in FIND-20).
- `docs/audits/2026-07-02-repo-audit.md` — prior audit (FIND-01…08).
- PR #67 — <https://github.com/johnalexwelch/dotdev/pull/67> (draft; contains the skill work above).
