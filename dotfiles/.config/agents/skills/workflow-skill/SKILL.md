---
name: workflow-skill
model: sonnet
reasoning: high
description: 'Implement one skill change end-to-end — author or revise via write-a-skill, gate it through skill-evaluator when the type warrants, then land it on the canonical source and mirror to Codex. Use when building a new skill, revising an existing one, or implementing an approved item from the skill backlog.'
codex-compatible: true
---

# Workflow Skill

The implementation arm for a *single* skill change. `skill-backlog` plans what to build and dispatches here per approved item; a human can also invoke it directly for one-off skill work. It stops at a landed, synced skill — it does not harvest or triage (that is `skill-backlog`).

## When to invoke

- An approved `skill-backlog` item needs building
- "Write a new skill for X", "revise `<skill>`", "fix this skill's description"
- workflow-router classifies work as skill authoring/revision

## Flow

```
Scope the change → Load and run `write-a-skill` → [Load and run `skill-evaluator`]^conditional^ → Land on canonical source + Codex sync → Report
```

## Workflow Progress Reporting

Follow `../_docs/step-ledger.md` (step-ledger protocol): emit the `WORKFLOW_STEPS` ledger before executing or dispatching any step, update it at every status transition, and include the final ledger in every halt, handoff, and completion response.

```markdown
WORKFLOW_STEPS:
| Step | Required? | Status | Evidence / Skip Reason |
|------|-----------|--------|------------------------|
| Step 1: Scope The Change | required | pending | - |
| Step 2: Author/Revise (write-a-skill) | required | pending | - |
| Step 3: Evaluation Gate (skill-evaluator) | conditional | pending | Runs when skill type warrants |
| Step 4: Land + Codex Sync | required | pending | - |
| Step 5: Report | required | pending | - |
```

### Step 1: Scope the change

Establish, from the backlog item or the user:

- New skill or revision of an existing one (revision preserves the existing `name` and directory).
- The specific behavior change and its evidence (a backlog cluster, a correction, a reflection). Carry the evidence forward — it seeds `write-a-skill`'s requirements and `skill-evaluator`'s baseline scenario.

Completion criterion: the target skill path and the concrete change are both named.

### Step 2: Author or revise

Load and run `write-a-skill/SKILL.md` with the scoped requirement. For a new skill it runs the quality gate first; for a revision it skips the gate. Output: the drafted or edited `SKILL.md` (plus `references/`/`scripts/` if needed), not yet committed.

Completion criterion: draft exists and passes `write-a-skill`'s Review checklist.

### Step 3: Evaluation gate (conditional)

Decide by the skill's type — the observable predicate:

- **Discipline/behavior-shaping**, **output-deterministic**, or **model-invoked with trigger doubt** → Load and run `skill-evaluator/SKILL.md`. Act on the verdict: `revise` → loop back to Step 2 with the named gap; `ship` → proceed; `reject` → halt and report.
- **Subjective or trivial** (small wording/reference edit, judgment skill) → skip with reason "type not eval-bearing"; a read of the draft suffices.

Completion criterion: either a `ship` verdict is recorded, or the skip reason is recorded.

### Step 4: Land on canonical source + Codex sync

Respect the Stow + Codex seam:

- Edits target the **canonical source**: `~/dotdev/dotfiles/.config/agents/skills/<name>/SKILL.md`. Never edit the `~/.claude/skills/` runtime mirror. Resolve symlinks (`readlink -f`) before `git add`; do not `git add` through a symlink.
- The git root is `~/dotdev` (dotfiles is a subdir). Commit the path as `dotfiles/.config/agents/skills/<name>/...` from the root, or `cd ~/dotdev/dotfiles` first.
- After the approved edit, mirror to Codex: run `~/dotdev/dotfiles/.config/agents/skills/sync-codex-skills.sh --apply`.
- Verify landing for every runtime that should see the skill: Codex path above, and the Claude runtime link (`~/.claude/skills/<name>` resolves to the canonical source). If the Claude symlink tree is broken, report it — do not pretend the skill is activated.
- If the skill needs MCP or interactive tools, set `codex-compatible: false` in its frontmatter.
- For anything beyond a local skill edit (broad refactor, many files), route the commit through `workflow-review` + `workflow-finalize` instead of a direct commit.

Completion criterion: canonical `SKILL.md` updated, frontmatter parses, Codex mirror synced, Claude runtime verified or breakage reported.

### Step 5: Report

State what changed, the evaluation verdict (or skip reason), the commit, and — when dispatched by `skill-backlog` — the backlog item id to mark `implemented`.

## Contract

Consumes: a scoped skill change (backlog item, user request, or reflection evidence)
Produces: a landed skill edit on the canonical source, Codex-mirrored, with an evaluation verdict or skip reason
Requires: git; `skill-evaluator` (conditional); subagents when the eval gate runs
Side effects: writes/edits skill files under `~/dotdev/dotfiles/.config/agents/skills/`; commits; runs the Codex sync script
Human gates: `write-a-skill` draft review; commit approval per repo convention

## Context

Typical workflows: dispatched per-item by `skill-backlog`; standalone for one-off skill work
Pairs well with: write-a-skill (authoring), skill-evaluator (verdict), skill-backlog (upstream planner), session-insight (upstream producer)
