---
name: git-guardrails
model: haiku
reasoning: medium
description: Set up a Claude Code PreToolUse hook that blocks dangerous git commands (force-push, reset --hard, clean -f, branch -D, checkout/restore .) before they execute. Use when the user wants to prevent destructive git operations, add git safety hooks, or block git push/reset in Claude Code.
---

## Contract

Consumes: user's choice of scope (this project vs. all projects), any existing `.claude/settings.json` / `~/.claude/settings.json`
Produces: installed hook script (`block-dangerous-git.sh`) under `.claude/hooks/` or `~/.claude/hooks/`; a `PreToolUse` hook entry wired into the matching settings file
Requires: bash, jq
Side effects: writes/overwrites a script file on disk; edits `.claude/settings.json` or `~/.claude/settings.json` in place
Human gates: scope choice (project-only vs. global) before writing anything; confirm the blocked-pattern list before finalizing if the user wants customization

## Context

Typical workflows: standalone (repo or machine safety setup, usually run once)
Pairs well with: setup-skills

# Git Guardrails

Sets up a `PreToolUse` hook that intercepts and blocks dangerous git commands before Claude executes them.

## What gets blocked

- `git push` (all variants, including `--force`)
- `git reset --hard`
- `git clean -f` / `git clean -fd`
- `git branch -D`
- `git checkout .` / `git restore .`

When blocked, Claude sees a message on stderr telling it that it does not have authority to run the command — the tool call itself never executes.

## Agent conduct: stash & branch safety (not hook-enforced)

The hook can't safely block `git stash pop` or `checkout` (both are routinely legitimate), so these are **behavioral rules the agent must follow** — they prevent the most common non-destructive-but-corrupting mistakes:

- **Before `git stash`, run `git status --short`. If the tree is clean, do NOT stash** — `git stash`/`git stash -u` on a clean tree saves nothing and silently leaves the *previous* `stash@{0}` on top. A later `git stash pop` then applies a **foreign stash you didn't create**.
- **Never `git stash pop`/`apply` a positional `stash@{0}` you didn't just create.** Use named stashes (`git stash push -m "<msg>"`) and pop by inspecting `git stash list` first. If a pop conflicts or the diff surprises you, **verify the stash's provenance** (`git stash show -p stash@{N}`, what branch/tree it's based on) before "resolving" it — don't check foreign content into tracked files.
- **Prefer reading across refs over checkout for inspection/integration.** `git show <ref>:<path>` and `git diff A..B -- <path>` answer "what's different" without touching the working tree. A branch checkout in a dirty or ambiguous worktree is where things go wrong.
- **A surprising `git diff <ref>` is a signal, not noise.** If a stash/branch diff is far larger than your change, the ref is likely based on a different branch state — stop and confirm provenance before acting.
- **cwd ≠ work repo → pass `--repo` explicitly.** When your cwd is a *different* repo's git worktree than the project you're operating on, `gh` and issue tools resolve against the cwd repo — a bare `gh issue view/close <N>` silently targets the wrong project (observed: an `issue_close` hit the cwd worktree's repo, not the intended one). Always pass `gh ... --repo <owner/slug>` when cwd may differ.
- **Known-concurrent checkout → re-check the tip before committing.** If other agents may be editing the same checkout, `git rev-parse HEAD` before staging and again before commit; a moved tip means your work may be based on a stale tree (observed: a commit was orphaned by a concurrent hard-reset). Reconcile against the new HEAD, and stage only your own files (`git add <explicit paths>`, never `git add .`) so you don't sweep in a concurrent agent's uncommitted changes.
- **Before a follow-up/targeted fix mid-session, confirm the checked-out branch is not behind its merge-target base.** Compare `git log --oneline -1 HEAD` against `git log --oneline -1 origin/<base>` (fetch first). A worktree reused across a multi-branch session silently drifts behind `origin/<base>`; editing the stale copy "works" locally but is missing later merges, so tests collect the wrong set and checkers throw errors that don't match the visible code (observed: ~10 wasted calls chasing a phantom mypy bug that was just a stale test file). When unsure, re-cut a fresh branch from `origin/<base>` rather than trusting whatever is checked out.
- **An internally-inconsistent static-analysis result means "check the input," not "debug the tool."** If a type-checker/linter/test result contradicts the visible code (fewer tests collected than expected, an error that shouldn't apply), `git diff origin/<base> -- <path>` the file against its expected upstream version *before* investigating tool internals or building minimal repros. Wrong-file-version is far more likely than a tool bug.

## Steps

### 1. Ask scope

Ask the user: install for **this project only** (`.claude/settings.json`) or **all projects** (`~/.claude/settings.json`)?

### 2. Copy the hook script

The bundled script is at [scripts/block-dangerous-git.sh](scripts/block-dangerous-git.sh).

Copy it to the target location based on scope:

- **Project**: `.claude/hooks/block-dangerous-git.sh`
- **Global**: `~/.claude/hooks/block-dangerous-git.sh`

Make it executable with `chmod +x`.

### 3. Add the hook to settings

Add to the appropriate settings file:

**Project** (`.claude/settings.json`):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-dangerous-git.sh"
          }
        ]
      }
    ]
  }
}
```

**Global** (`~/.claude/settings.json`):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/block-dangerous-git.sh"
          }
        ]
      }
    ]
  }
}
```

If the settings file already exists, merge the hook into the existing `hooks.PreToolUse` array — don't overwrite other settings.

### 4. Ask about customization

Ask if the user wants to add or remove any patterns from the blocked list. Edit the copied script's `DANGEROUS_PATTERNS` array accordingly — don't edit the bundled copy in this skill folder.

### 5. Verify

Run a quick test against the installed copy:

```bash
echo '{"tool_input":{"command":"git push origin main"}}' | <path-to-installed-script>
```

Should exit with code 2 and print a `BLOCKED:` message to stderr. Also test one command that should pass cleanly (e.g. `git status`) to confirm exit code 0.
