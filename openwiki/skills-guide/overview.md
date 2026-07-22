# Skills Guide: Overview

The dotdev environment includes ~93 executable skills — Markdown playbooks with YAML frontmatter that define model, reasoning level, and step-by-step procedures.

This guide explains skill categories, how to discover them, how to write new ones, and which clusters are most important.

---

## What Is a Skill?

A skill is a Markdown file with:

```yaml
---
name: skill-name
model: sonnet | opus | haiku
reasoning: high | medium | low
description: 'Single-quoted description'
---

# Skill Name

## Purpose
When and why to use this skill.

## When to invoke
Triggering conditions.

## Process / Steps
Step-by-step playbook.

## Step Ledger (if multi-step)
Table of required/optional steps and status.

## Gate Blocks (if decision-heavy)
Structured evidence records.
```

**Key principle**: Skills are the **single source of truth**. When any prompt, goal, or handoff names a skill, that skill's SKILL.md is loaded and followed, including all required gate blocks. A prose claim that a skill ran without its gate block present means it did **not** run.

---

## Skill Categories

### Workflow Orchestration (10 skills)

Coordinate multi-phase work, routing, and delivery gates.

- **workflow-router**: Sole routing authority; classifies all incoming work
- **workflow-build-one**: Standard workhorse — one issue from branch to merged PR
- **workflow-feature**: Vague idea → ready-to-implement issues (stops before code)
- **workflow-debug**: Bug diagnosis → fix → regression test
- **execute-prd**: Full PRD tree execution with dependency ordering
- **run-backlog**: AFK batch processing of ready-for-agent issues
- **workflow-review**: Independent review gate with risk-sized profiles
- **workflow-finalize**: Universal delivery closure (PR body → CI → merge → cleanup)
- **design-plan**: Turn audit/requirement into phased plan
- **execute-phase**: Run one or more phases of a design-plan

### Phase Management & Setup (5 skills)

Create and manage isolated worktrees, phases, and workflow state.

- **setup-worktree**: Create isolated git worktree for issue/phase
- **cleanup-delivery**: Post-merge cleanup (branch, worktree, issue close)
- **setup-skills**: Initialize "Agent skills" block in AGENTS.md/CLAUDE.md; optionally register repo for OpenWiki nightly doc generation
- **git-guardrails**: Pre-hook guards for dangerous git commands
- **resolving-merge-conflicts**: Structured git merge/rebase conflict resolution

### Implementation & Coding (6 skills)

Write code, tests, and prototypes.

- **implement**: Implement a feature from PRD/issue/spec
- **tdd**: Test-driven development with red-green-refactor loop
- **prototype**: Build throwaway prototype to answer design question
- **codebase-design**: Design module interfaces and boundaries
- **improve-codebase-architecture**: Find deepening opportunities using domain language
- **user-journey-qa**: Playwright-first UX regression verification (UI changes)

### Analysis & Design (10 skills)

Plan, grill, and make design decisions.

- **grill-with-docs**: Canonical grill engine for design interrogation
- **decision-log**: Record accepted decisions in docs/decision-log.md
- **repo-audit**: Map-reduce codebase audit with risk categories
- **domain-modeling**: Build and sharpen domain vocabulary
- **analysis-design**: Design analysis from a decision, not from data
- **analysis-council**: Convene 2–5 expert council to stress-test claims
- **clarity-review**: Review document/email for communication clarity
- **decision-memo**: Transform analysis into executive memo (Pyramid Principle)
- **strategic-analysis-review**: Review exec-facing analyses for argument strength
- **post-mortem**: Blameless retrospective after significant work

### Product & Requirements (5 skills)

Turn ideas into PRDs, issues, and roadmaps.

- **to-prd**: Turn conversation into PRD and post as GitHub issue
- **to-issues**: Decompose plan/spec into independently-grabbable issues
- **triage**: Classify issues through state machine (open → ready-for-agent)
- **okr-generator**: Draft OKRs that are decisions, not wish-lists
- **product-launch-checklist**: Phase-gated launch plan from launch blast radius

### Metrics & Data (8 skills)

Design, audit, and verify metrics and data pipelines.

- **metric-design**: Design metric from a question, not available data
- **metric-council**: Council to stress-test metric design
- **metric-tree-review**: Audit metric tree for consistency
- **data-quality-audit**: Audit table/model/pipeline for data issues
- **data-readiness-check**: Verify data exists, is fresh, correctly grained
- **mock-data-generator**: Generate realistic, referentially-consistent mock datasets
- **lineage-audit**: Trace metric/table backward to sources and forward to dependents
- **experiment-design**: Design A/B test, multivariate, switchback, holdout

### Incident & Debug (5 skills)

Investigate and resolve bugs, incidents, and performance issues.

- **diagnose**: Disciplined diagnosis loop (reproduce → minimize → rank → test → fix)
- **incident-triage**: During incident, establish facts, scope, blast radius
- **incident-retro**: Blameless post-incident retrospective
- **runbook-author**: Author/update operational runbook from incident retro
- **watch-ci**: Manual CI polling and bounded fix helper

### Review & Quality (7 skills)

Review code, design, and output for quality and correctness.

- **workflow-review**: Independent review gate (called by all delivery workflows)
- **pr-review**: Review GitHub PR against project standards
- **receive-review**: Process PR review comments end-to-end
- **pr-responder**: Bulk-process open PR review comments
- **spec-review**: Review diff for standards compliance
- **sql-review**: Review SQL query/view/dbt model
- **review-scaffolding**: Foundational pattern for review skills

### Utilities & Operations (10 skills)

Git, documentation, configuration, and runtime utilities.

- **handoff**: Compact conversation into handoff document for another agent
- **wayfinder**: Plan huge foggy chunk as GitHub investigation tickets
- **humanizer**: Remove AI-writing tells from text
- **humanizer-exec**: Executive-tuned humanizer
- **caveman**: Ultra-compressed communication mode (tokens/scroll optimization)
- **zoom-out**: Structured perspective shifts (local, domain, strategic)
- **slop-cleaner**: Canonical cleaner for non-code writing
- **write-a-skill**: Create or revise agent skills
- **prompt-builder**: Generate optimized agent prompt for issue
- **docs-audit**: Audit documentation drift across a repo (completeness, accuracy, freshness, coherence)

### Skill Improvement & Maintenance (4 skills)

Develop, evaluate, and improve the skills library and agent patterns.

- **session-insight**: Analyze agent session for insights/decisions; harvest skill-improvement proposals
- **skill-backlog**: Harvest and prioritize skill-improvement suggestions from session reflections
- **workflow-skill**: Implement one skill change end-to-end (author/revise via write-a-skill, evaluate, land)
- **skill-evaluator**: Produce evidence-backed verdict on whether a finished skill works (pressure battery, quantitative evals, trigger-accuracy, A/B)

### Domain-Specific (8 skills)

Specialized workflows for specific domains.

- **v1-workflow**: Master orchestration for V1 product design
- **v1-idea-grill**: [DEPRECATED] use grill-with-docs instead
- **v1-system-design**: Design technical system for V1 product
- **user-journey-qa**: UX regression verification (Playwright)
- **dashboard-design**: Design dashboard from decision, not data
- **dashboard-review**: Review dashboard for decision-fit and clarity
- **council-scaffolding**: Foundational pattern for council skills
- **graph-first**: Graph-first protocol for loading context

### Automation & Oversight (4 skills)

Orchestrate complex multi-phase workflows and audits.

- **workflow-autonomous-backlog**: Autonomous module discovery → PRDs → AFK backlog execution
- **workflow-effectiveness-audit**: Audit whether skills/workflows are working
- **workflow-executive-doc**: Orchestrate executive-doc creation and review
- **workflow-roadmap**: Create product + implementation roadmap from goals/state

---

## Discovery

### Finding a Skill

Use the skills index:

```bash
cat ~/.config/agents/skills/_docs/skills-index.md
```

Or search for a keyword:

```bash
rg "metric design" ~/.config/agents/skills --files-with-matches
```

Or ask the agent:

```
Find a skill for designing dashboards
→ Agent loads skills-index.md and suggests dashboard-design
```

### Skill Index Structure

The index (auto-generated by `_docs/skills-index.sh`) lists all skills with one-line descriptions. It's in Markdown and grouped by category.

To regenerate:

```bash
cd ~/.config/agents/skills
./_docs/skills-index.sh --write
```

---

## Key Skill Clusters

### The Delivery Cluster

These skills work together to deliver a piece of work from planning through merge:

```
workflow-router
  ↓
┌─────────────────────┬──────────────────────┬─────────────────────┐
│                     │                      │                     │
workflow-feature  workflow-build-one    execute-prd
(plan phase)      (code phase)          (tree phase)
  │                 │                      │
  ├─→ to-prd        ├─→ setup-worktree     ├─→ setup-worktree
  ├─→ to-issues     ├─→ triage             ├─→ for each child:
  ├─→ triage        ├─→ implement            ├─→ implement
  │                 ├─→ workflow-review      ├─→ workflow-review
  │                 ├─→ user-journey-qa     ├─→ user-journey-qa
  │                 ├─→ workflow-finalize    ├─→ workflow-finalize
  │                 └─→ cleanup-delivery   └─→ reconcile-issues
  │                                          ├─→ cleanup-delivery
  └─→ ready-for-agent issues

All paths must end with:
  workflow-review (independent)
  → workflow-finalize (merge + cleanup)
```

### The Design Cluster

Skills for turning ideas into executable plans:

- **grill-with-docs**: Stress-test idea against existing docs and decisions
- **decision-log**: Record the accepted decision
- **design-plan**: Phase a large refactor or migration
- **domain-modeling**: Sharpen vocabulary and contracts
- **analysis-design**: Design analysis from a question
- **analysis-council**: Council to stress-test claims

### The Metrics & Data Cluster

Skills for working with metrics, data pipelines, and experiments:

- **metric-design**: Design metric from question
- **metric-council**: Stress-test metric
- **metric-tree-review**: Audit tree for consistency
- **data-readiness-check**: Verify data exists and is usable
- **data-quality-audit**: Audit for quality issues
- **lineage-audit**: Trace sources and dependents
- **experiment-design**: Design A/B test or experiment
- **mock-data-generator**: Generate test data

### The Audit & Investigation Cluster

Skills for understanding current state:

- **repo-audit**: Codebase state and risks
- **incident-triage**: Active incident facts and scope
- **wayfinder**: Plan huge foggy work as investigation tickets
- **lineage-audit**: Metric/table lineage
- **workflow-effectiveness-audit**: Do our skills/workflows work?
- **workflow-executive-doc**: Synthesize findings for exec audience

---

## Writing a Skill

Every skill follows the same template:

```yaml
---
name: your-skill-name
model: sonnet | opus | haiku
reasoning: low | medium | high
description: 'Single-quoted one-line description used in discovery'
---

# Your Skill Name

## Purpose

When and why to use this skill. Be specific about the trigger conditions.

## When to invoke

Explicit conditions that warrant this skill.

## Process

Step-by-step playbook. If multi-step:

### Step 1: [Name]
Description.

### Step 2: [Name]
Description.

## Workflow Progress Reporting (if multi-step)

```markdown
WORKFLOW_STEPS:
| Step | Required? | Status | Evidence |
|------|-----------|--------|----------|
| Step 1: X | required | pending | - |
| Step 2: Y | required | pending | - |
```

## Gate Blocks (if decision-heavy)

Structured evidence blocks with specific fields.
```

### Best Practices

1. **Start with purpose**: Explain *when* and *why*, not just *how*
2. **Be specific**: "Use when X" is better than "Use for tasks"
3. **Step ledgers**: Multi-step skills must have them; update status throughout
4. **Gate blocks**: Capture decisions with evidence, not prose claims
5. **Narration**: Full prose for findings/blockers; use caveman mode only during mechanical loops
6. **Single responsibility**: One skill = one clear job; split if it does multiple things
7. **Reference other skills**: Don't duplicate procedures; reference and link instead

### Testing a Skill

When you create a new skill, verify it:

1. Load it: `cat ~/.config/agents/skills/my-skill/SKILL.md`
2. Check YAML frontmatter: `yq eval '.name, .model, .reasoning' ~/.config/agents/skills/my-skill/SKILL.md`
3. Lint Markdown: `markdownlint ~/.config/agents/skills/my-skill/SKILL.md`
4. Run a golden-path test: Ask the agent to invoke it with a simple case
5. Regenerate the index: `_docs/skills-index.sh --write`

---

## Loading a Skill

When a prompt, goal, or handoff **names a skill**, the skill is **loaded and followed**:

```
Agent: "I'll run workflow-finalize now"
    ↓
[load ~/.config/agents/skills/workflow-finalize/SKILL.md]
    ↓
[follow every step in the Process section]
    ↓
[emit all required gate blocks before claiming completion]
```

**Non-negotiable rule**: If the skill's steps or gate blocks are not present in the output, the skill did not run — no matter what the prose says.

---

## Skill Versioning

Skills are **append-only** and **backward-compatible**:

- **Add new steps**: Append to the Process section (don't renumber existing steps)
- **Deprecate old steps**: Mark with `[DEPRECATED]` but leave them; new runs skip them
- **Add new gate blocks**: Append to Gate Blocks section (don't remove old ones)
- **Record breaking changes in decision-log**: If a skill must change semantics, add a decision-log entry

Example:

```markdown
### Step 3: Build the thing [DEPRECATED]

This step is no longer used. Replaced by Step 5 (2026-01-15).

### Step 5: Build with new system (added 2026-01-15)

...
```

---

## See Also

- **Skills Index**: `~/.config/agents/skills/_docs/skills-index.md` (all ~90 skills)
- **Workflows**: [Workflows Overview](/openwiki/workflows/overview.md) (how skills are routed)
- **Architecture**: [System Design](/openwiki/architecture/system-design.md) (how skills fit in the system)
- **write-a-skill**: `~/.config/agents/skills/write-a-skill/SKILL.md` (detailed skill authoring guide)

