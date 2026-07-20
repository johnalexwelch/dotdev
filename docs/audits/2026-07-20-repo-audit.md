# Repo Audit — dotdev
**Date:** 2026-07-20
**Context:** Personal monorepo "dotdev" holding stow-managed dotfiles, agent/skill configuration for Claude Code & Codex, execution-artifact docs, and setup scripts; owner asked whether it's set up properly, what shouldn't be there, and what's overkill.
**Scope:** whole repo (`/Users/alexwelch/dotdev`)
**Focus:** all (setup correctness, shouldn't-haves, overkill)

## Overall state

The repo works day-to-day but is mid-refactor and its quality machinery is decorative rather than enforcing. The live agent surface (95 skills, stow symlinks, herdr/openwiki/pi wiring) functions on this machine, and the recurring self-audit loop has verifiably closed several prior findings (FIND-01/02/05). But three independent quality gates are all silently non-functional at once: CI has failed on every push to `main` for over a month and gates nothing (no branch protection); the bash test suite is never run by CI and, when run by hand, aborts on a 320-line test file (`test/test-tmux-dev.sh`) that exercises scripts deleted weeks ago; and the nightly OpenWiki doc pipeline has been failing on a Node native-module ABI mismatch for days while logging a false "docs already current." An uncommitted symlink refactor (`.claude/skills`/`docs` deletions) sits in the working tree that, if committed as-is, breaks fresh-machine reproducibility. A private SSH key committed 18 months ago remains extractable from public git history and was never purged. And the process scaffolding — dual decision-record mechanisms, 32 execution artifacts, reflection files that a documented rule says should never be written, 75MB of `.git` bloat from stashed one-off analysis blobs — has outgrown what a one-person dotfiles repo needs. Nothing is on fire, but "set up properly" is currently truer of the docs than of the enforcement behind them.

## Prior findings status

Only rows with evidence in the 2026-07-20 fact-packs are listed; FIND-03/04, 07/08, 11–18, 21–24, 26–28 have no re-verifying evidence in this pass and are omitted rather than guessed.

| ID | Status | Evidence |
|----|--------|----------|
| FIND-01 (hardcoded `/Users/alexwelch` in SessionStart hooks) | **Fixed** | `grep /Users/alexwelch dotfiles/.claude/settings.json` → no matches (pack 01 §G, re-verified). |
| FIND-02 (pi-fork routes to unconfigured openrouter) | **Fixed** | `pi-fork` now anthropic-based, no openrouter (pack 01 §G). |
| FIND-05 (arc.sh / security-init.sh not executable) | **Fixed** | both now 755 (pack 01 §G). |
| FIND-06 (tmux-session-switch.sh undocumented) | **Superseded / moot** | script no longer exists; `ls scripts/tmux-session-switch.sh` → No such file. Now a dangling *test* reference instead (see FIND-30). |
| FIND-09 (SSH private key extractable from public history) | **Still open** | `git show 449613f:dotfiles/config/ollama/id_ed25519` → `-----BEGIN OPENSSH PRIVATE KEY-----` (re-verified); repo still public; no history rewrite. |
| FIND-10 (pre-commit/git-secrets never installed locally) | **Still open** | `core.hooksPath=.githooks` holds only `commit-msg`; no local pre-commit hook (pack 03 §11). |
| FIND-19 (`mcp.json` hardcodes `github-mcp-pi` absolute path) | **Still open** | `dotfiles/.config/mcp/mcp.json` and `.pi/agent/mcp.json` both hardcode `/Users/alexwelch/.local/bin/github-mcp-pi`; wrapper untracked (pack 05). |
| FIND-20 (AI_ENVIRONMENT / SETUP_WRITEUP mutual + reality drift) | **Still open** | skill-count claims still disagree (95 vs ~90), SETUP_WRITEUP references nonexistent hooks/CHORUS paths (pack 06). |
| FIND-25 (`mcp.json` broken server; real MCP fleet uncaptured) | **Still open** | only `github`/`granola` live in `~/.claude.json`; Slack/Notion/Asana/etc. connector-level, uncaptured (pack 05). |
| FIND-29 (CI Lint job fails; `detect-secrets` blocks green CI) | **Still open (specifics moved)** | now fails on `dotfiles/.config/nvim/lazy-lock.json:2` + `openwiki/.last-update.json:4` + an openwiki doc, not the originally-cited `lazy-lock.json:12–42`; `.secrets.baseline` still stale (2025-01-06). Now compounded by auto-fixing hooks re-failing every run (pack 03 §3, §10). |

## Findings

New findings, most-severe-first. Recurrences of prior IDs are referenced above, not re-minted.

**FIND-30 — Dangling test file + CI never runs the test suite**
Severity: high · Category: tests/CI
Evidence: `bash test/run-tests.sh` exits 1 (re-verified); `test/test-tmux-dev.sh` (320 lines) fails on `scripts/tmux-dev.sh` / `scripts/tmux-session-switch.sh` — neither exists (`ls` → No such file). Because `run-tests.sh` uses `set -e`, the 3 later test files (`test-sync-codex-skills.sh`, `test-skill-suite-lint.sh`, `test-workflow-guard.sh`) never execute in that invocation; run individually they pass (14/0, 5/0, 6/0). `.github/workflows/ci.yml` has zero references to `test/` (`grep run-tests|test/test- .github/workflows/*.yml` → none), yet `docs/TESTING.md` documents a fictional `🧪 Test Dotfiles` CI job running `./test/run-tests.sh`. Undetected since the 2026-06-15 "bloat removal" (commit `0e05f16`).
Impact: The one test suite the repo ships is broken and invisible to automation, so regressions in commit-normalize / skill-lint / codex-sync logic ship unnoticed.

**FIND-31 — CI has been red on `main` for over a month and gates nothing**
Severity: high · Category: CI/process
Evidence: last green run on `main` was 2026-06-19; every run since through 2026-07-17 is `failure`; 50 most recent runs (any branch) are 48 failure / 2 cancelled / 0 success (pack 03 §2). The Lint job re-fails identically every run because its auto-fixing hooks (`trailing-whitespace`, `markdownlint`, `shfmt`, `yamlfmt`, `end-of-file-fixer`) modify files and exit non-zero, and their fixes are never committed back — a structural, not transient, failure. `gh api .../branches/main/protection` → 404, so no protection; most events are direct `push`. Renovate PRs inherit the same red.
Impact: The most visible quality signal in the repo is permanently red and blocks nothing, training the owner to ignore it entirely — so a *real* failure would also be ignored.

**FIND-32 — OpenWiki nightly pipeline silently failing while logging success**
Severity: high · Category: integrations/ops
Evidence: `openwiki/.last-update.json` → `updatedAt 2026-07-17T13:55:39Z`, `gitHead 51f5ac7` (stale vs HEAD, re-verified). Launchd job `com.alexwelch.openwiki` fires nightly and fails the actual generation step with `better_sqlite3.node ... compiled against NODE_MODULE_VERSION 127 ... requires 147` for ≥3 straight days (07-18/19/20), then logs `WARN ... exited nonzero` immediately followed by `OK /Users/alexwelch/dotdev docs already current` — the fallback message masks the failure as a no-op. For `~/projects/agents/iris` the same job errors daily on `gh pr create` (`No commits between main and openwiki/update`).
Impact: The doc layer CLAUDE.md names as source of truth is stale and drifting from HEAD, and the misleading "OK" log means nothing surfaces the breakage.

**FIND-33 — Uncommitted symlink deletion will break fresh-machine reproducibility if committed as-is**
Severity: medium · Category: architecture/state
Evidence: working tree deletes 4 tracked mode-120000 symlinks (`dotfiles/.claude/skills`, `.claude/docs`, `.config/agents/skills/find-skills`, `.config/agents/skills/herdr`) — re-verified via `git status --porcelain` (4 `D`). `find-skills`/`herdr` are materialized as real untracked dirs. Live `~/.claude/skills` still resolves *only* because it was hand-patched to an absolute symlink (`readlink` → `/Users/alexwelch/.config/agents/skills`), not derived from the repo. So functionality is not broken *now*; the risk is conditional: committed as-is, `install.sh`/stow would no longer create `~/.claude/skills`, and it contradicts still-current README/SETUP_WRITEUP structure docs. Intent is undocumented (no commit/plan/handoff addresses the deletion).
Impact: A fresh `install.sh` today would not produce `~/.claude/skills` at all, silently breaking skill resolution on any rebuilt machine.

**FIND-34 — pre-commit skill-lint hooks point at a path deleted in the working tree (latent break)**
Severity: medium · Category: CI/config
Evidence: `.pre-commit-config.yaml:35,40` hardcode `entry: dotfiles/.claude/skills/lint-skill-suite.sh` / `lint-skill-refs.sh` (re-verified); that directory is gone from disk (only `skills.zip` remains). Real scripts now live at `dotfiles/.config/agents/skills/`. Direct invocation reproduces exit 127. Last-committed HEAD's CI still passed these hooks (pre-migration), so this is latent — it fires the moment the FIND-33 deletion is committed without updating the hook paths.
Impact: Committing the in-flight refactor without fixing these two lines turns the (already red) Lint job into a hard 127 error and breaks local pre-commit for anyone who runs it.

**FIND-35 — `.git` is 75MB from one-off analysis blobs reachable only via an old stash**
Severity: medium · Category: data/state
Evidence: `.git` 75M vs ~4MB working content (`/usr/bin/du -sh .git .` → 75M / 80M, re-verified). Largest pack blobs are all `outputs/ai-trenches-analysis/*` (up to 79.6MB `all_ai_session_index.json`); `git log --all -- outputs/...` → empty (not in any branch), reachable via `refs/stash`. 6 stash entries exist, none dropped (re-verified); `outputs/` is gitignored but that doesn't unpack already-stashed blobs.
Impact: Every clone drags ~75MB of dead analysis data; disk won't reclaim until stashes are dropped AND `git gc --prune=now` runs.

**FIND-36 — `Bash(*)` + auto-mode + suppressed prompts is effectively unrestricted agent shell**
Severity: medium · Category: security/config
Evidence: `dotfiles/.claude/settings.json` — `Bash(*)` allowed, `defaultMode: "auto"`, `skipDangerousModePermissionPrompt: true`, `skipAutoPermissionPrompt: true` (all re-verified at lines 9/52/177/184). Deny list blocks only `sudo`, force-push, `rm -rf /`, `rm -rf ~`. The compensating PostToolUse secret-grep hook is advisory (`|| true`), doesn't block.
Impact: Any agent session can run essentially any shell command without confirmation; the blast radius is the whole machine, offset only by an advisory warning.

**FIND-37 — session-insight reflection files written in violation of the repo's own rule**
Severity: low · Category: process/docs
Evidence: commit `77a7c62` (2026-07-16) rewrote `session-insight/SKILL.md` to state reflections are "write-only clutter... never `docs/executions/reflections/`." Yet 9 new reflection files dated 2026-07-17→19 sit in exactly that path (16 on-disk vs 7 tracked, re-verified — fact-pack 06 counted 17; live churn). All untracked.
Impact: A documented behavioral rule is being ignored by the agents that read it, producing unconsumed clutter and demonstrating that skills-as-prompts don't self-enforce.

**FIND-38 — Two parallel decision-record mechanisms; ADR numbering starts at 0002, uncommitted**
Severity: low · Category: docs/architecture
Evidence: `docs/adr/` contains only `0002-sole-routing-authority.md` (re-verified), no `0001`, entire dir untracked. `docs/decision-log.md` (tracked, DL-NNNN) explicitly argues ADRs are "Overkill" for this repo. A third, disjoint ADR set lives at `~/.claude/docs/adr/` (3 different files, live-only, different inode) — neither ADR location is version-controlled.
Impact: Decision content is split across two competing conventions and two disconnected directories, neither durably tracked — decisions can be silently lost.

**FIND-39 — Five root docs are stale generic templates contradicting the repo**
Severity: low · Category: docs drift
Evidence: `docs/{INSTALLATION,SHELL,TESTING,MACOS,APPLICATIONS}.md` — `SHELL.md` claims `EDITOR='nvim'` (real: `code`) and lists aliases that don't exist; `INSTALLATION.md` lists Warp/iTerm2/gcloud/Docker not in the Brewfile (real: ghostty/awscli/orbstack); `TESTING.md` documents a nonexistent CI job (pack 02 §9). Unlike AI_ENVIRONMENT/SETUP_WRITEUP, these carry no staleness caveat.
Impact: A new reader following these docs hits wrong editor config, phantom aliases, and apps that were never installed.

**FIND-40 — CONTEXT-MAP.md (untracked) links to gitignored, machine-local `.claude/CONTEXT.md`**
Severity: low · Category: docs drift
Evidence: `?? CONTEXT-MAP.md`; it links `.claude/CONTEXT.md`, which is under the gitignored root `/.claude/` (`git check-ignore -v` → `.gitignore:145`). The "agents" link `dotfiles/.config/agents/CONTEXT.md` is also untracked. (Distinct from the deliberately-excluded "dotdev needs a CONTEXT.md" item.)
Impact: The document meant to be the map of contexts is itself not durable and half its links resolve only on this machine.

**FIND-41 — `README.md` LICENSE link is dead; genuinely broken live symlink**
Severity: low · Category: docs drift
Evidence: `README.md:116` links `[LICENSE](LICENSE)`; no LICENSE file ever existed (`git log --all -- LICENSE` → empty, re-verified). Separately, `~/.claude/docs/pr-sizing-policy.md` is a broken symlink (target moved by the 2026-07-15 hoist, never fixed) — the one genuinely-broken-now symlink (pack 07 §4).
Impact: Cosmetic for LICENSE; the broken pr-sizing-policy symlink means that policy doc is unreadable at its live path.

**FIND-42 — Unpinned third-party pi packages + inconsistent CI action pinning**
Severity: low · Category: security/supply-chain
Evidence: `dotfiles/.pi/agent/settings.json` pulls ~21 packages including two git-sourced forks (`git:github.com/elpapi42/pi-fork`, `pi-codemapper`), none version/commit-pinned. `openwiki-update.yml` SHA-pins all actions; `ci.yml` uses floating `@v4/@v5/@v3` tags including the secret scanner (pack 04 §9, §5).
Impact: Supply-chain drift — unpinned agent extensions run with full context; floating CI tags can change under the repo without notice.

## Top three

**FIND-09 (still open, high → arguably critical given duration).** A real OpenSSH private key sits in the public GitHub history of `johnalexwelch/dotdev`: `git show 449613f:dotfiles/config/ollama/id_ed25519` returns the full `-----BEGIN OPENSSH PRIVATE KEY-----` today. It was committed 2025-01-07, "deleted" the same day with a plain `git rm` (no history rewrite), and has been publicly extractable for ~18 months. Secret scanning was only added 2026-04-10 and scans push ranges, not history, so it never caught this and won't. This is the single most severe open item in the entire corpus — a live-exposure credential in a public repo outranks any process breakage. It stays FIND-09 (prior ID) but belongs at the top: the owner must confirm the key is revoked/rotated, and decide whether to rewrite history (`git filter-repo` + force-push + GitHub cache-purge).

**FIND-31 (new, high).** CI on `main` has been red every push for over a month, fails identically every run by design (auto-fixing hooks that are never committed back), and gates nothing because `main` has no branch protection and commits land by direct push. The danger isn't the red itself — it's that a permanently-red signal trains the owner to ignore CI, so the day a substantive check fails it will also be ignored. This is the keystone of the "quality machinery is decorative" theme and the cheapest high-impact fix: make the hooks check-only (or auto-commit fixes) so green becomes achievable and meaningful again.

**FIND-32 (new, high).** The nightly OpenWiki launchd job — the pipeline that regenerates the doc layer CLAUDE.md designates as source of truth — has failed its generation step for at least three consecutive nights on a `better-sqlite3` Node ABI mismatch (NODE_MODULE_VERSION 127 vs 147), while its own log prints a reassuring `OK ... docs already current`. So `openwiki/` is silently stale relative to HEAD and the failure is actively masked. First fix is trivial (rebuild the native module against current Node); the deeper fix is making the fallback log distinguish "no diff" from "generation errored."

## Detailed findings by question

**01 — Product architecture (built vs. planned / module inventory).** The repo is one canonical skills tree (95 dirs, ~23.4k lines) plus stow configs, scripts, an execution-artifact trail, and a generated OpenWiki layer; it's mid-refactor and 3 days behind its own HEAD with uncommitted work. Sourced FIND-30 (test/CI gap), FIND-32 (OpenWiki), FIND-33 (symlink deletion), FIND-37 (reflection rule), FIND-38 (ADR duality). Confirms the audit/fix loop works (FIND-01/02/05 fixed) but only for things it actually exercises.

**02 — Surface & entrypoints.** `install.sh` is the real, CI-dry-run-tested entrypoint; standalone scripts and zsh aliases are genuine (no stubs). Sourced FIND-34 (broken pre-commit paths), FIND-39 (stale docs), plus style inconsistency (mixed `set -euo pipefail`, mixed shebangs). Note: this pack's Brewfile counts were wrong (see Open questions).

**03 — Tests & CI.** CI is decorative, not enforcing: month-long red, no branch protection, test suite never invoked. Sourced FIND-30 and FIND-31, and re-confirmed FIND-29 (detect-secrets, moved specifics) and FIND-10 (pre-commit never installed locally). Strongest evidence base in the corpus and the anchor for the overkill assessment.

**04 — Security & config.** No tracked secrets today; good env-var handling. But re-confirmed FIND-09 (historical key, critical) and sourced FIND-36 (`Bash(*)` auto-mode) and FIND-42 (unpinned pi packages / floating CI tags). `.secrets.baseline` stale since 2025-01-06.

**05 — Integrations & ops.** Terminal-first, no dashboards/alerting; graceful-degrade patterns are consistent. Sourced FIND-32 detail and re-confirmed FIND-19/FIND-25 (hardcoded/uncaptured MCP). Flagged untracked-but-load-bearing tools (guardian source, hud, `github-mcp-pi` wrapper) and cora schedules not committed (rebuild-reproducibility gap). Brewfile counts here verified correct.

**06 — Docs drift & onboarding.** Mostly minor/cosmetic; README self-flags AI_ENVIRONMENT/SETUP_WRITEUP as semi-deprecated. Sourced FIND-38/39/40/41 (dead LICENSE, broken anchors, CONTEXT-MAP, ADR numbering) and re-confirmed FIND-20. 297 of ~342 markdown files touched in 30 days — docs function as a live execution ledger, not stable reference.

**07 — Data & state.** Working tree small; `.git` 75MB. Sourced FIND-35 (stash blobs), FIND-33 detail (deleted symlinks, the FIND-41 broken live symlink), the dual/diverging ADR sets under FIND-38, and pi/codex checkpoint-ref sprawl. No node_modules/venvs; no in-tree broken symlinks.

## Biggest gaps and risks

What breaks first, in order:
1. **The public SSH key (FIND-09)** is the only item with live external-attacker exposure. If that key is still authorized anywhere, it's an active breach vector today — everything else is internal hygiene.
2. **Committing the in-flight refactor without fixing hook paths (FIND-33 + FIND-34)** is the next thing to break: the moment the symlink deletions land, Lint hard-errors (127) and a fresh `install.sh` stops producing `~/.claude/skills`. These two must land in the same commit or not at all.
3. **The trio of dead gates (FIND-30/31/32)** means the repo has *no* working automated verification: no green-able CI, no CI-run tests, no trustworthy doc regeneration. The risk is slow drift nobody catches — which is exactly how the tmux-test breakage survived 5+ weeks.
4. **`.git` bloat (FIND-35)** is a slow tax, not a break, but compounds every clone/worktree (9 worktrees exist).

The unifying risk: this repo's safety net is entirely self-reported, and three independent reporters are currently lying (red-CI-ignored, tests-not-run, OpenWiki "OK").

## Implementation patterns

The best-built piece is the **OpenWiki scheduled runner** (`dotfiles/.config/openwiki/openwiki-scheduled.sh`, plus its committed `.plist` and `repos.conf`). It is the model new automation should follow: `set -euo pipefail`; explicit `.env` sourcing because launchd doesn't inherit shell env; regeneration inside a throwaway `git worktree` so it never touches the live checkout; a self-defense step (`git checkout -- .github/workflows/openwiki-update.yml`) that prevents OpenWiki from reverting hand-hardening into the PR; best-effort/`|| true` degradation that logs and continues rather than cascading; and its config (plist) committed into the repo so the schedule is reproducible from `dotdev` alone. Notably, cora's schedules do *not* follow this pattern (plists live only on the machine, uncommitted) — the OpenWiki approach is the one to generalize. Its one flaw (the masking "OK" fallback log, FIND-32) is a small blemish on otherwise the most disciplined automation in the repo. The herdr guard pattern in `hdev.sh`/`hlog.sh` (check `HERDR_ENV`, two-line stderr explanation, `exit 1`) is the matching model for user-facing CLI failure UX.

## Overkill assessment

The owner asked directly, so: yes, several parts are overkill for a one-person dotfiles/agent-config repo, and a few have demonstrably not paid off.

- **Quality-gate ceremony vs. zero enforcement (FIND-31/34, FIND-10).** A 5-job CI workflow plus an 8-hook pre-commit config plus a separate `.githooks/commit-msg` is heavy machinery for a personal repo — and it currently gates nothing (no branch protection, month of red, pre-commit never installed locally, tests not wired in). This is the clearest overkill: maximum ceremony, zero enforcement. Either make one lightweight gate actually work, or drop the pretense.
- **Dual decision-record systems (FIND-38).** `docs/decision-log.md` (DL-NNNN) AND `docs/adr/` (which the decision-log itself calls "Overkill"), plus a third disjoint ADR set at `~/.claude/docs/adr/`. Three mechanisms for one person's decisions; pick one.
- **Execution-artifact accumulation (FIND-37).** 32 files across handoffs/reflections/architecture-reviews/.pr-bodies with no pruning policy, including reflection files a documented rule says should never be written and which "nothing consumes." This is pure weight by the repo's own admission.
- **`.git` bloat (FIND-35)** — 75MB of stashed one-off analysis for a ~4MB repo.
- **Two full narrative onboarding writeups** (AI_ENVIRONMENT.md 23KB + SETUP_WRITEUP.md 20KB) that the README already flags as semi-deprecated and drifting (FIND-20), layered over the OpenWiki that's meant to replace them.

Where the machinery **has** paid off, to be fair: the recurring self-audit cadence verifiably closed FIND-01/02/05 (pack 01 §G), so the audit habit itself earns its keep. The stow layout, the OpenWiki worktree-isolation pattern, and the herdr integration are all genuinely well-built and load-bearing. The 95-skill library is large but is the actual product of the repo, not overhead. The overkill is concentrated in the *meta*-layer (gates, decision records, reflections, duplicate onboarding prose), not in the working configuration.

## Module candidates

Per classification `discard | needs-human | research-spike | module-prd-ready`. Confidence and provenance noted; nothing invented beyond fact-pack evidence.

- **MOD-01 — Wire `test/run-tests.sh` into CI and fix/delete `test-tmux-dev.sh`.** `module-prd-ready`. Confidence high. Provenance: FIND-30, packs 01/02/03. Small, well-scoped, unblocks a real gate.
- **MOD-02 — Make CI Lint green-able (check-only hooks or auto-commit fixes) + decide branch-protection posture.** `module-prd-ready`. Confidence high. Provenance: FIND-31, pack 03 §2/§3.
- **MOD-03 — Reconcile the in-flight symlink refactor (FIND-33) + pre-commit paths (FIND-34) as one atomic change.** `needs-human`. Confidence high on the problem, needs owner intent on the target end-state (drop compat symlinks vs. repoint). Provenance: packs 01/03/05/07.
- **MOD-04 — FIND-09 remediation: confirm key revoked; decide history-rewrite.** `needs-human`. Confidence high on the finding; the rewrite decision is a destructive judgment call (breaks clones). Provenance: FIND-09, pack 04 §7.
- **MOD-05 — Fix OpenWiki native-module ABI + de-mask the fallback log.** `module-prd-ready`. Confidence high. Provenance: FIND-32, packs 01/03/05.
- **MOD-06 — Consolidate decision records to one mechanism.** `needs-human`. Confidence medium; requires owner preference (decision-log vs ADR). Provenance: FIND-38.
- **MOD-07 — `.git` slimming (drop stashes + gc, or filter-repo).** `research-spike`. Confidence medium — need to confirm no stash holds wanted work before pruning. Provenance: FIND-35, pack 07.
- **MOD-08 — Retention/pruning policy for `docs/executions/**` + reflection-write enforcement.** `research-spike`. Confidence low-medium; behavioral, not purely mechanical. Provenance: FIND-37, packs 01/06.

## Recommended next steps

Priority-ordered, max 8.

1. **Confirm the leaked SSH key is revoked/rotated (FIND-09).** Effort: minutes to check, then decide. Next workflow: `triage` (open a security issue) → owner decision on history rewrite. Highest severity, do first.
2. **Make CI Lint green-able and decide branch protection (FIND-31 / MOD-02).** Effort: ~1–2h. Next workflow: `to-issues`. Without this every other CI/test fix stays invisible.
3. **Wire the test suite into CI and fix or delete `test-tmux-dev.sh` (FIND-30 / MOD-01).** Effort: ~1h. Next workflow: `to-issues`. Pairs with step 2.
4. **Land the symlink refactor + pre-commit path fix atomically, or revert it (FIND-33 + FIND-34 / MOD-03).** Effort: ~1–2h. Next workflow: `grill-with-docs` (settle target end-state with owner) then `to-issues`.
5. **Rebuild `better-sqlite3` against current Node and de-mask the OpenWiki "OK" log (FIND-32 / MOD-05).** Effort: minutes + small script edit. Next workflow: `triage`.
6. **Regenerate `.secrets.baseline` and triage current detect-secrets findings (FIND-29).** Effort: minutes. Next workflow: `triage`. Unblocks the secret-scan portion of green CI.
7. **Prune stashes + `git gc --prune=now` after confirming no wanted work (FIND-35 / MOD-07).** Effort: ~30m. Next workflow: `triage`.
8. **Decide the meta-layer diet: one decision mechanism, a retention policy for `docs/executions/**`, and enforce (or drop) the reflection-write rule (FIND-37/38 + overkill).** Effort: multi-step, spans docs + a skill change. Next workflow: `design-plan` (only multi-phase item here).

## Open questions / unverified claims

- **Brewfile composition contradiction (surfaced, now resolved).** Pack 02 §5 reported brew 45 / cask ~28 / vscode 34 / npm 4 / taps 5; pack 05 reported brew 66 / cask 43 / vscode 45 / npm 6 / tap 6 / 278 lines. Direct re-count settles it in pack 05's favor: `grep -c` → brew 66, cask 43, tap 6, mas 4, vscode 45, npm 6, 278 lines. Pack 02's numbers are wrong; pack 05's are used throughout. No verdict depends on this.
- **Reflection file count drift.** Pack 06 said 17 on-disk reflections; live re-count shows 16 on-disk / 7 tracked (working-tree churn during the audit). FIND-37 severity unchanged (still low) — the rule-violation pattern is intact regardless of exact count.
- **`git status` modified-count.** Packs reported 20–22 modified; live is 22 M / 18 ?? / 4 D. Immaterial live drift.
- **External / out-of-repo claims not re-verified (accepted as-is from fact-packs, out of scope):** whether the leaked key is still authorized anywhere (FIND-09 live-exposure severity depends on this); whether `~/projects/legacy/chorus`, `~/projects/idea-os/bin/*`, and the cora/gbrain/rowan schedules behave as described; whether `LANGFUSE_HOST=http://192.168.4.43:3050` is reachable. These live outside `dotdev` and could not be checked from the repo.
- **Guardian source location (FIND-04 lineage).** `~/.claude/guardian/` is load-bearing (pre/post-tool hooks) but untracked in dotdev, and `.gitignore` implies its source was once meant to live here. Whether that's intentional (external private repo) or a gap is unresolved by the packs.
