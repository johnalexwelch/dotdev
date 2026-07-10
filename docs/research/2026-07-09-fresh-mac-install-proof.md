# Fresh-Mac reproducible-install — how we prove a clean install across pi/claude/codex

Research asset for [ticket #73](https://github.com/johnalexwelch/dotdev/issues/73) (map [#68](https://github.com/johnalexwelch/dotdev/issues/68)). 2026-07-09.

## Question

How do we **prove** dotdev installs clean on a fresh Mac across pi/claude/codex? The macOS path is effectively broken today (FIND-11–19, FIND-29). Decide the verification approach; the known fixes then route to design-plan→execute-phase once we know how we test them.

## Key finding: today's CI runs `install.sh` but proves almost nothing

`ci.yml` already has `stow-dry-run`, `install-dry-run` (`DRY_RUN=1`), `shell-syntax` (`bash -n`), `secrets`, and `lint`. But **every side effect in `install.sh`/`ai-setup.sh` routes through `run_cmd`, which under `DRY_RUN=1` only `echo`s "Would execute: …" and returns 0.** So the dry-run job:

- never sources `terminal.sh` → misses FIND-11 (crash on unset `DOTFILES`).
- never runs `stow` for real → misses FIND-12 (nonexistent target path).
- never hits `github.sh` logic → misses FIND-16/17 (missing SSH alias, non-idempotent key re-add).
- never re-runs → misses idempotency breaks entirely.

Dry-run is a **preview of intended commands, not a proof the install works** ([shellcheck/bats CI practice](https://dev.co/idempotent-bash-deployment-scripts-shellcheck), [bats-core](https://github.com/bats-core/bats-core)). This is the trap: green CI, broken install.

## Why the "obvious" options don't fit

| Option | Verdict | Why |
|---|---|---|
| VM / container mac-ish harness | **No** | You cannot run macOS in a Linux container, and licensing/tooling for nested macOS VMs is not worth it for a solo repo. GitHub already gives fresh macOS runners. |
| One big `install.sh` run on a macOS runner | **No, as-is** | The script hard-codes `$HOME/dotdev`, calls `sudo` (`scutil`, `/etc/shells`, `chsh`), clones private repos over `github-personal` SSH, and installs the whole Brewfile — none safe/available in CI. Running it whole is how it stays untested. |
| Fresh macOS runner + **runnable core** + idempotency re-run | **Yes** | GitHub says each job is a fresh runner instance ([docs](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)) — "new machine" enough. The lever is making the *portable core* actually executable in a sandbox `HOME`. |

## Decision: prove reachable + idempotent for the portable core; smoke-test the rest

"Clean install" is two claims, mirroring the #70 split (reachable vs invoked):

| Claim | Meaning | CI-deterministic? | How |
|---|---|---|---|
| **Portable-core applies** | Stow + config-init + dotfile-only steps run for real against a sandbox `HOME` and succeed. | **Yes** | real run on `macos-15` runner, `HOME=$RUNNER_TEMP/fakehome` |
| **Idempotent** | Running the core **twice** converges — no crash, no dupes, symlinks still correct. | **Yes** | run core twice, assert second run exits 0 and symlinks/`/etc/shells`-style appends are unchanged |
| **Sudo/network/GUI steps** | brew bundle, `chsh`, `scutil`, private-repo clones, `pi install`. | **No** (need creds/sudo/GUI) | keep as `DRY_RUN` echo *plus* `bash -n` + `brew bundle --file … list`-style static checks |

### The one enabling change (routes to design-plan→execute-phase)

Split `install.sh` into **`install_core` (portable, HOME-relocatable, no sudo/network)** and **`install_machine` (sudo/network/GUI)**, gated so CI runs the core for real. Concretely:

1. **`export DOTFILES`** from `install.sh` and make it `${DOTFILES:-$HOME/dotdev}` so a sandbox HOME works (fixes FIND-11 root cause; unblocks CI sourcing `terminal.sh`).
2. **Correct the stow target path** to `dotfiles/.config` (FIND-12) — caught the moment stow runs for real.
3. Make key-add/SSH-alias/`/etc/shells`/`chsh` steps **guard-before-act** (`grep -q`, `[ -L ]`, `command -v`) so a second run is a no-op (FIND-16/17) — the idempotency re-run asserts this.
4. Every mutation uses **ensure-style guards** (`ensure_symlink`, `ensure_line`, `ensure_dir`) so dry-run *and* re-run are both meaningful ([pattern](https://dev.co/idempotent-bash-deployment-scripts-shellcheck)).

### The recommended check (Layer, CI-runnable, deterministic)

A `test/install-core.bats` (bats is the standard bash test framework; `brew install bats-core` on the runner) driving a new `install-core` job on `macos-15`:

```bash
@test "core install applies clean into sandbox HOME" {
  run env HOME="$SANDBOX" DOTFILES="$SANDBOX/dotdev" bash install.sh --core-only
  [ "$status" -eq 0 ]
  [ -L "$SANDBOX/.claude/skills" ] || [ -d "$SANDBOX/.claude/skills" ]   # stow ran
  [ -L "$SANDBOX/.zshrc" ] || true                                        # per FIND-13 resolution
}

@test "core install is idempotent" {
  run env HOME="$SANDBOX" DOTFILES="$SANDBOX/dotdev" bash install.sh --core-only
  [ "$status" -eq 0 ]                                                     # second run: no crash
  refute_duplicate_lines "$SANDBOX/.zshrc"                                # no double-append
}
```

Plus the existing `stow-dry-run` + `shell-syntax` jobs stay (cheap, catch parse/DSL breaks incl. FIND-18). Add **`brew bundle list --file Brewfile`** (parses the Brewfile without installing) to catch FIND-18's non-DSL stanzas deterministically.

### Per-harness proof (pi/claude/codex)

Install-proof is mostly harness-agnostic (all three are stowed dotfiles + a clone/package step). The harness-specific reachable checks are **already owned by #70's static wiring audit** — don't duplicate them here:

- **claude** — stow lands `~/.claude/{skills,hooks}`, `settings.json`, `settings.local.json` from template. Core install verifies the symlinks resolve; #70 audit verifies skills/hooks are registered.
- **pi** — `pi install` per `settings.json` packages. Network+auth, so **DRY_RUN echo in the core job**; #70 audit asserts the package list is present/valid offline.
- **codex** — `sync-codex-skills.sh`; #70 already made codex = "sync dry-run clean" (runtime deferred, no trace sink). Nothing new here.

### FIND-29 (CI Lint red on detect-secrets false positives)

Separate, small, and **blocks seeing any of the above go green**, so fix it in the same route: baseline-align `detect-secrets`/gitleaks (the leaked key is already erased per #69) so `pre-commit run --all-files` passes. Fold into the execute-phase batch, not a new ticket.

## Handoff

Route: **`/design-plan` → `/execute-phase`** (infra/scripts — matches map Notes). The design-plan batch is:
`export/guard DOTFILES` + `install-core`/`install-machine` split (FIND-11) · stow path fix (FIND-12) · oh-my-zsh doc/script reconcile (FIND-13) · double-run fix (FIND-14) · SSH alias + idempotent key-add (FIND-16/17) · Brewfile DSL (FIND-18) · mcp path portability (FIND-19) · `test/install-core.bats` + `install-core` CI job + `brew bundle list` + FIND-29 lint fix.

Verification method decided; the fixes are now testable. No new frontier decision remains here — it's execution.
