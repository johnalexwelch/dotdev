# Session Reflection: Multi-repo git branch + worktree audit and cleanup

**Date**: 2026-07-22
**Goal**: Audit and clean up all local git branches and worktrees across the machine (37 repos discovered, hundreds of branches, ~60 worktrees across `wt/`, `.herdr/worktrees/`, `.hermes/`, `dotdev-worktrees/`, `.worktrees/`, `/tmp`, `/private/tmp`).

## What Went Well

- Ran a two-phase audit-then-cleanup: read-only survey first (per-repo `worktree list` / `branch -vv` / `merged` / `status`), presented a categorized report, and only executed after explicit per-item approval. No destructive action was taken blind.
- Used `git branch -d` (not `-D`) as the default-safe bulk-delete primitive — it refuses unless the branch is reachable from HEAD or its upstream, so the "safe pass" (69 deletions) was provably lossless by construction, no manual merge-checking needed per branch.
- Before touching `.herdr/worktrees/*`, queried `herdr workspace list` to see which worktrees were *actually* live (4 of ~60) rather than assuming any worktree under a tool-managed directory was untouchable. This is the authoritative-source check the process asks for — didn't assume "herdr-managed path" == "in use."
- Caught and rm'd a genuinely corrupted worktree (`wt/cora/issue-120`, 0-byte broken `.git`) that git itself couldn't even report on.

## What Went Wrong / Friction

- **Bash tool + inline multi-line control flow**: every `for`/`if` loop written directly as the `bash` tool's `command` string got mangled — errors like `hypa: An error occurred trying to start process 'for'` and `syntax error near unexpected token 'do'`. Some invisible layer (rtk/hypa auto-rewrite) is splitting/reformatting multi-line command strings and breaking shell control-flow keywords. Workaround that worked every time: write the script to a temp file with the `write` tool, then `bash /tmp/foo.sh`. Cost: ~4 failed attempts before landing on the workaround, repeated later in the session too (didn't generalize the lesson to "always script-file it" until after the second failure).
- **Bare `grep` inside the astronomer worktree**: after removing worktrees I ran a raw `grep -E "pattern"` with no path restriction while cwd was `~/dojo/astronomer`. It recursively matched the entire repo including a vendored `dbt_venv/` (binary files, huge CSVs), producing a multi-thousand-line, mostly-noise result and wasting a full tool call. Should have used `git branch -vv | grep ...` (piped from a git command, not the filesystem) from the start — I did that correctly in *most* other places this session, just not this one.
- **Unscoped `find` across `/Users/alexwelch`**: killed (exit 137) on the first attempt because home dir is huge (iCloud, caches, etc). Had to re-scope to known project roots (`projects/`, `dojo/`, `wt/`, etc.) discovered via `ls ~`. Minor, but the instinct should be "narrow to known project roots first" rather than "search everything then narrow."
- **Didn't check for existing dedicated tooling first**: `tool-inventory.md` (which was sitting in the home dir the whole time) lists `git-cleanup@trailofbits` as an *active* installed tool explicitly described as "Dead branches and stale ref cleanup" — exactly this task. Checked afterward: it's a Claude Code plugin (scope: user), not reachable from this pi/codex tool surface, so it likely wouldn't have helped directly — but I never checked *before* hand-rolling ~40 repos' worth of audit scripts, and only discovered the scope mismatch after the fact. The check should happen before building custom tooling, not as a retroactive rationalization.

## Corrections

No explicit user corrections this session — user approved each proposed action rather than redirecting. Findings below come from Pass B (friction/gap hunting on a session that otherwise succeeded).

## Lessons

1. **Script-file first for any bash control flow.** This environment's bash tool reliably breaks inline `for`/`if`/`while` in the `command` string. Default to `write` → `bash <file>.sh` for anything beyond a single pipeline, instead of discovering the breakage each time.
2. **Pipe git metadata from git commands, never grep the working tree.** `git branch -vv`, `git for-each-ref`, `git worktree list` are the ground truth; raw filesystem `grep`/`find` inside a repo risk hitting vendored deps (venvs, node_modules, lockfiles) and drowning the real signal.
3. **Check `~/tool-inventory.md` (and `.sqlite`) before hand-building multi-repo tooling.** It's a local index of exactly this kind of already-solved problem. Even when the hit turns out to be surface-mismatched (Claude Code plugin vs. pi/codex session), knowing that *up front* changes the plan (e.g., flag the gap immediately instead of after finishing the manual version).
4. **`herdr worktree remove` is scoped to open workspaces only** — it can't target an arbitrary closed/orphaned worktree path. For anything not in `herdr workspace list`, plain `git worktree remove` is correct and doesn't fight herdr's bookkeeping. This isn't written down anywhere in the `herdr` skill.

## Proposed Improvements

- [ ] `~/.claude/skills/herdr/SKILL.md` — document the `herdr worktree list/create/open/remove` subcommand family (currently entirely absent from the skill despite existing in `herdr --help`), and explicitly state that `remove` only targets currently-open workspace IDs; closed/orphaned worktrees need plain `git worktree remove`. (priority: med)
- [ ] New skill candidate (see below) — capture the multi-repo branch/worktree audit-and-clean procedure so it isn't re-derived from scratch next time. (priority: med)
- [ ] Durable habit note (`docs/agents/habits.md`) — "check `tool-inventory.md`/`.sqlite` for an existing installed tool before hand-rolling multi-step tooling across many repos" and "prefer `write` + `bash <file>.sh` over inline bash control-flow strings." (priority: low — cheap, high-recurrence fix)

## Skill Extraction Candidates

- **Proposed skill**: `git-worktree-audit` · **target**: `~/dotdev/dotfiles/.config/agents/skills/git-worktree-audit/SKILL.md` · **invocation**: user (explicit request, e.g. "audit/clean up my branches and worktrees")
  - **Trigger / leading word**: "audit branches", "clean up worktrees", "prune stale worktrees"
  - **Inputs**: none required; discovers repos under common project roots (`~/projects`, `~/dojo`, `~/wt`, `~/dotdev`, `~/jarvis`, `~/gbrain-repo`, etc. — read from `ls ~` rather than hardcoded, since the set drifts)
  - **Steps**:
    1. Enumerate real repos (`.git` is a directory) vs worktree links (`.git` is a file) via `find <known roots> -maxdepth 4 -name .git`, scoped — never bare `find ~`.
    2. Per real repo: `git worktree prune -v` (zero-risk — only clears registry entries whose directory is already gone).
    3. Per real repo: for every local branch not currently checked out, attempt `git branch -d` (never `-D` in this automated pass) — safe by construction.
    4. Report remaining `: gone]` branches (upstream deleted) and worktrees still on disk per repo; do NOT auto-force-delete — surface for explicit per-item human approval, since squash-merge/PR-closed states can't be distinguished from truly-abandoned work without checking GitHub.
    5. Before touching any `.herdr/worktrees/*` or other tool-managed worktree dir, cross-check `herdr workspace list` (or equivalent live-session query) — only treat a worktree as orphaned if it's not a currently open workspace/pane.
    6. On approval, force-delete (`-D`) confirmed-gone branches and `git worktree remove --force` confirmed-stale worktrees; re-verify with `git worktree list` / `git branch -vv` after.
  - **Success criteria**: `git worktree prune` clean, no `: gone]` branches without an explicit human sign-off, no worktree directories orphaned from the registry.
  - **Constraints / pitfalls**: bash control-flow must go through a script file, not inline; never bare `grep`/`find` across a repo root (vendored deps); `herdr worktree remove` only works on open workspace IDs.
  - **Verification evidence**: this session — 30 dead worktree registry entries pruned, 69+ branches safely `-d` deleted with zero data loss (git's own merge check enforced it), 9 stale worktrees + their branches force-removed after explicit approval, astronomer worktree count 21→12.
  - **Quality gate**: googleable=No (the safe-delete-via-`-d`-as-filter + herdr-open-workspace-cross-check combo is environment-specific) · specific=Yes (this machine's exact worktree sprawl locations) · real-effort=Yes (multiple failed bash attempts, herdr CLI discovery, one wasted grep)
  - **Open questions**: should the "gone but unmerged" bucket ever be auto-`-D`'d if the associated GitHub PR is confirmed merged via `gh pr view`? Would remove a manual-approval step but adds a network dependency and API-vs-proxy trust question.
