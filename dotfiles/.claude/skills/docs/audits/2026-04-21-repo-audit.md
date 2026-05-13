# Repo Audit — ~/.claude/skills/
**Date:** 2026-04-21
**Context:** Personal global Claude Code skills directory; just-completed 6-skill core-loop refactor
**Scope:** .
**Focus:** all

## Overall state

Fragile but not broken. The 6-skill core loop (repo-audit, design-plan, execute-phase, describe-pr, post-mortem, setup-worktree) was ported and wired up in a single 2026-04-21 refactor and is internally consistent: line counts match the plan, YAML frontmatter parses strictly across all 6 SKILL.md files, ID vocabulary (FIND-NN, NEW-NN, phase numbers) threads across every skill, and five of six phase-run outcome files are in `docs/executions/.phase-runs/`. Every other axis is thin or unproven. The skills are specification-only — no tests, no CI, no end-to-end dogfood on a real repo (Phase 5 halted at target-repo selection), no commit-schema enforcement, no notification mechanism if an unattended `/execute-phase` halts at 3am. A new contributor would need 45–75 minutes to reach first run because the repo has no README and no command index. The follow-on 2026-04-22 brief-mode plan is written but not executed — zero REQ-NN references exist in any SKILL.md. The foundation is real; the surrounding infrastructure is aspirational.

## Findings

### FIND-01 — `/repo-audit` Explore-subagent architecture cannot reliably write fact-pack files
- Severity: **high**
- Category: built-vs-planned
- Evidence: Observed during this audit run. 7 of 13 fact-packs had to be written by the orchestrator as a recovery path because Explore subagents returned their content inline rather than writing to `docs/audits/.fact-packs-2026-04-21/`. `/repo-audit/SKILL.md` (313 lines) specifies fan-out to 13 parallel Explore subagents, but Explore-type subagents don't reliably have Write tool access for the target paths used.
- Impact: The headline skill of the core loop can't complete its documented workflow without orchestrator intervention; defeats the map-reduce design and burns tokens re-running agents.

### FIND-02 — Zero end-to-end dogfood on a real repo
- Severity: **high**
- Category: tests
- Evidence: `docs/executions/.phase-runs/2026-04-21-phase-5.md` records the integration dogfood halted at Task 1 (target-repo selection, a `[human]` gate). Five deferred checks remain: `dry_run=true` path, `/setup-worktree` live run, `/describe-pr` live PR, `/post-mortem` live run, cluster-grouping heuristic. No self-tests, no test runner, no CI (`find` returns 0 test/spec/Makefile/workflow files).
- Impact: Every claim the 6 skills make about test-status reporting, PR-body synthesis, verification-subagent behavior, and dry-run mode is designed but unproven. The loop has never closed on a real repo.

### FIND-03 — Zero CI and no commit-message schema enforcement
- Severity: **high**
- Category: ci-workflows
- Evidence: No `.github/workflows/`, `Makefile`, `.pre-commit-config.yaml`, or `package.json`. `git remote -v` is empty. `/execute-phase` produces commits with schema `phase-<N>: <Goal> (addresses <IDs>)` that `/post-mortem` and `/describe-pr` parse, but nothing validates that schema. A malformed SKILL.md YAML frontmatter or a mis-formatted commit would go undetected until load time or downstream parse time.
- Impact: The three load-bearing contracts of the loop (SKILL.md YAML, commit-message schema, directory conventions) all depend on authorial discipline with no automated gate.

### FIND-04 — No failure-notification path; core-loop skills designed to run unattended but can't wake the user
- Severity: **high**
- Category: operability
- Evidence: Fact-pack 09 grepped all SKILL.md files: 0 occurrences of "notify", "alert", "email", "slack" in error-handling rows; 0 "log" outside `git log`; 0 "timeout"/"backoff"/"circuit-breaker"; 1 "retry" total. `/execute-phase` with `auto_proceed=true` halts on scope violation or verification fail, writes the outcome file, and surfaces to chat — but if the user is asleep, nothing pings them. `.omc/state/last-tool-error.json` is a singleton (not a log).
- Impact: Autonomous execution is the premise of the core loop; a silent 3am halt leaves a phase branch checked out blocking main with no out-of-band alert.

### FIND-05 — Brief-mode extension (2026-04-22 plan) designed but not executed
- Severity: **high**
- Category: built-vs-planned
- Evidence: `2026-04-22-design-plan-brief-mode.md` (196 lines) specifies REQ-01 edits across 5 skills. Validated grep for `REQ-NN|REQ-01` across all SKILL.md files: 0 matches. Validated grep for `brief` in design-plan inputs: 0 matches for the input parameter (other "brief" hits are generic prose in write-to-obsidian, describe-pr, execute-phase). `/design-plan/SKILL.md` has no `brief` input, no adaptive phase-count logic. `/execute-phase/SKILL.md` hardcodes `refactor/` branch prefix. `/post-mortem/SKILL.md` globs only `refactor/phase-*`.
- Impact: Users can't run `/design-plan` on bug or feature-scale work without first generating an audit, even though the design for that case already exists.

### FIND-06 — `/setup-worktree` silently copies `.claude/settings.local.json` into isolated worktrees
- Severity: **medium**
- Category: security-depth
- Evidence: `/setup-worktree/SKILL.md` line 95 (validated): `.claude/settings.local.json (if .claude/ exists in destination, copy inside; else skip)`. Lines 152, 157 show it in the default copy list with no warning. This file can hold API preferences, auth flags, and local permissions.
- Impact: If the user runs `/setup-worktree` without auditing that file first, local Claude Code settings propagate unencrypted to `~/wt/<repo>/phase-<N>/`. Not a hot-secret leak but a settings-exfiltration shape.

### FIND-07 — No README, no command index, no skill matrix
- Severity: **medium**
- Category: onboarding, doc-drift, user-surface
- Evidence: Fact-pack 12 confirms `/Users/alexwelch/.claude/skills/` has no README.md, CONTRIBUTING.md, or GETTING_STARTED.md. Fact-pack 11 confirms no `SKILL_INDEX.md` or `COMMANDS.md`. The two root markdown files are shipped design plans, not entry docs. Fact-pack 08 notes `/repo-audit` Step 0 preflight expects a README at repo root. Realistic time-to-first-run estimated at 45–75 minutes.
- Impact: Discovery is per-file across 11 SKILL.md files (2,957 total lines); the 4-skill loop topology must be mentally compiled from pairing sections in each skill.

### FIND-08 — Unbounded data retention for phase-runs and plans
- Severity: **medium**
- Category: security-depth
- Evidence: `docs/executions/.phase-runs/` holds 7 outcome files (validated) and accumulates indefinitely; no deletion policy. `docs/plans/` doesn't exist yet but has no TTL in its spec. `.gitignore` correctly excludes `.omc/state/` and `.fact-packs-*/` but intentionally tracks phase-run outcomes as audit trail.
- Impact: Low immediate cost (<10KB today) but scales linearly with usage; no policy for what to prune after N months.

### FIND-09 — 5 installed skills have inconsistent frontmatter vs. core-loop standard
- Severity: **medium**
- Category: module-inventory, user-surface, entry-points
- Evidence: Core-loop skills have complete frontmatter with explicit `triggers:` array, `inputs:`, `reads:`, `writes:`, `## Example Invocation`, and `## Error Handling` table. Installed skills drift: `ci-deploy-fix` (219 lines) has triggers in description only, no Example Invocation; `slack-update` (118 lines) same pattern, partial Example; `td-task-management` (215 lines) has name+description only and no error table; `write-to-obsidian` and `omc-reference` marked `user_invocable: false`.
- Impact: Inconsistent discovery surface; two skills (ci-deploy-fix, slack-update) live on keyword triggers in description text instead of formal `triggers:` arrays.

### FIND-10 — `ci-deploy-fix` presupposes GitHub Actions infrastructure this repo lacks
- Severity: **medium**
- Category: integrations, ci-workflows
- Evidence: `ci-deploy-fix/SKILL.md` uses `gh run view`, `gh run list --workflow=ci.yml`, and references Ruff/mypy/pytest/Docker/Trivy patterns. This repo has no GitHub remote, no `.github/workflows/`, no CI. The skill targets consumer repos, not this repo itself. Not a bug, but a mismatch with the current repo's state that would bite if someone ran it here.
- Impact: Dogfooding `/ci-deploy-fix` on this repo is impossible until a remote + Actions exist; the skill's self-documented workflow can't self-validate.

### FIND-11 — Organizational context leak in slack-update examples
- Severity: **medium**
- Category: config-secrets
- Evidence: `slack-update/SKILL.md` (validated) contains `classdojo/iris` at lines 14, 29, 113, 117 — employer + internal project name, including `~/projects/iris/.env` as a hardcoded token fallback and GitHub PR URLs like `github.com/classdojo/iris/pull/128`. Not live credentials; documentation strings.
- Impact: If this repo is ever pushed to a public remote, employer + internal project name go with it.

### FIND-12 — Empty `new-project/` directory
- Severity: **low**
- Category: built-vs-planned, legacy-vs-new
- Evidence: Validated: `new-project/` exists and contains zero files. Not mentioned in either the 2026-04-21 or 2026-04-22 plan. No SKILL.md, no references/, no content.
- Impact: Placeholder or cleanup miss. Harmless but confusing to a new reader.

### FIND-13 — Pairing sections are prose, not ASCII-art diagrams
- Severity: **low** (downgraded from fact-pack 08's original high; evidence conflicts)
- Category: doc-drift
- Evidence: Fact-pack 08 claimed "pairing diagrams are missing or incomplete" and cited the 2026-04-21 plan §5.4 tasks 5-8. Validation: grep for `pairing|core loop|side-car` hits all 6 core-loop SKILL.md files. `post-mortem/SKILL.md:280-283`, `repo-audit/SKILL.md:304-311`, `design-plan/SKILL.md:430-445` all contain prose pairing sections naming the full 4-skill core + setup-worktree side-car. The plan's §11 shows one ASCII example, but the skills write the same topology as prose, and the fact-pack's own quoted text from `post-mortem` line 281 is the pairing section it called "missing." The finding as originally stated (no pairing diagrams) is unverified.
- Impact: Real drift would be missing topology documentation; actual state is present-but-not-ASCII. Stylistic, not structural. See Open questions.

### FIND-14 — td-task-management has no slash-command surface
- Severity: **low**
- Category: entry-points, user-surface
- Evidence: Fact-pack 03 confirms no `triggers:` array; the skill is accessed via bash `td <subcommand>`. Fact-pack 02 notes frontmatter is name + description only. No error handling table.
- Impact: Discoverability via Claude Code's skill loader is nil; users must know about the `td` CLI out-of-band.

### FIND-15 — `.omc/state/` writes are not atomic and state can desync from `.phase-runs/`
- Severity: **low**
- Category: operability
- Evidence: Fact-pack 09 found no mention of atomic writes, temp-file-rename, or schema versioning in any SKILL.md or `.omc/state/` file. `mission-state.json`, `subagent-tracking.json`, `last-tool-error.json`, `agent-replay-*.jsonl` all appear to be direct writes.
- Impact: Kill Claude Code mid-write and `.omc/state/` could disagree with `.phase-runs/`; `resume=true` could retry a done phase or skip one.

## Top three

**FIND-01 — Explore-subagent architecture can't reliably Write fact-packs.** The repo's flagship skill, `/repo-audit`, specifies fan-out to 13 parallel Explore subagents with the explicit instruction to write fact-pack files to disk. In practice during this very audit run, 7 of 13 agents returned content inline and the orchestrator had to write the files. This is the closest thing we have to an "it doesn't work" finding, and it was discovered by dogfooding. The skill should switch to general-purpose subagents with explicit Write-path scope, or add an orchestrator fallback that's formally documented rather than emergent.

**FIND-02 — No end-to-end exercise on a real repo.** The entire 4-skill core loop — audit, plan, execute, describe, post-mortem — has been validated against contrived `/tmp/` targets and YAML-parse checks. Phase 5 dogfood halted at target-repo selection and never resumed. Every claim about verification subagents, commit-schema parsing, dry-run mode, cluster grouping, and `/setup-worktree` env-file copy is designed but never exercised with real inputs. This is the single highest-leverage gap: one Phase 5 run against any small real repo would collapse half the unknowns in this audit.

**FIND-03 — Zero CI, no commit-schema validation, no SKILL.md YAML gate.** The loop depends on three unenforced contracts: strict-YAML frontmatter, `phase-<N>: <Goal> (addresses <IDs>)` commit messages, and directory conventions under `docs/`. A `.pre-commit-config.yaml` with a 30-line Python YAML check plus a commit-msg regex would catch 90% of the silent-corruption surface. Without it, a malformed SKILL.md or commit goes undetected until a downstream skill parses it wrong.

## Detailed findings by question

### 01 — built-vs-planned
Fact-pack 01 confirmed the 6-skill core-loop refactor (phases 0–5 of 2026-04-21) is shipped: all six skills exist with line counts matching plan. Brief-mode plan (2026-04-22) is unexecuted — zero REQ-NN references in any SKILL.md. Five skills (ci-deploy-fix, omc-reference, slack-update, td-task-management, write-to-obsidian) exist outside plan scope; `new-project/` is empty; `docs/plans/` doesn't exist on disk despite being the plan's specified output path. **Extracted:** FIND-05, FIND-12.

### 02 — module-inventory
Fact-pack 02 confirmed 11 skills totaling 2,957 lines of SKILL.md (validated exactly). Core-loop skills all have complete `reads:`/`writes:` blocks forming the documented dependency graph. Installed skills vary in frontmatter completeness. **Extracted:** FIND-09 (in combination with 11).

### 03 — entry-points
Fact-pack 03 documented 38 distinct trigger phrases across 9 invokable surfaces with zero trigger overlap. 6 core-loop skills have formal `triggers:` arrays; ci-deploy-fix and slack-update have keyword triggers in description only; td-task-management has no slash surface (bash CLI only); write-to-obsidian and omc-reference are `user_invocable: false`. No central command index. **Extracted:** FIND-09, FIND-14, and the discoverability half of FIND-07.

### 04 — legacy-vs-new
Fact-pack 04 confirmed clean state: 2 commits, zero `.bak`/`.old`/`.orig` files, no commented-out sections, no deprecation language in any SKILL.md. All 11 skills are current and load-bearing; no duplicated functionality. **No new findings extracted** — this is the "healthy" axis.

### 05 — tests
Fact-pack 05 confirmed no formal test suite, no test runner, no CI workflow. The 6 core-loop skills make claims about consuming test status from target repos but are not themselves tested. Phase-run outcome files are meta-tests (YAML parse + file I/O + basic dispatch). Phase 5 dogfood halted at target-repo selection. Five deferred checks remain: `dry_run=true`, `/setup-worktree` live, `/describe-pr` live, `/post-mortem` live, cluster-grouping heuristic. **Extracted:** FIND-02.

### 06 — config-secrets
Fact-pack 06 found no committed credentials, no `.env*` files, `.gitignore` correctly excludes OMC runtime state. Baseline commit `b9a579e` captured only session UUIDs and cost stats. Organizational context (`classdojo`/`iris`) leaks in slack-update examples; username `alexwelch` appears in phase-run outcome files (working artifacts); no `/Users/alexwelch/` absolute paths in skill bodies themselves. **Extracted:** FIND-11.

### 07 — integrations
Fact-pack 07 mapped 5 skills with external integrations (slack-update → Slack API, write-to-obsidian → local FS, describe-pr → gh CLI, setup-worktree → git, ci-deploy-fix → GitHub Actions). All documented as specifications; no implementation code (`.py`, `.js`, `.sh`). No rate-limit handling, no retry logic, no backoff, no token rotation across any integration. Failure modes vary from hard-fail (slack-update, setup-worktree) to graceful-degrade (describe-pr, write-to-obsidian). **Extracted:** FIND-10 (ci-deploy-fix mismatch), informs FIND-04 (no alerting).

### 08 — doc-drift
Fact-pack 08 flagged pairing diagrams as CRITICAL-missing and brief-mode edits as MEDIUM-unknown. Validation found pairing *sections* exist as prose in all 6 core-loop skills (post-mortem:280, repo-audit:305, design-plan:430) — the finding was partially wrong. Brief-mode claim validated as accurate (0 REQ-NN matches). README absence confirmed; cross-skill ID vocabulary (FIND-NN, NEW-NN, phase-N) consistent across all files. **Extracted:** FIND-05, FIND-07 (README half), FIND-13 (downgraded per validation).

### 09 — operability
Fact-pack 09 confirmed no unified error observability layer. 6 of 13 skills have `## Error Handling` tables; 0 occurrences of log/notify/alert/email/slack in error rows; 1 retry mention total; 0 timeout/backoff/circuit-breaker. `.omc/state/` captures agent-level lifecycle but not task-level failures. `/execute-phase` can halt unattended at 3am with no out-of-band notification. `.omc/state/` writes are not atomic. **Extracted:** FIND-04, FIND-15.

### 10 — security-depth
Fact-pack 10 found strong compartmentalization: no committed secrets in 2-commit history, no `.env` files, `.gitignore` correct, no destructive git operations (`git reset --hard`, `git push --force`) in any skill. Three medium concerns: unbounded retention, unrestricted tool access per skill, and `/setup-worktree` copying `.claude/settings.local.json`. **Extracted:** FIND-06, FIND-08.

### 11 — user-surface
Fact-pack 11 found strong consistency inside the core loop (`triggers:`, Example Invocation, Error Handling all present) and variable quality outside it. 5 installed skills drift from the core-loop template. No central command index. **Extracted:** FIND-07 (index half), FIND-09.

### 12 — onboarding
Fact-pack 12 estimated 45–75 minutes from clone to first successful `/repo-audit`. Blockers: no README, no skill matrix, no CONVENTIONS doc, no mention of git-identity/Python/pyyaml prerequisites, hardcoded `~/wt/` default with no upfront explanation, implicit `~/.claude/skills/` auto-load. **Extracted:** FIND-07.

### 13 — ci-workflows
Fact-pack 13 confirmed zero CI infrastructure (no `.github/workflows/`, no Makefile, no `.pre-commit-config.yaml`, no remote). SKILL.md YAML validation is manual per the 2026-04-21 plan's §10 DoD. Commit-message schema (`phase-<N>: <Goal> (addresses <IDs>)`) is unenforced despite being load-bearing for `/post-mortem` and `/describe-pr` parsing. `/ci-deploy-fix` presupposes GitHub Actions this repo lacks. **Extracted:** FIND-03, FIND-10.

## Biggest gaps and risks

The leverage cluster is **FIND-01 / FIND-02 / FIND-03** — they compound. `/repo-audit`'s subagent architecture is unreliable (FIND-01), so evidence gathering is partial. The whole loop has never run end-to-end on a real repo (FIND-02), so every downstream skill's claims are unproven. And there's no CI gate (FIND-03), so when a skill breaks silently, nothing flags it. The fastest way to collapse uncertainty is to pick any small real repo and force a Phase 5 run — doing so would exercise FIND-02 directly, expose any further FIND-01-class failures, and motivate the FIND-03 pre-commit guardrails by surfacing the first real commit-schema or YAML regression.

FIND-04 (no failure notification) and FIND-15 (non-atomic `.omc/state/` writes) are latent risks that only bite during autonomous unattended execution — they're cheap to ignore today and expensive to ignore once `/execute-phase` becomes a nightly habit.

FIND-06 (settings.local.json copy), FIND-08 (retention), and FIND-11 (org-context leak) form the "don't push this repo public without cleanup" set.

FIND-07 (no README), FIND-09 (installed-skill frontmatter drift), FIND-14 (td-task-management no slash surface) are solo-dev-tolerable but kill discoverability for anyone else.

FIND-05 (brief-mode not executed) is a known-unknown — the design exists; running it is a 1-2 hour task once Phase 5 is unblocked.

## Implementation patterns

The best-built piece is **`/execute-phase`** (527 lines, `execute-phase/SKILL.md`). It has: 6 explicit inputs with defaults and types, 11 procedure steps with branch/dispatch/verify/commit semantics spelled out, an 18-row `## Error Handling` table that distinguishes abort/halt/degrade behaviors per failure mode, two `## Example Invocation` blocks (clean path + verification-fail path), explicit scope-verification via post-batch subagent, and a structured outcome file write under `docs/executions/.phase-runs/` that downstream skills consume. Its frontmatter parses strict-YAML, its `reads:`/`writes:` blocks form a contract with sibling skills, and its persona/voice matches the rest of the core loop.

**Pattern new work should follow:**
- Strict-YAML frontmatter with `name`, `description`, `triggers:` array, typed `inputs:`, `reads:`, `writes:`, `persona`.
- A `## Error Handling` table with concrete outcome per row (abort | halt | degrade | warn+continue) — no ambiguous verbs.
- A `## Example Invocation` block showing user input plus expected Claude output, ideally two scenarios (clean + failure).
- A `## Pairing` section (prose is fine per FIND-13) naming explicit upstream/downstream skills and shared ID vocabulary.
- A structured output-file contract with a filename pattern and header schema that downstream skills can parse.
- The 5 installed skills (per FIND-09) should be regularized to this pattern before they accumulate more drift.

## Recommended next steps

1. **Pick a small real repo and run the full loop.** Addresses FIND-02, validates FIND-01 (reproduces or refutes the Explore-subagent Write issue in production), exercises all 5 deferred checks. **Effort:** 2–4 hours.

2. **Replace Explore-subagent fan-out in `/repo-audit` with general-purpose subagents that have explicit Write scope — or formalize the orchestrator-fallback path.** Addresses FIND-01. Either way, document the actual working mechanism. **Effort:** 1–2 hours.

3. **Add `.pre-commit-config.yaml` with strict-YAML check + commit-msg schema regex.** Addresses FIND-03. One hook script for each; checks `SKILL.md` files on staged change and validates commit messages match `phase-<N>: <Goal> (addresses <IDs>)`. **Effort:** 1 hour.

4. **Add a root README.md with: one-paragraph purpose, 4-skill loop diagram (ASCII is fine), skill-matrix table (Skill | Input | Output | Use when), prerequisite list (git identity, Python 3 + pyyaml), link to the two design plans as history-not-entry.** Addresses FIND-07. **Effort:** 30 minutes.

5. **Execute 2026-04-22 brief-mode plan Phase 1.** Addresses FIND-05. Five SKILL.md edits per the plan spec. **Effort:** 1–2 hours (blocks on #1 being done first so brief-mode can be dogfooded).

6. **Add failure-notification primitive — append to `.omc/state/unresolved-halts.txt` on any `/execute-phase` halt; optional: webhook-to-chat integration.** Addresses FIND-04. **Effort:** 1 hour for the file primitive; more if webhook.

7. **Regularize the 5 installed skills (ci-deploy-fix, slack-update, td-task-management, write-to-obsidian, omc-reference) to core-loop frontmatter template.** Addresses FIND-09, FIND-14. Anonymize `classdojo/iris` in slack-update examples (FIND-11) while you're there. **Effort:** 2–3 hours.

8. **Audit `.claude/settings.local.json` contents and either exclude it from `/setup-worktree` copy or add a pre-copy warning.** Addresses FIND-06. **Effort:** 30 minutes.

## Open questions / unverified claims

- **FIND-13 (pairing diagrams).** Fact-pack 08 claimed pairing diagrams were CRITICAL-missing, citing 2026-04-21 plan §5.4 tasks 5-8 and the §11 ASCII example as the required form. Validation found prose pairing sections in all 6 core-loop skills (e.g. `post-mortem/SKILL.md:280-283`) — fact-pack 08 even quotes this text while calling it missing. The finding has been downgraded to **low** severity. **Open question:** was the plan's DoD "update the loop diagram" satisfied by prose pairing sections, or did it require ASCII-art specifically? The plan's actual §5.4 task text would need to be checked against the intent — the fact-pack's citation doesn't fully resolve it.

- **`new-project/`.** Was it a planned skill-stub, a cleanup miss, or a scratch directory that never got content? Fact-packs don't say (FIND-12).

- **Brief-mode Phase 0 preflight status.** The 2026-04-22 plan specifies Phase 0 tasks (confirm five skills parse, backup/git check, catalog FIND-NN references). No artifact exists to show whether Phase 0 ran separately from Phase 1 (FIND-05).

- **`/describe-pr` REQ-NN regex.** Fact-pack 01 claims "describe-pr's ticket-reference regex searches for FIND-NN, NEW-NN, phase-N, and common patterns, but no explicit REQ-NN handling." Validation found 2 `brief|REQ-NN` hits in describe-pr/SKILL.md, but context wasn't checked — could be generic "brief" usage rather than REQ-NN awareness. Unconfirmed.

- **td-task-management/references/.** Fact-pack 02 notes `ai_agent_workflows.md` and `quick_reference.md` exist but aren't referenced by other skills. Is this by design (bash-CLI is the interface) or a gap?

- **Whether all 13 fact-packs were truly authored by subagents or by the orchestrator.** The audit prompt flags that 7 of 13 were orchestrator-written recovery — FIND-01 is based on that observation, not on re-running the fan-out. If the stated ratio is wrong, FIND-01's severity could change.
