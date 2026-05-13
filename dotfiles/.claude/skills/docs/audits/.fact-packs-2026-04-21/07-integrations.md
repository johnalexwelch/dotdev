# External Integrations Audit

**Date:** 2026-04-21  
**Directory:** /Users/alexwelch/.claude/skills/  
**Scope:** Very thorough  
**Focus:** External service integrations (GitHub, Slack, Obsidian, Linear, git remotes, OAuth, MCP, web APIs)

---

## Summary

The skills directory contains 11 documented skills. **Five core skills directly integrate with external services**:

1. **slack-update** — Slack API (mrkdwn messaging)
2. **write-to-obsidian** — Local filesystem (Obsidian vault)
3. **describe-pr** — GitHub CLI (gh) for PR body application
4. **setup-worktree** — Git remote operations (branch creation, worktree add)
5. **ci-deploy-fix** — GitHub Actions (workflow logs, PR comments)

The remaining six skills are **internal orchestration tools** (no external integrations):
- repo-audit, design-plan, execute-phase, post-mortem, td-task-management, omc-reference

**Key finding:** All integrations are **aspirational** (documented in SKILL.md) with **no implementation code** present. No Python, JavaScript, or shell scripts implement the workflows — only specification markdown exists.

---

## Findings

### 1. slack-update — Slack API Integration

**Service:** Slack (https://slack.com/api)

**Auth method:** Bearer token via `SLACK_BOT_TOKEN`  
- Environment variable lookup chain: `$SLACK_BOT_TOKEN` → `.env` file → fallback to `~/projects/iris/.env`
- No OAuth flow documented; uses pre-provisioned bot token

**Wired vs. aspirational:** **Aspirational**  
- SKILL.md documents the workflow but contains no executable code
- Pseudo-code example: Python httpx AsyncClient call to `https://slack.com/api/chat.postMessage`
- Workflow orchestrated via GitHub channel mapping file: `~/.claude/slack-update-channels.json`

**Failure mode:** **Hard fail with user notification**
- Token not found → ask user interactively
- API errors (e.g., invalid channel) → print error response, no retry
- Network timeout (15s per SKILL.md) → timeout error surfaced to chat

**Rate-limit handling:** **Not addressed**
- No mention of Slack API rate limits (50 req/min for chat.postMessage)
- No exponential backoff or queue
- No retry logic specified

**Verification:** Single-step — user confirmation before sending ("Send to #channel?")

**Drift from specification to reality:**
- SKILL.md prescribes `/chat.postMessage` API call with unfurl_links/unfurl_media flags
- `conversations.info` call to resolve channel name (real-time lookup for display, not cached)
- PR grouping heuristic (conventional commits + PR body scanning) is complex; no risk assessment for edge cases (malformed commit messages)

**Load-bearing design choices:**
- Mrkdwn formatting (asterisks for bold, no heading syntax)
- Em dashes (—) vs. hyphens for separators
- One-day lookback for merged PRs (UTC midnight-to-midnight)

---

### 2. write-to-obsidian — Local Filesystem Integration

**Service:** Obsidian vault (local filesystem at ~/Documents/Home/)

**Auth method:** None (filesystem ACL)

**Wired vs. aspirational:** **Aspirational**
- SKILL.md specifies `mkdir -p` + heredoc bash commands
- No implementation code; intended as a skill subagent's workflow description, not automated

**Failure mode:** **Graceful degrade + user prompt**
- File exists → ask user: overwrite, append, or abort (check with `[ -f ... ]` test)
- Missing parent directory → `mkdir -p` creates it (no error)
- Filesystem permission error → silent skip per file, continue with rest

**Rate-limit handling:** **N/A** (local filesystem)

**Directory conventions documented:**
- Briefings: `Chief of Staff/Briefings/[YYYY-MM]/[MM-DD]/`
- Meeting notes: `Areas/dojo/Meeting Notes/`
- Meal plans: `Areas/Family/Meal Planning/[YYYY]/[MM-month]/`
- Inbox: `* Inbox/`

**YAML frontmatter requirements:**
- Mandatory: `created: YYYY-MM-DD`, `tags: [tag1, tag2]`
- Optional: `week_start` (for meal plans)

**Load-bearing design choices:**
- Heredoc quoting: `<< 'OBSIDIAN_EOF'` (prevents shell expansion)
- `>>` for append vs. `>` for overwrite
- File naming: lowercase with hyphens (`morning-briefing.md`)
- Date-stamped directories for recurring outputs

**Specification gaps:**
- No conflict resolution for simultaneous writes
- No Obsidian-native API call (treats Obsidian as dumb vault)
- Relies on filesystem mtime for "recent" sorting in Obsidian, not Obsidian metadata

---

### 3. describe-pr — GitHub CLI Integration

**Service:** GitHub API (via `gh` CLI and `git` commands)

**Auth method:** GitHub CLI (OAuth or SSH; user pre-configured)  
- No explicit token handling in SKILL.md
- Assumes `gh` and `git` commands available and authenticated

**Wired vs. aspirational:** **Aspirational**
- SKILL.md documents the workflow; no implementation code
- Pseudo-code: `gh pr view`, `gh pr edit --body-file`, `git log`, `git diff`, `git hash-object`
- Subagent dispatch: "general-purpose Agent" (no hardcoded subagent type)

**Failure mode:** **Graceful degrade to text-only**
- `gh` CLI not installed and `pr_number == 0` → proceed in text-only mode; no PR actions attempted
- No PR exists for branch → skip `apply` step, return body text only
- `git remote get-url origin` not GitHub → omit diff permalinks, note in body
- `git hash-object` unavailable → omit per-file diff permalinks, use compare-view URL
- Deviation subagent returns empty → retry once with tighter prompt; if still empty, surface in body

**Rate-limit handling:** **Not addressed**
- GitHub API has 5,000 req/hr for authenticated users
- No mention of rate-limit headers or backoff
- `gh pr view` is a single call (low cost); but for large repos, `git log` is local

**Verification:** Two-phase
1. Pre-flight: confirm git repo, resolve plan/branch/PR
2. Subagent review: deviation-analysis Agent compares plan vs. commits, surfaces drift

**Integration points:**
- Reads: `docs/plans/*.md`, `docs/executions/.phase-runs/*`, git log, `gh pr view`
- Writes: `docs/executions/.pr-bodies/<date>-pr-<N>.md`, (optionally) PR body on GitHub

**Load-bearing design choices:**
- Ticket ref regex: `FIND-NN`, `NEW-NN`, `GAP-NN`, `phase-N`, `[A-Z]+-\d+` (JIRA-style)
- Ticket URL construction: opt-in via `.tickets.env` base URL (no Linear-specific hardcoding)
- Per-file diff anchors: `git hash-object --stdin` for 8-char prefix (not GitHub's native syntax)

**Specification gaps:**
- Deviation subagent brief is prescriptive but not autogenerated; relies on manual prompting
- No caching of deviation analysis (subagent is stateless, re-runs on each invocation)
- `§3 Goals` and `§5 Execution plan` parsing is manual (no structured extraction)

---

### 4. setup-worktree — Git Remote Operations

**Service:** Git (local and remote)

**Auth method:** User pre-authenticated (SSH or HTTPS git creds)  
- No explicit credential handling
- Assumes git is configured and has access to remote

**Wired vs. aspirational:** **Aspirational**
- SKILL.md documents `git worktree add`, `git show-ref`, file copy logic
- No implementation code; intended for human execution or subagent delegation

**Failure mode:** **Hard fail (no fallback)**
- Path already exists → abort (would require `--force`, which is silently declined)
- Branch conflict (in use by another worktree) → abort, report error, no auto-cleanup
- Branch doesn't exist and is new name → create off current HEAD
- Env file copy failure (permissions, missing parent dir) → warn per-file, continue with rest
- `setup_command` exits non-zero → surface error but keep worktree (user debugs in place)

**Rate-limit handling:** **N/A** (local git)

**Config files auto-copied:**
- `.env`, `.env.local`, `.env.development`, `.env.production`, `.env.test`
- `.envrc`, `.nvmrc`, `.python-version`, `.tool-versions`, `.ruby-version`, `.node-version`
- `.claude/settings.local.json` (if `.claude/` exists in destination)

**Copy strategy:**
- Flat copy (not symlinks) to avoid dangling links on worktree removal
- Best-effort per file; skip silently if parent dir missing in destination
- No fingerprinting or mtime preservation

**Load-bearing design choices:**
- Branch naming: `refactor/phase-<N>-<phase-slug>` derived from plan
- Worktree path: `~/wt/<repo>/phase-<N>/` convention
- Phase slug derivation: lowercase, non-alphanum → `-`, cap 40 chars (matches `/execute-phase`)

**Specification gaps:**
- No validation that copied env files match source (one-way copy, no sync)
- No post-copy `.gitignore` check (user responsible for `.gitignore` covering new paths)
- Setup command is optional; no default (e.g., `npm install` not auto-run)

---

### 5. ci-deploy-fix — GitHub Actions Integration

**Service:** GitHub Actions (workflow logs and PR API)

**Auth method:** GitHub CLI (pre-configured)  
- Assumes `gh` available and authenticated
- Reads workflow logs via `gh run view`

**Wired vs. aspirational:** **Aspirational**
- SKILL.md documents workflow; no implementation code
- Pseudo-code: `gh run list`, `gh run view <RUN_ID> --log-failed`, `gh pr comment`, `gh api repos/<owner>/<repo>/commits/<SHA>/comments`

**Failure mode:** **Diagnosis-only with escalation**
- Infra/permissions issues (IAM, ECR login, runner availability) → diagnose only, escalate
- CI fix available → create fix branch, apply fix, verify locally, open PR
- Migration failures → user must fix and verify (test against local DB)
- Skaffold/k8s deploy → verify YAML with `--dry-run`, note that actual deploy can't be verified locally

**Rate-limit handling:** **Not addressed**
- GitHub Actions logs are rate-limited (API calls to `gh run view`)
- No mention of backoff or retry

**Verification strategy:**
- Lint/type errors → run lint/type tool locally before commit
- Test failures → run test suite locally
- Build failures → test build stage locally
- Migrations → test against local DB if possible
- Deploy failures → often not verifiable locally (k8s, Skaffold)

**Load-bearing design choices:**
- Failure classification: lint, type, test, build, migration, k8s, skaffold, infra, resource
- Fix branch pattern: `fix/ci-<description>` or `fix/deploy-<description>`
- Worktree isolation for CI fixes (convention from project)
- PR body structure: Diagnosis, Root Cause, Fix, Verification (checkbox format)

**Integration points:**
- Reads: `gh run list`, workflow files (`.github/workflows/`), migration files
- Writes: fix branch, PR (optionally), commit comment on original PR or merge commit

**Specification gaps:**
- Root-cause diagnosis is manual (no automated log analysis)
- Fix branch creation uses worktrees if available; fallback to git checkout (no explicit condition)
- Common patterns (ruff, Docker build errors, Trivy CVE) are documented as examples, not automated

---

### 6–11. Internal Skills (No External Integrations)

**repo-audit, design-plan, execute-phase, post-mortem, td-task-management, omc-reference**

These six skills are **internal orchestration** and do not integrate with external services:

- **repo-audit** — Spawns 13 parallel subagents to audit local repo; produces FIND-NN findings. No external API calls.
- **design-plan** — Reads audit, asks user questions, writes plan markdown. No external services.
- **execute-phase** — Dispatches subagents per phase, verifies with local tools (git, tests). No external services.
- **post-mortem** — Reads git history, plan, audit; produces retro markdown. No external services.
- **td-task-management** — Local SQLite issue tracking. No external services.
- **omc-reference** — Skill reference documentation. No external services.

---

## Evidence

### File Structure
```
/Users/alexwelch/.claude/skills/
├── slack-update/
│   └── SKILL.md (11 lines, pseudo-code for Slack API call)
├── write-to-obsidian/
│   └── SKILL.md (160 lines, bash heredoc examples)
├── describe-pr/
│   └── SKILL.md (290 lines, git/gh CLI pseudo-code)
├── setup-worktree/
│   └── SKILL.md (235 lines, git worktree documentation)
├── ci-deploy-fix/
│   └── SKILL.md (220 lines, failure classification + fix patterns)
├── repo-audit/
│   └── SKILL.md (314 lines, subagent dispatch patterns, no external services)
├── design-plan/
│   └── SKILL.md (400 lines, plan generation, no external services)
├── execute-phase/
│   └── SKILL.md (527 lines, phase execution, no external services)
├── post-mortem/
│   └── SKILL.md (290 lines, retro generation, no external services)
├── td-task-management/
│   └── SKILL.md (216 lines, local task tracking, no external services)
└── omc-reference/
    └── SKILL.md (skill reference, no external services)
```

**No implementation files found.** Each skill directory contains only SKILL.md (specification markdown). No `.py`, `.js`, `.sh`, or other executable code present.

### Integration Inventory

| Skill | Service | Auth | Wired | Fail Mode | Rate Limits | Notes |
|-------|---------|------|-------|-----------|-------------|-------|
| slack-update | Slack API | Bearer token | Aspirational | Hard fail | Not handled | httpx AsyncClient example; mrkdwn formatting |
| write-to-obsidian | Filesystem | None | Aspirational | Graceful degrade | N/A | Bash heredoc workflow; no Obsidian SDK |
| describe-pr | GitHub (gh CLI) | GitHub CLI auth | Aspirational | Text-only fallback | Not handled | Subagent for deviation analysis |
| setup-worktree | Git | User auth | Aspirational | Hard fail (no force) | N/A | Local git worktree; env file copy |
| ci-deploy-fix | GitHub Actions (gh CLI) | GitHub CLI auth | Aspirational | Diagnosis only | Not handled | Escalate infra issues; no auto-fix for deploy |
| repo-audit | None | N/A | Aspirational | N/A | N/A | Internal; subagent dispatch |
| design-plan | None | N/A | Aspirational | N/A | N/A | Internal; plan generation |
| execute-phase | None | N/A | Aspirational | N/A | N/A | Internal; phase execution |
| post-mortem | None | N/A | Aspirational | N/A | N/A | Internal; retro generation |
| td-task-management | None | N/A | Aspirational | N/A | N/A | Internal; local SQLite |
| omc-reference | None | N/A | Aspirational | N/A | N/A | Reference documentation |

### External Service Details

**Slack API (slack-update)**
- Endpoint: `https://slack.com/api/chat.postMessage`
- Parameters: `channel`, `text`, `unfurl_links`, `unfurl_media`
- Token source: `SLACK_BOT_TOKEN` env var or `.env` file
- Fallback: ask user interactively
- Timeout: 15 seconds (httpx AsyncClient)

**GitHub (describe-pr, ci-deploy-fix)**
- CLI: `gh` (user pre-authenticated)
- Commands: `gh pr view`, `gh pr edit`, `gh run list`, `gh run view`, `gh pr comment`, `gh api`
- Git commands: `git log`, `git diff`, `git remote get-url`, `git hash-object`, `git status`
- No hardcoded OAuth or token handling (delegates to gh CLI)

**Obsidian (write-to-obsidian)**
- No API; filesystem only
- Vault path: `~/Documents/Home/`
- Access: `mkdir -p` and bash heredoc `cat >` commands
- File format: Markdown with YAML frontmatter

**Git (setup-worktree)**
- Commands: `git worktree add`, `git show-ref`, `git checkout -b`
- Auth: User pre-configured (SSH or HTTPS creds)
- No credential handling in skill; assumes user has access

---

## Open Questions

1. **Slack token rotation:** SKILL.md specifies looking up `SLACK_BOT_TOKEN` but does not address token expiry or rotation. Is the token long-lived, or does it need to be refreshed?

2. **Rate-limit recovery:** Slack and GitHub both have rate limits. The SKILL.md documents do not specify retry logic, exponential backoff, or queue-based sending. What is the intended behavior when rate-limited?

3. **Obsidian vault consistency:** write-to-obsidian uses flat filesystem copy for env files. If the vault is being edited in Obsidian while a skill is writing to it, is there a conflict risk?

4. **PR deviation analysis:** describe-pr dispatches a "general-purpose Agent" for deviation analysis. This agent's prompt is text-heavy and complex. How does the agent handle incomplete or contradictory plan/phase-run evidence?

5. **GitHub remote access:** setup-worktree assumes user has already authenticated with GitHub (via SSH or HTTPS). No credential refresh or validation happens. What if the user's SSH key expired or GitHub token was revoked?

6. **CI log parsing:** ci-deploy-fix documents failure classification (lint, type, test, build, migration, k8s) but parsing is manual via subagent. Are there known limitations or edge cases in classifying unfamiliar CI systems?

7. **Subagent execution model:** Five of the skills rely on dispatching subagents (describe-pr, execute-phase, repo-audit, ci-deploy-fix). The SKILL.md documents do not address:
   - Subagent context window size / truncation
   - Failure recovery (e.g., subagent times out)
   - Determinism (e.g., does re-running the same phase give the same results?)

8. **End-to-end integration:** The core loop (repo-audit → design-plan → execute-phase → describe-pr → post-mortem) relies on stable file paths and FIND-NN/NEW-NN IDs. What breaks if a user runs steps out of order or manually edits outcome files?

9. **No implementation code:** All skills are specification-only. Who/what is responsible for actually implementing them (subagent, human, future refactor)?

---

## Conclusion

All external integrations in this skills directory are **aspirational** — documented in SKILL.md as workflows, with no executable implementation. The five skills that declare external service integration (Slack, Obsidian, GitHub, git) are designed as **skill specifications for human execution or subagent dispatch**, not as autonomous production code.

**Integration quality:**
- **Slack API:** Well-specified but no auto-retry or rate-limit handling; token lookup fallback is user-interactive.
- **Obsidian:** Treats vault as dumb filesystem; no Obsidian API or conflict resolution.
- **GitHub (CLI-based):** Delegates auth to user's pre-configured `gh` tool; no credential refresh; graceful-degrade to text-only if gh unavailable.
- **Git:** Assumes user pre-authenticated; hard-fail if branch conflict or path exists.
- **GitHub Actions:** Diagnosis-only for infra issues; no auto-fix for deploy or k8s failures.

**Gaps:**
- No rate-limit handling documented across any integration.
- No explicit error recovery or retry logic.
- Specification relies on human judgment or subagent reasoning; not deterministic.
- No implementation code to validate against.

**Recommendation:** If these skills are intended for production use, implementation code and integration tests should be added, along with explicit rate-limit handling and retry strategies per service.

