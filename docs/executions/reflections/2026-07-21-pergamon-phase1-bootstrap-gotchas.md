# Session Reflection: Pergamon Phase 1 host bootstrap + disk triage + handoff

**Date**: 2026-07-21
**Goal**: Bootstrap a real Apple Silicon Mac mini over SSH (rename, power
config, tooling, scoped sudo, secrets-foundation docs), then triage disk
space and write a Phase 1→2 handoff.

## What Went Well

- Preferred ground truth over a stale proxy: `lens_diagnostics mode=all`
  reported line-length/comment-spacing errors that didn't match the actual
  file on disk and used a different yamllint ruleset than the repo's own
  `.yamllint.yaml`. Rather than chase the cache, fell back to running the
  real `yamllint .` / `shellcheck` / `shfmt` directly, which was clean —
  correct call, the direct tool is authoritative.
- Held a real trust-boundary line under explicit user pressure: asked to
  clear Messages/Photos "as long as backed up to iCloud," verified iCloud
  service enrollment via `MobileMeAccounts.plist`, but declined to actually
  delete either — enrollment isn't proof of 100%-uploaded, and neither has
  a safe partial-clear primitive the way app caches do. Cleared only the
  unambiguous caches and named the in-app alternative instead of guessing.
- Idempotence wasn't just asserted — it was proven against the live host
  (3 consecutive `CHANGES=0` runs), which is what actually surfaced 7 real
  bugs a dry-run/local-only test never would have caught.

## What Went Wrong / Friction

- **Multi-line command flatten bug bit me despite reading the exact warning
  seconds earlier.** The `handoff` skill explicitly says "do NOT use
  multi-line command blocks... run mkdir, cp, and verify as separate
  single-line commands" — then I immediately sent a 3-line command block
  (`install ...\necho ...\n/bin/ls ...`) and the bash tool flattened it,
  making `install` swallow `echo`/`ls` as extra filename args
  ("target directory ... does not exist"). Root cause: skimmed past a
  known, named pitfall instead of treating it as a hard checklist item.
- **Violated the session's own parallel-tool-call rule for a dependent
  pair.** Issued `mkdir -p <dir>` and `cp <file> <dir>/<file>` in the same
  turn as two "independent" calls, when `cp` actually depends on `mkdir`
  completing first. Got a transient "No such type" file error and initially
  misdiagnosed it as a tool bug before realizing it was an ordering race.
- **Buried the one thing the user needed** (a copy-pasteable shell command)
  inside explanatory prose once; user had to ask "what are the command?" to
  get it restated plainly. Minor, but a pattern worth avoiding: when the
  next message is literally "run this," the command should be the first
  and most visually prominent thing, not paragraph 3.
- Several real macOS-specific automation gotchas only surfaced by running
  against the actual host, not discoverable by reading docs first:
  - `ssh -t pergamon 'bash -s' < file` — piping the script via stdin
    consumes the same stdin `ssh -t` needs for the pty, silently degrading
    the "interactive password prompt" path. Fix: scp the script to a real
    remote path, then `ssh -t host 'bash /path/to/script'`.
  - Factory `ComputerName` on this machine used a **curly apostrophe**
    (U+2019, "Alex's Mac mini") — a straight-quote allow-list string
    rejected the real host as "unintended."
  - `systemsetup -get*` subcommands require `sudo` just to **read** state,
    not only to set it (`pmset`/`scutil` don't have this asymmetry). A
    read implemented without `sudo` silently returns empty output rather
    than erroring loudly, so a naive idempotence check reports "always
    needs changing."
  - `disablesleep`/`SleepDisabled` shows up under plain `pmset -g`
    ("System-wide power settings" header), not under `pmset -g custom`
    (which only has the per-power-source profile). Wrong section = false
    idempotence failure.
  - A root-owned mode-440 sudoers file can't be read back by the
    non-root user who installed it via sudo — so a content-diff
    idempotence check for "did I already install my own sudoers file"
    always fails and reinstalls + reprompts for a password every run.
    Existence-check is the correct (if slightly weaker) idempotence
    signal for a file the checking user structurally cannot read.
  - Finder-drag app uninstalls (Steam/Autodesk/BambuStudio) leave
    `~/Library/Application Support/<App>` completely intact — found ~60GB
    of orphaned data this way, 8.2GB of which was just one app's log files.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | "what are the command?" | Command was stated but buried in prose above a longer explanation | none — communication habit, not a skill gap |

(No skill/file was wrong here; this is a self-correction pattern, not a
skill defect — noted for the lesson, not routed to a change.)

## Lessons

1. **A documented pitfall you just read is not automatically a pitfall you
   avoid.** Reading "don't do X" and then doing X in the very next tool
   call means the warning needs to be closer to an enforced checklist than
   prose to skim. Treat explicit tool-quirk warnings in a skill as literal
   pre-flight checks, not context.
2. **"Independent" tool calls in one turn must actually be independent.**
   `mkdir` then `cp` into that directory are sequentially dependent even
   though they're two different commands — batching them broke the
   ordering guarantee. When a later command reads what an earlier one
   wrote, they are not parallel candidates regardless of how the calls are
   split.
3. **Real idempotence bugs only show up against the real target.** All 7
   bootstrap bugs here passed local shellcheck/shfmt/unit-test review; none
   were catchable without actually running the script against the live
   host twice. Local static checks are necessary, not sufficient, for a
   script whose entire claim is "safe to re-run."
4. **A privileged bootstrap script's own idempotence check can be blocked
   by the privilege it just granted itself** (can't read back a root-owned
   440 file as the unprivileged user). Existence-over-diff is the correct
   fallback, with the tradeoff (no drift detection) named explicitly rather
   than silently accepted.

## Proposed Improvements

- [ ] `handoff/SKILL.md` — the multi-line-flatten warning already exists
  but is prose inside a dense paragraph; consider pulling it into its own
  bolded one-line callout immediately before step 5's mkdir/cp/verify
  instructions, e.g. **"CHECK: does your next command contain a literal
  newline separating two commands? If yes, split it before sending."**
  (priority: low — the warning is technically already there; this is about
  making it harder to skim past, not adding new content)
- [ ] `handoff/SKILL.md` — add one explicit sentence to the mkdir/cp
  guidance: "`mkdir` and the following `cp`/`install` are sequentially
  dependent — never issue them as parallel tool calls in the same turn,
  even though the rest of your independent calls that turn can be
  batched." (priority: low — same root cause as above, different failure
  mode: batching instead of flattening)

No skill file was factually wrong or missing for the macOS bootstrap work —
those gotchas are host-specific operational knowledge, not a skill gap in
this session's toolset. Logged here in case a future `macos-remote-bootstrap`
skill is ever proposed, so the gotchas aren't re-discovered from scratch.

## Skill Extraction Candidates

- **Proposed skill**: `macos-remote-bootstrap-gotchas` (reference/checklist,
  not a workflow) · **target**: new skill dir, e.g.
  `~/dotdev/dotfiles/.config/agents/skills/macos-remote-bootstrap-gotchas/`
  · **invocation**: model (auto-surface when writing/idempotence-checking a
  macOS SSH bootstrap script)
  - **Trigger / leading word**: writing or debugging an idempotent bash
    script that runs `scutil`/`pmset`/`systemsetup`/sudoers/Homebrew setup
    over SSH against real macOS hardware.
  - **Inputs**: none — reference knowledge only.
  - **Steps**: N/A (checklist, not a process) — the content itself is the
    "steps": the 6 gotchas listed under "What Went Wrong / Friction" above
    (pty-over-stdin, curly-apostrophe default hostname, `systemsetup` read
    needing sudo, `pmset -g` vs `pmset -g custom` section split, root-owned
    sudoers file unreadable by its own installer, Finder-uninstall leaving
    `Application Support` orphans).
  - **Success criteria**: a bootstrap script author checks each item before
    claiming idempotence, instead of discovering each one by a failed live
    run.
  - **Constraints / pitfalls**: this is macOS/Apple-Silicon-specific and
    version-dependent (macOS 15.6.1 at time of discovery); some of these
    (`systemsetup` sudo-for-read) may change across macOS versions and
    should be re-verified, not assumed permanent.
  - **Verification evidence**: all 6 items were independently reproduced
    and fixed against a live host this session (`docs/reports/phase-1-
    validation.md` in the `pergamon` repo, "Issues found and fixed"
    section has the exact commands/output for each).
  - **Quality gate**: googleable=No (these are undocumented-elsewhere
    interactions between specific macOS tools, not general knowledge) ·
    specific=Yes (macOS system-command automation specifically) ·
    real-effort=Yes (each was found via an actual failed run against real
    hardware, not from documentation).
  - **Open questions**: is this common enough across future sessions to
    justify a standalone skill, or should it just live as a comment trail
    in the `pergamon` repo's own `docs/reports/phase-1-validation.md` (where
    it already is) since it's tied to one specific host? Leaning toward
    "leave it in the pergamon repo unless a second unrelated macOS-bootstrap
    project comes up" — recommend deferring skill creation until then.
