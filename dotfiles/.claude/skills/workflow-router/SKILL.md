---
name: workflow-router
description: Single authoritative entry point for classifying work and routing to the correct workflow skill
---

# Workflow Router

## Purpose

The single routing authority for all incoming work. Classifies the task, runs preflight checks, and dispatches to the appropriate workflow skill. Replaces ad-hoc routing decisions with a consistent classification system.

## Authority

This skill is the **sole routing authority**. Per ADR-0002:

- `workflows.md` is reference documentation only — it does not route
- OMC keyword triggers (`autopilot`, `ralph`, `ultrawork`, etc.) bypass this router intentionally — they are power-user shortcuts
- All other work goes through this router

## Classification table

| Signal | Classification | Routes to |
|--------|---------------|-----------|
| Bug report, error, "it's broken", regression | **bug** | workflow-debug |
| Vague idea, "what if we...", "I want to build..." | **ambiguous feature** | workflow-feature |
| Issue with `ready-for-agent` + clear acceptance criteria | **ready issue** | workflow-build-one |
| Multiple ready issues, "run the backlog", AFK batch | **AFK backlog** | run-backlog |
| "Audit the repo", large-scale analysis needed | **refactor/audit** | repo-audit → design-plan (Audit Loop) |
| Research question, "investigate how..." | **research** | RPI Chain (research → plan → implement) |
| "Review this", "review my changes" | **review** | workflow-review |
| D&D, campaign, session prep, mystery, encounter, NPC, worldbuilding | **creative/D&D** | dnd-workflow |

## Bug routing rule

**Never route bugs to workflow-build-one**, even if the fix appears obvious. Bugs always go to workflow-debug, which enforces diagnosis-first. This prevents:

- Fixing symptoms instead of root causes
- Missing regression tests
- Incorrect assumptions about "simple" bugs

## Preflight

Before dispatching, check the target workflow's `Requires` field:

1. Read the target skill's `## Contract` section
2. For each tool in `Requires:`, verify availability:
   - CLI tools: check via `which <tool>`
   - MCP servers: check if configured
   - Project tools: check if project has expected config (package.json, Makefile, etc.)
3. If a required tool is missing:
   - Report what's missing and why it's needed
   - Suggest installation or alternative
   - Do NOT proceed with the workflow

## Graceful degradation

| Missing tool | Impact | Behavior |
|--------------|--------|----------|
| `gh` | Can't interact with GitHub | Flag finalization incomplete, work locally only |
| OMC | Can't dispatch to Codex team | Fall back to direct Claude execution |
| CORA | Can't validate contracts | Skip contract validation, proceed normally |
| `playwright-mcp` | Can't run UJ QA | Skip user-journey-qa step, note in PR |
| Project test runner | Can't verify | Halt and request setup info |
| Campaign docs | D&D skills degrade gracefully | dnd-grill works without docs; dnd-grill-with-canon falls back to lightweight mode |

## Process

```
1. Receive work description (user input, issue, or automated trigger)
2. Classify using signal table above
3. If ambiguous: ask ONE clarifying question (max 1 — don't interrogate)
4. Run preflight on target workflow
5. If preflight passes: dispatch to target workflow
6. If preflight fails: report missing requirements
```

## Contract

Consumes: work description (user input, issue body, automated trigger)
Produces: dispatched workflow invocation, preflight report (if failed)
Requires: none (the router itself has no tool dependencies — target workflows do)
Side effects: none (routing is a decision, not an action)
Human gates: ambiguous classification asks one clarifying question

## Context

Typical workflows: entry point (invoked implicitly or explicitly for all new work)
Pairs well with: all workflow skills (it routes to them), preflight validates their contracts
