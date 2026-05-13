# Onboarding Audit — `/Users/alexwelch/.claude/skills/`

**Date:** 2026-04-21  
**Investigator:** Explore agent (Onboarding specialist)  
**Scope:** Entry point, documentation, prerequisites, time-to-first-run for a new contributor cloning `~/.claude/skills/` tomorrow

---

## Summary

A new contributor cloning this skills directory **without prior context** would struggle significantly. The directory has **no README, no CONTRIBUTING guide, and no entry-point map**. The two design plan files (`2026-04-21-skills-updates-design.md` and `2026-04-22-design-plan-brief-mode.md`) are shipped artifacts describing *what was built*, not *how to use it*. They document the 4-skill core loop (`/repo-audit → /design-plan → /execute-phase → /describe-pr → /post-mortem`) and the `/setup-worktree` side-car, but assume the reader has already mentally compiled the skill interaction model.

**Realistic time-to-first-run estimate:** **45–75 minutes** from `git clone` to successfully running `/repo-audit` on a test repo (assuming no Python/git dependency surprises).

**Blocker categories:**

1. **Undocumented entry point** — no guidance on "start here" or "what is the core workflow"
2. **Implicit skill prerequisites** — `/design-plan` requires a prior `/repo-audit` run (or brief-mode input); `/execute-phase` requires a plan; skills are assumed auto-discovered in Claude Code
3. **Unwritten norms** — `~/.claude/skills/` as a global directory auto-loaded by Claude Code; `docs/audits/`, `docs/plans/`, `docs/executions/` conventions live only in skill file `reads:` blocks
4. **Machine-local state** — git identity required for commits (caught us mid-execution when `/execute-phase` tried to commit); Python 3 + pyyaml for the strict-YAML Definition of Done check; worktree path default `~/wt/<repo>/phase-<N>/` not explained upfront
5. **Load-bearing hardcoded defaults** — `/execute-phase` defaults `plan_path=""` → find newest `docs/plans/*.md`; `/setup-worktree` defaults `path="~/wt/<repo>/phase-<N>/"` with no explanation of the `~` and `/wt/` convention upfront

---

## Findings

### Finding 1: No readme or entry-point documentation at repository root

**Evidence:** The root directory of `~/.claude/skills/` contains:

```
├── .git/
├── .gitignore
├── .omc/
├── 2026-04-21-skills-updates-design.md          ← design plan, not entry guide
├── 2026-04-22-design-plan-brief-mode.md         ← follow-up design plan
├── ci-deploy-fix/
├── describe-pr/
├── design-plan/
├── docs/
├── execute-phase/
├── new-project/
├── omc-reference/
├── post-mortem/
├── repo-audit/
├── setup-worktree/
├── slack-update/
├── td-task-management/
└── write-to-obsidian/
```

**No README.md, CONTRIBUTING.md, GETTING_STARTED.md, or quick-reference.**

A new contributor sees 15 directories with opaque names and two design documents dated 2026-04-21/22 — both explaining the *history of the refactoring* that built this, not *how to use the skills once built*.

**Impact:** 5–10 minutes lost trying to understand what `repo-audit`, `design-plan`, `execute-phase` are, and which one to run first.

---

### Finding 2: The core 4-skill loop is documented *only* in the plan files and within skill `SKILL.md` pairing diagrams

**Evidence:**

In `/Users/alexwelch/.claude/skills/2026-04-21-skills-updates-design.md` (line 8):

> The end state is a four-skill core loop — `/repo-audit → /design-plan → /execute-phase → /describe-pr → /post-mortem`

This is described as the **shipped result** of that design plan's Phase 5 (integration dogfood), not as "here's how to use the directory."

Each individual skill's `SKILL.md` file includes a pairing diagram at the bottom — but a new contributor must:

1. Pick one skill (which one?)
2. Read its full SKILL.md to find the diagram (typically 200+ lines)
3. Infer the loop from the diagram
4. Go back and read the other skills to understand the full chain

**Impact:** 10–15 minutes of reading to discover the shape of the loop.

---

### Finding 3: `/design-plan` implicitly requires `/repo-audit` output

**Evidence:**

In `/Users/alexwelch/.claude/skills/design-plan/SKILL.md`:

```yaml
inputs:
  - name: audit_path
    type: string
    default: ""
    description: Path to a repo-audit report. If empty, use the newest file matching `docs/audits/*-repo-audit.md`.
```

Step 0 (Preflight) says:

> Otherwise, find the newest `docs/audits/*-repo-audit.md`. If none exists, stop and tell the user to run `/repo-audit` first.

**Unwritten norm:** When a new user invokes `/design-plan` without an audit, the skill will *prompt* them to run `/repo-audit` first. This is discovered by trial, not upfront guidance.

The `2026-04-22-design-plan-brief-mode.md` plan adds a brief-mode input (`brief="..."`) to support bug/feature-scale work without an audit — but this is documented in the plan file, not in the skill directory's entry documentation.

**Impact:** 5 minutes of trial-and-error or reading the design plan to discover brief-mode.

---

### Finding 4: Unwritten norm: `~/.claude/skills/` is a global directory auto-loaded by Claude Code

**Evidence:**

The directory is at a well-known path (`~/.claude/skills/`), which Claude Code's harness auto-discovers and loads. From `/Users/alexwelch/.claude/skills/design-plan/SKILL.md`:

```yaml
triggers:
  - "write a design doc"
  - "create a refactor plan"
  - "/design-plan"
```

The `/design-plan` trigger (and similarly `/repo-audit`, `/execute-phase`, etc.) work because Claude Code's harness:

1. Scans `~/.claude/skills/` at startup
2. Reads each `SKILL.md` frontmatter
3. Registers the `triggers` as commands

**This is not documented in the skills directory itself.** A new contributor might assume the skills must be explicitly installed, invoked via a CLI, or require environment setup.

**Impact:** 2–3 minutes of confusion before discovering the skills "just work" in Claude Code's chat.

---

### Finding 5: Hardcoded default paths with no upfront explanation

**Evidence:**

In `/Users/alexwelch/.claude/skills/setup-worktree/SKILL.md` (line 65):

> `path = ~/wt/<repo-dirname>/phase-<N>/` where `<repo-dirname>` is `basename $(git rev-parse --show-toplevel)`.

In `/Users/alexwelch/.claude/skills/execute-phase/SKILL.md` (line 41, implicit via the `writes:` block):

> writes:
>
> - docs/executions/.phase-runs/<date>[-<plan-slug>]-phase-<N>.md
> - new git branch `refactor/phase-<N>-<slug>` (off current HEAD)

The convention that worktrees live under `~/wt/` is documented in the `setup-worktree` SKILL.md, but not announced upfront. A user who hasn't read that skill has no warning they'll spawn directories under `~/wt/`.

Similarly, the `docs/audits/`, `docs/plans/`, `docs/executions/` directory structure is *implicit* in each skill's `reads:`/`writes:` blocks — not stated as "this is the directory convention" upfront.

**Impact:** 5 minutes of "where did that worktree directory go" or "where do I find the generated plan file".

---

### Finding 6: Machine-local state dependencies (git identity, Python 3, pyyaml)

**Evidence:**

From the phase-0 outcome file (`/Users/alexwelch/.claude/skills/docs/executions/.phase-runs/2026-04-21-phase-0.md`):

> Two of three fail strict PyYAML ... Strict-parse becomes a Phase 4 acceptance criterion

And from `2026-04-21-skills-updates-design.md` (line 286):

> No `SKILL.md` file fails YAML parse. Verified by running `python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]).read().split('---')[1])" <file>` on each.

This means:

1. **Git identity required** — `/execute-phase` creates commits; if `git config user.email` and `git config user.name` are not set, commits will fail.
2. **Python 3 + pyyaml required** — The Definition of Done in `2026-04-21-skills-updates-design.md` validates all SKILL.md files via strict YAML parsing. This is *not* a runtime dependency of the skills (they don't call Python), but it's a *verification dependency* if you want to check whether the repo is in good shape.

Neither is documented in the directory. A new contributor might assume the skills work with just Claude Code and git.

**Impact:** 5–10 minutes of "why did the commit fail" or "how do I verify the setup".

---

### Finding 7: The two design-plan files are shipped *results*, not entry documentation

**Evidence:**

`2026-04-21-skills-updates-design.md` begins:

> This plan updates three global skills under `~/.claude/skills/` ... Uses a lightweight `GAP-NN` ID scheme — no `/repo-audit` was run, because this is skill authoring, not a repo refactor.

and concludes:

> **Shipped state.** This plan was executed; see a separate design doc for subsequent brief-mode work (GAP-06).

These are records of *what was built*, not *how to use it*. A new contributor reading them will understand the history but still lack a "start here" guide.

**Impact:** 15–20 minutes of reading two long design documents before reaching a "this is what you can do with these skills" understanding.

---

### Finding 8: No quick-reference or skill matrix

**Evidence:**

No skill comparison table. No list like:

```
| Skill         | Input                | Output              | Use when...                  |
|---------------|----------------------|---------------------|------------------------------|
| /repo-audit   | repo path (optional) | docs/audits/*.md    | You want a state-of-repo     |
| /design-plan  | audit or brief       | docs/plans/*.md     | You have findings to plan    |
| /execute-phase| plan, phase number   | docs/executions/.   | You're ready to implement    |
| /describe-pr  | PR / plan            | PR body text        | You want a summary of changes|
| /post-mortem  | plan + git history   | docs/executions/*.md| You want to review what happened |
| /setup-worktree| plan + phase        | ~/wt/<repo>/<path>/ | You want isolated checkout  |
```

Each skill's `SKILL.md` is self-contained (~200–300 lines), so understanding the *adjacency* of skills requires reading multiple files.

**Impact:** 10–15 minutes of document navigation to build a mental model.

---

### Finding 9: Skill discovery and registration is implicit in Claude Code

**Evidence:**

The skills are available as `/repo-audit`, `/design-plan`, etc., in Claude Code's chat interface *because* Claude Code's harness scans `~/.claude/skills/` and reads YAML frontmatter.

This is **not documented in the skills directory itself**. A new contributor might assume they need to:

- Install the skills via a package manager
- Run a setup script
- Configure environment variables
- Register them in a config file

**Impact:** 2–3 minutes of attempting to "activate" or "install" skills before discovering they're already available.

---

## Evidence

### File structure (root and subdirectories)

```
/Users/alexwelch/.claude/skills/
├── repo-audit/SKILL.md                   (307 lines, covers 13 discovery agents)
├── design-plan/SKILL.md                  (420+ lines, draft + revise modes)
├── execute-phase/SKILL.md                (250+ lines, phase dispatch + verify)
├── describe-pr/SKILL.md                  (260+ lines, PR summary generation)
├── setup-worktree/SKILL.md               (200+ lines, worktree setup)
├── post-mortem/SKILL.md                  (280+ lines, execution retro)
├── 2026-04-21-skills-updates-design.md   (322 lines, plan that built the loop)
├── 2026-04-22-design-plan-brief-mode.md  (196 lines, follow-up: brief-mode input)
├── docs/executions/.phase-runs/          (6 phase outcome files from dogfood)
├── docs/audits/.fact-packs-2026-04-21/   (1 partial audit pack)
├── ci-deploy-fix/SKILL.md                (unrelated to core loop)
├── slack-update/SKILL.md                 (unrelated)
├── td-task-management/SKILL.md           (unrelated)
├── write-to-obsidian/SKILL.md            (unrelated)
└── other skills                          (5+ others, not part of core loop)
```

### Key excerpts confirming findings

**From `/repo-audit/SKILL.md` (line 10):**

```yaml
persona: Staff Engineer running a structured codebase audit
```

**From `/design-plan/SKILL.md` (lines 58–65):**

```markdown
- **draft**: locate the audit. If `audit_path` is set, use it.
  Otherwise, find the newest `docs/audits/*-repo-audit.md`. If none
  exists, stop and tell the user to run `/repo-audit` first.
```

**From `setup-worktree/SKILL.md` (lines 14, 26, 65):**

```yaml
description: Path to the design plan. If set with `phase`, derives the branch name from the plan's §5.<N> header and the worktree path from `~/wt/<repo>/phase-<N>/`.
```

**From `2026-04-21-skills-updates-design.md` (§0, line 8):**

```markdown
The end state is a four-skill core loop — `/repo-audit → /design-plan → /execute-phase → /describe-pr → /post-mortem` — plus `/setup-worktree` as an on-demand side-car.
```

---

## Open questions

1. **Why are the design plan files at the root level?** They're shipped artifacts documenting what was built. Should they be moved to `docs/` for clarity that they're historical records, not entry guides?

2. **Is Python 3 + pyyaml truly required for normal use?** The Definition of Done mentions strict YAML validation, but the skills themselves don't invoke Python. Is this a dev/maintenance requirement only?

3. **Should worktree path convention be announced in a README, or is it discoverable enough via `/setup-worktree` help text?**

4. **Who is the target audience for git clone?** Assume "someone already using Claude Code" (no Claude Code install step needed) or "a completely fresh user"? If the latter, a Claude Code setup guide is load-bearing.

5. **Should the 4-skill loop be visualized as ASCII art in a README**, given how central it is to understanding the directory?

---

## Recommended next steps (not in scope of this audit, but load-bearing for onboarding)

1. **Create `README.md` at repository root** with:
   - One-paragraph purpose ("personal skill library for audit → plan → execute → retro workflow")
   - ASCII diagram of the 4-skill core loop + side-car
   - "Start here" pointer: "Clone this, then in any repo, run `/repo-audit`"
   - Quick reference table (Skill | Input | Output | When to use)
   - Link to the two design plan files as background reading (not entry docs)

2. **Create `docs/CONVENTIONS.md`** (or inline in README):
   - `~/.claude/skills/` as auto-loaded global directory
   - `docs/audits/`, `docs/plans/`, `docs/executions/` convention per target repo
   - `~/wt/<repo>/phase-<N>/` default worktree path
   - Git identity requirement
   - Optional: Python 3 + pyyaml for strict YAML validation

3. **Consider renaming or relocating the design plan files** to `docs/design-history/` to clarify they're shipped artifacts, not setup guides.

4. **Add a "Troubleshooting" section** to the README covering:
   - "Skills not showing up in Claude Code chat" → Check `~/.claude/skills/` directory, reload Claude Code
   - "Git commit failed" → Ensure `git config user.email` and `git config user.name` are set
   - "Worktree path defaulted to `~/wt/`" → This is intentional; see CONVENTIONS

---

## Realistic time estimate breakdown

**From `git clone ~/.claude/skills` to running `/repo-audit` on a test repo:**

| Step | Activity | Time | Blocker |
|------|----------|------|---------|
| 1 | Clone directory, explore root structure | 2 min | None |
| 2 | Realize no README, read design-plan files to understand loop | 15 min | Finding 2, 7 |
| 3 | Discover `/repo-audit` is the entry point (or trial-run skills) | 5 min | Finding 1 |
| 4 | Navigate to a test repo, ensure git identity set | 3 min | Finding 6 |
| 5 | Run `/repo-audit` | 2 min | None |
| 6 | Verify audit output lands in `docs/audits/` | 3 min | Finding 5, 8 |
| **Total** | | **30 min** | |

**If the contributor also runs the full 4-skill loop (audit → plan → execute):**

| Step | Activity | Time | Blocker |
|------|----------|------|---------|
| 1–6 | Above (audit) | 30 min | Finding 1, 2, 6 |
| 7 | Run `/design-plan` (choose outcome, constraints) | 5 min | Finding 3 |
| 8 | Read generated plan, pick Phase 1 | 5 min | Finding 2, 8 |
| 9 | Run `/execute-phase phase=1` | 5 min | Finding 9 |
| 10 | Verify phase branch created, commit made | 3 min | Finding 5 |
| **Total** | | **53 min** | |

**Additional time if not discovered upfront:**

- Searching for "where did my plan file go" (Finding 5, 8): +5 min
- Trying to understand worktree defaults (Finding 5): +3 min
- Reading design-plan files thoroughly (Finding 7): +15 min
- Attempting skill "setup" or "installation" (Finding 9): +3 min

**Realistic worst-case: 75 minutes** (if all blockers are encountered and none are discovered upfront).

---
