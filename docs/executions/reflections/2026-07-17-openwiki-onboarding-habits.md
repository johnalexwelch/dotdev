# Session Reflection: Wiring OpenWiki + docs standardization

**Date**: 2026-07-17
**Goal**: Wire OpenWiki for dotdev (then iris), harden its automation, audit repo docs for LLM-discoverability, extend onboarding to auto-register new repos.

## What Went Well

- Verified user-stated paths against the filesystem instead of trusting them: `~/projects/iris` doesn't exist (real path `~/projects/agents/iris`), `~/projects/chorus` isn't a git repo at all — caught both before acting, corrected the user's model instead of silently writing to a wrong/no-op path.
- After causing a real regression (below), didn't just patch the symptom — rebuilt the scheduled script's safety as structural (`git checkout --` restore + narrow add-paths) rather than relying on memory, and documented the remaining manual-run gap explicitly in USAGE.md.
- Before adding a brand-new "register with setup script" mechanism, searched for an existing owner first and found `setup-skills` already fit the job (onboarding-skill reuse over new scaffolding).

## What Went Wrong / Friction

- Ran `openwiki code --update --print` directly against the **live checkout** (not a scratch worktree) just to "quickly verify." It clobbered hand-hardened security settings in `.github/workflows/openwiki-update.yml` — re-enabled the disabled cron, downgraded pinned-SHA actions back to floating tags, dropped `persist-credentials: false` and the explicit token line. Had to diff and revert by hand. This is a **ground-truth-vs-proxy miss**: assumed (proxy: "a regen tool only touches its own generated content") instead of verifying that assumption before running a mutating command on the live tree — the exact trap the throwaway-worktree pattern (built minutes later, for the *scheduled* path only) exists to prevent. Manual/interactive runs still have no structural guard, only documented discipline.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | User pushed back: "should openwiki be used for the documentation audit?" after starting to manually grep files instead of checking whether the tool just wired already covered it | Didn't reflexively check a newly-available capability before defaulting to manual work | `CLAUDE.md` Agent Habits |

## Lessons

1. **New capability, check before manual work**: When a tool/automation is wired in the *same session*, before doing the adjacent task by hand, check whether the tool already covers it (even partially) and scope what's left. Generalizes past this one openwiki incident.
2. **Live-checkout regen tools need the same discipline as `git reset --hard`**: any mutating/regenerating CLI (doc generators, codegen, scaffolders) run directly against a live checkout should be treated as untrusted until diffed — either dry-run in an isolated copy first, or diff-review immediately after, before assuming success. `git-guardrails` only covers git commands specifically; this is a broader "third-party mutating tool" habit with no current owner.
3. **SKILLS-MAP.md has a real onboarding-category gap**: `setup-skills` (repo onboarding: issue tracker, triage labels, domain docs, now OpenWiki registration) isn't listed anywhere in the map — 0 matches for its name or any of its section topics. Finding it this session took a multi-directory grep instead of a map lookup.

## Proposed Improvements

- [ ] `CLAUDE.md` (repo root, `~/dotdev/CLAUDE.md`) — add two bullets to **Agent Habits**:
  - Check newly-wired capabilities/tools before falling back to manual work for an adjacent task.
  - Treat live-checkout runs of mutating/regenerating third-party tools (doc generators, codegen, scaffolders) like destructive git ops: dry-run in an isolated copy, or diff immediately after — never assume success.
  (priority: high — cheap, cross-session, would've prevented the actual incident)
- [ ] `dotfiles/.claude/SKILLS-MAP.md` (canonical source: `dotfiles/.config/agents/skills/_docs/` sibling or wherever this map is authored — verify path before editing) — add a "Starting a new project" row/section pointing to `setup-skills` (issue tracker + triage labels + domain docs + OpenWiki registration). (priority: med — pure discoverability, no behavior change)

Both are docs-only, no code/skill logic changes.
