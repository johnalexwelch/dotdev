# Security Depth

## Summary

Strong data compartmentalization. No committed secrets. No dangerous untracked artifacts. Three medium concerns: (1) data retention is unbounded — phase-run outcomes and plans accumulate forever with no cleanup policy; (2) all skills have full Claude Code tool access, no capability restrictions; (3) `/setup-worktree` copies `.claude/settings.local.json` into isolated worktrees, which could exfiltrate sensitive user settings if not audited first. Skills that mutate state (`/execute-phase` commits and branches, `/setup-worktree` creates worktrees) are additive, not destructive — no `git reset --hard` or `git push --force` paths exist. YAML parser strictness is a minor quality-not-security issue.

## Findings

### PASS: No committed secrets across 2-commit history
- `git log -p --all`: no API keys, tokens, or credentials
- Baseline commit `b9a579e` captured `.omc/state/` runtime metadata only (session UUIDs, cost stats, context-window usage) — no credentials
- Commit `019414d` untracks this state; `.gitignore` prevents re-tracking

### LOW: PII in execution artifacts
- Phase-run outcome files contain branch names, commit hashes, relative paths, task text — no credentials
- Git author field (`alex.welch@classdojo.com`) is standard, not a leak
- Plan example paths mention `/Users/alexwelch/...` — username-level context, not sensitive

### MEDIUM: Unbounded data retention
- `docs/executions/.phase-runs/` files accumulate indefinitely; no deletion policy
- `docs/plans/` (empty at present but planned path) has no expiration
- `docs/executions/<date>-post-mortem.md` (future writes) also no TTL
- `.gitignore` correctly ignores `.omc/state/` (ephemeral) but not phase-run outcomes (intentionally tracked as audit trail)
- Disk impact negligible now (6 files, <10KB total); scales linearly with phase count

### MEDIUM: All skills have unrestricted tool access
- No capability restrictions in SKILL.md frontmatter
- Every skill can Read/Write any path, Bash any command, dispatch unlimited subagents
- Self-imposed discipline is the only guardrail (e.g., `/execute-phase` Step 5 scope verification is a documented convention, not a technical enforcement)
- Precedent: Claude Code's hook system (PreToolUse/PostToolUse) could enforce scope but is not used here

### MEDIUM: `/setup-worktree` copies `.claude/settings.local.json`
- Worktree creation includes copying the local Claude Code settings file into the isolated worktree
- If this file contains sensitive settings (API preferences, auth tokens, debug flags), they propagate unencrypted to any worktree path (default `~/wt/<repo>/phase-<N>/`)
- User action: audit `.claude/settings.local.json` contents before running `/setup-worktree` if sensitive data is present

### LOW: Destructive operation capabilities
- `/execute-phase`: `git checkout -b`, `git add` (scoped), `git commit` — all additive; no resets, no force-pushes
- `/setup-worktree`: `git worktree add -b` — additive
- No skill has `rm -rf`, `git push --force`, or `git reset --hard` paths
- User must manually `git worktree remove` worktrees when done; no auto-cleanup

### LOW: External CLI dependencies unpinned
- `gh` CLI, `git`, `python3` + `pyyaml` — no version constraints documented
- No installation docs; users are expected to have these pre-installed

### LOW: YAML parser strictness (pre-existing, partially fixed)
- `design-plan/SKILL.md` and `post-mortem/SKILL.md` have frontmatter that fails strict PyYAML due to quoted-then-unquoted `description:` values in `inputs:` blocks (NEW-03 from Phase 0 of the skills-updates plan)
- Not a security vulnerability — just a robustness issue; Claude Code's tolerant parser accepts these
- Fixed for `design-plan/inputs[mode]` and `post-mortem/inputs[scope]` in Phase 0 of the plan

## Evidence

- `git log -p --all | grep -iE '(api[_-]key|token|secret|password|BEARER|BEGIN PRIVATE)'`: 0 credential-like matches
- `find . -name '*.env*' -type f`: 0 matches in repo
- `.gitignore` covers `.omc/state/`, `.omc/logs/`, `docs/audits/.fact-packs-*/`, `docs/executions/.pr-bodies/`
- Scanned `/setup-worktree` Step 2: copies `.env*`, `.envrc`, `.nvmrc`, `.python-version`, `.tool-versions`, `.ruby-version`, `.node-version`, `.claude/settings.local.json`

## Open questions

1. What is in `.claude/settings.local.json` on this machine? Should `/setup-worktree` exclude that file, or at minimum warn the user on copy?
2. Retention policy — keep plans + phase-runs forever (audit trail), or prune after N months?
3. Should pre-commit hooks be added to enforce commit-message schema + scan for accidentally-staged secrets before push?
