# dotdev Audit — 2026-07-02

## Overall State

Repo is in good shape after the previous session's 10 fixes. Remaining findings are low-to-medium severity — two are minutes-long fixes (executable bits, npm audit), one is a real portability gap (hardcoded paths in settings.json hooks), and one configuration mismatch (pi-fork routes to openrouter which is unconfigured).

## Findings Summary

| ID | Severity | Area | Title | Effort |
|----|----------|------|-------|--------|
| FIND-01 | medium | hooks | SessionStart hooks hardcode `/Users/alexwelch` | minutes |
| FIND-02 | medium | pi | pi-fork all efforts use openrouter (unconfigured) | minutes |
| FIND-03 | low | guardian | npm audit: 2 vulns in esbuild (1 low, 1 moderate) | minutes |
| FIND-04 | low | guardian | run.sh uses `npx tsx` JIT — dist/ compiled but unused | 1h |
| FIND-05 | low | scripts | arc.sh + security-init.sh not executable (644) | minutes |
| FIND-06 | low | scripts | tmux-session-switch.sh undocumented | minutes |
| FIND-07 | low | cron | First granola sync job missing comment label | minutes |
| FIND-08 | info | scripts | shellcheck info-level warnings (SC2012, SC2016, SC2162) | 1h |

## Top 3 Findings

### FIND-01 — SessionStart hooks hardcode `/Users/alexwelch`

Two commands in `settings.json → hooks.SessionStart` contain literal `/Users/alexwelch/` paths rather than `$HOME`. On any fresh machine with a different username the hooks silently fail — herdr agent state won't be reported and the remember-plugin journey hook won't be installed. Since `settings.json` is stowed from dotfiles and shared across machines (or future reinstalls), this is a real portability gap. Fix: replace hardcoded prefix with `$HOME`.

### FIND-02 — pi-fork all effort levels route to openrouter (unconfigured)

`settings.json → pi-fork.efforts` maps fast/balanced/deep to `provider: openrouter` models. Pi's `defaultProvider` is `anthropic`; openrouter has no API key configured. Every call to the `fork` tool will fail with an auth error. Fix: remap efforts to the anthropic provider, e.g. `claude-sonnet-4-6` for balanced, `claude-opus-4-5` for deep.

### FIND-03 — guardian esbuild vulns

`npm audit` inside `~/.claude/guardian` reports 2 vulnerabilities in `esbuild` (1 low severity path-traversal info-leak, 1 moderate arbitrary file-read on Windows dev server). The Windows-only moderate vuln has near-zero runtime exposure on macOS, but `npm audit fix` resolves both without breaking changes. Should be kept clean.

## Detailed Findings

### FIND-01 — SessionStart hooks hardcode `/Users/alexwelch`

**Severity:** medium | **Effort:** minutes | **Area:** hooks / dotfiles portability  
**Evidence:** `settings.json` SessionStart hooks (2 entries):

```
"bash '/Users/alexwelch/.claude/hooks/herdr-agent-state.sh' session"
"for d in /Users/alexwelch/.claude/plugins/cache/..."
```

**Impact:** On a fresh machine or if username changes, both hooks fail silently — herdr agent-state reporting broken, remember-plugin journey hook not installed.  
**Fix:** Replace `/Users/alexwelch/` with `$HOME/` in both commands. Single `sed` edit to `dotfiles/.claude/settings.json`.

---

### FIND-02 — pi-fork efforts route to unconfigured openrouter

**Severity:** medium | **Effort:** minutes | **Area:** pi config  
**Evidence:** `dotfiles/.pi/agent/settings.json` → `pi-fork.efforts.*` all have `"provider": "openrouter"`. Pi `defaultProvider` is `anthropic`. No openrouter key configured.  
**Impact:** `fork` tool fails for every effort level (fast/balanced/deep) with auth error.  
**Fix:** Update `pi-fork.efforts` to use anthropic provider and appropriate model IDs:

```json
"pi-fork": {
  "defaultEffort": "balanced",
  "efforts": {
    "fast":     { "provider": "anthropic", "id": "claude-haiku-4-5" },
    "balanced": { "provider": "anthropic", "id": "claude-sonnet-4-6" },
    "deep":     { "provider": "anthropic", "id": "claude-opus-4-5" }
  }
}
```

---

### FIND-03 — guardian npm: 2 esbuild vulns

**Severity:** low | **Effort:** minutes | **Area:** guardian / deps  
**Evidence:** `cd ~/.claude/guardian && npm audit` — "2 vulnerabilities (1 low, 1 moderate)". Both in `esbuild ≤ 0.28.0`. Moderate = arbitrary file read in Windows dev server (GHSA-g7r4-m6w7-qqqr). Not exploitable on macOS in this usage.  
**Impact:** Low runtime risk; dependency hygiene / Dependabot noise.  
**Fix:** `cd ~/.claude/guardian && npm audit fix` — resolves both without major version bumps.

---

### FIND-04 — guardian run.sh uses npx tsx (JIT); dist/ compiled but unused

**Severity:** low | **Effort:** 1h | **Area:** guardian / performance  
**Evidence:** `~/.claude/guardian/run.sh`: `exec npx tsx cli.ts`. PostToolUse hook compiles to `dist/` on every .ts edit but `dist/cli.js` is never executed.  
**Impact:** `npx tsx` adds ~100-300ms JIT overhead on every Bash PreToolUse call. The PostToolUse recompile hook is wasted work.  
**Fix:** Change `run.sh` to `exec node --input-type=module < dist/cli.js` (or `exec node dist/cli.js` if it's CJS). Keep the PostToolUse recompile hook — it would then serve its intended purpose. Alternatively: accept the tsx overhead, it's fast enough.  
`ponytail: tsx latency is acceptable on modern hardware; only switch if profiling shows real impact.`

---

### FIND-05 — arc.sh + security-init.sh not executable

**Severity:** low | **Effort:** minutes | **Area:** scripts  
**Evidence:** `ls -la scripts/` → `644 arc.sh`, `644 security-init.sh`. All other scripts are `755`.  
**Impact:** `./scripts/arc.sh backup` fails with "Permission denied". Must use `bash scripts/arc.sh` instead.  
**Fix:** `chmod +x ~/dotdev/scripts/arc.sh ~/dotdev/scripts/security-init.sh`

---

### FIND-06 — tmux-session-switch.sh undocumented

**Severity:** low | **Effort:** minutes | **Area:** docs  
**Evidence:** `scripts/tmux-session-switch.sh` (191B) — fzf-based tmux session switcher. Not listed in README Standalone Scripts section added in previous session.  
**Impact:** Muscle memory loss; not discoverable.  
**Fix:** Add to README Standalone Scripts table.

---

### FIND-07 — First granola sync cron job missing comment

**Severity:** low | **Effort:** minutes | **Area:** cron / ops  
**Evidence:** `crontab -l` — jobs at 7:45, 7:50, 8:30 all have `# gbrain — X (daily Y)` comment. The 8:00am granola job has none.  
**Impact:** Cosmetic; harder to read crontab.  
**Fix:** Add `# gbrain — Granola + Meeting sync (daily 8am)` before the first cron line.

---

### FIND-08 — shellcheck info-level warnings

**Severity:** info | **Effort:** 1h | **Area:** scripts / code quality  
**Evidence:** `shellcheck scripts/*.sh` reports:

- `arc.sh:48` SC2012 — `ls` in command substitution (use `find`)
- `brew.sh:13` SC2016 — expression in single quotes (intentional — printing literal eval)
- `github.sh:18` SC2162 — `read` without `-r` (backslash handling)  
**Impact:** None in practice; brew.sh SC2016 is intentional.  
**Fix:** `github.sh`: add `-r` to `read`. `arc.sh`: replace `ls` with `find`. `brew.sh`: suppress with `# shellcheck disable=SC2016` (intentional single-quote).

---

## Already Fixed (Previous Session)

- **gbrain MCP** moved from `settings.json` → `settings.local.template.json`; `ai-setup.sh` always clones gbrain-repo
- **guardian fail-closed**: `main().catch` now calls `outputDeny` instead of `{}`
- **guardian TypeScript**: `rules.ts:141` non-null assertions for `noUncheckedIndexedAccess`
- **pi skills path**: `~/.claude/skills` (stow target) instead of `~/dotdev/dotfiles/.claude/skills`
- **pi install loop**: process substitution + failure tracking array
- **cron log rotation**: 9am daily job caps `~/.gbrain/*.log` at 512KB
- **setup.sh**: thin `exec install.sh` wrapper; diverging duplicate removed
- **tmux-dev.sh**: deleted (replaced by hdev.sh)
- **README**: Standalone Scripts section added

---

## Recommended Next Steps

1. **FIND-01** — Fix hardcoded paths in SessionStart hooks (minutes, portability)
2. **FIND-02** — Remap pi-fork efforts to anthropic provider (minutes, fork tool broken)
3. **FIND-03** — `npm audit fix` in guardian (minutes, dep hygiene)
4. **FIND-05** — `chmod +x` arc.sh + security-init.sh (minutes)
5. **FIND-06/07** — Add tmux-session-switch to README; add cron comment (minutes)
