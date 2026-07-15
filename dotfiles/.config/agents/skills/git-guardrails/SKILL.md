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
