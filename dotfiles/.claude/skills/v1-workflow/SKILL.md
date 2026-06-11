---
name: v1-workflow
model: opus
description: Master orchestration for turning a product idea into a complete V1 system design with ready-to-implement issues. Use when starting a new V1 product from an idea or when building a major version from concept.
---

# V1 Workflow

## Purpose

Transform a product idea from concept through system design, decision documentation, and roadmap planning into a set of ready-to-implement issues. This is the master workflow for V1 development — it orchestrates the full pipeline with hard gates at critical decision points.

All output issues must represent vertical slices of V1 functionality. Do not produce horizontal layer tickets (database-only, API-only, UI-only) unless they are independently demoable or system-verifiable.

## When to invoke

- User has a new product idea they want to turn into a shippable V1
- User wants to start a major version with full system design
- workflow-router classifies work as "V1 idea discovery" or "V1 system design"
- User says "build me a V1 from this idea"

## Contract

Consumes: loose product idea, constraints, target users, any existing context
Produces: approved V1_IDEA_BRIEF, approved V1_SYSTEM_DESIGN, decision-log entries, roadmap with implementation slices, ready-to-triage issues
Requires: git (for system design context inspection when building in existing codebase)
Side effects: creates/updates CONTEXT.md, decision-log.md, roadmap artifact, PRD(s), and issue(s) only when explicitly approved at each gate
Human gates: approval required at 4 critical points: idea brief, system design, roadmap, and issue readiness

## Flow

```
v1-idea-grill (Step 1)
  ↓ [approval gate]
decision-log (Step 2)
  ↓
[prototype] (Step 2.5 — optional)
  ↓
v1-system-design (Step 3)
  ↓ [approval gate]
decision-log update (Step 4)
  ↓
workflow-roadmap (Step 5)
  ↓ [approval gate]
to-prd (Step 6)
  ↓
to-issues (Step 7)
  ↓
triage (Step 8)
  ↓
ready-to-implement issues
```

## Workflow Progress Reporting

At the start of every run, display a step ledger before executing or dispatching any step.

```markdown
WORKFLOW_STEPS:
| Step | Required? | Status | Evidence / Skip Reason |
|------|-----------|--------|------------------------|
| <step name> | required|conditional|optional | pending|completed|skipped|blocked|failed | <evidence or reason> |
```

Rules:

- Initialize every known step as `pending`; conditional steps remain `pending` until their trigger is evaluated.
- As each step finishes or is skipped, update the ledger with the new status and evidence or reason.
- Do not mark required gates as skipped. If a gate cannot run, mark it `blocked` or `failed` and halt.
- At every halt, STOP, handoff, and final completion, include the final ledger in the response.
- The final ledger must distinguish `completed`, `skipped`, `blocked`, `failed`, and explain all non-completed statuses.

---

## Detailed Steps

### Step 1: V1 Idea Grill

**Invoke:** `v1-idea-grill`

- Interview the user about the product idea
- Clarify target users, core problem, V1 promise
- Resolve ambiguities and constraints
- Identify non-goals and success criteria
- Output: approved `V1_IDEA_BRIEF` artifact

**Gate:** User must approve the V1_IDEA_BRIEF before proceeding. If the brief is unclear, incomplete, or the user rejects it, halt and re-run grilling.

**Evidence:** Approved V1_IDEA_BRIEF in chat or artifact system.

### Step 2: Capture Grill Decisions in Decision Log

**Invoke:** `decision-log`

For every significant decision accepted during the idea grill, create a decision-log entry:

- Question asked and why it matters
- Answer chosen and alternatives considered
- Trade-offs accepted
- Impact on V1 scope

This log becomes the context for system design and downstream PRDs.

**Evidence:** decision-log.md with entries for all grill decisions.

### Step 2.5: Prototype (Conditional)

**Trigger when:** Grilling surfaces a question that reasoning alone cannot answer.

**Examples:**
- "Does this state model handle the case where X then Y?" → prototype (logic branch)
- "What should this look like?" → prototype (UI branch)
- "What's the right API shape?" → prototype (interface branch)

**Skip when:** Grilling output is clear enough to write system design directly.

**Evidence:** NOTES.md or ADR capturing the prototype's answer (not the code).

### Step 3: V1 System Design

**Invoke:** `v1-system-design`

- Validate the approved V1_IDEA_BRIEF exists
- Inspect existing codebase context if building in an existing repo
- Design from V1 user flow backward to system responsibilities
- Define modules, interfaces, data models, integrations
- Identify risks, rollout approach, and implementation slices
- Output: approved `V1_SYSTEM_DESIGN` artifact

**Gate:** User must approve the system design before proceeding. High-risk architecture decisions must have explicit sign-off. If the user has concerns, re-visit grilling or prototype before finalizing design.

**Evidence:** Approved V1_SYSTEM_DESIGN artifact in chat or artifact system.

### Step 4: Update Decision Log with Design Decisions

**Invoke:** `decision-log`

For every significant architectural decision in the system design, create a decision-log entry:

- Design decision and why it was chosen
- Alternatives considered
- Trade-offs and implications
- Risk acceptance

This ensures downstream PRD writers and implementers understand the "why" behind the architecture.

**Evidence:** decision-log.md with architecture decision entries.

### Step 5: Create V1 Roadmap

**Invoke:** `workflow-roadmap`

- Sequence the implementation slices identified in system design
- Define milestones and dependencies
- Identify critical path and risk mitigation
- Plan hardening, integrations, and testing phases
- Output: approved roadmap artifact with explicit vertical-slice path

**Gate:** User must approve the roadmap before PRD creation. If the roadmap is incomplete or the vertical-slice path is unclear, halt and re-plan.

**Evidence:** Approved roadmap artifact (e.g., `docs/roadmaps/YYYY-MM-DD-<product>-roadmap.md`) with user sign-off.

### Step 6: Write PRD(s)

**Invoke:** `to-prd`

- For each major vertical slice from the roadmap, create a PRD
- Each PRD should represent one shippable increment of V1
- Document acceptance criteria, success metrics, dependencies
- Include design rationale from decision log and system design
- Output: ready-to-implement PRD(s)

**Evidence:** PRD artifact(s) in docs/prd/ or linked from roadmap.

### Step 7: Create Issues

**Invoke:** `to-issues`

- For each PRD, create child issues representing implementation tasks
- All issues must be vertical slices (end-to-end feature behavior)
- Include acceptance criteria, test plan, design references
- Link to PRD and roadmap for context
- Output: issue tree with parent (PRD issue) and child (task) issues

**Evidence:** Issues created in GitHub with ready-for-agent or ready-for-human classification.

### Step 8: Triage

**Invoke:** `triage`

- Classify each issue as `ready-for-agent` or `ready-for-human`
- Verify all mandatory fields are present (acceptance criteria, test plan, effort estimate)
- Add AI disclaimer to any AI-generated issue content
- Output: triaged issues ready for implementation or human review

**Evidence:** All issues marked as ready-for-* with triage status and mandatory fields.

---

## Hard Gates and Approval Points

**Gate 1: V1 Idea Brief Approval**
- Halt before Step 2 if the brief is not approved
- User must explicitly confirm the brief captures the V1 idea
- Re-run Step 1 if the brief is unclear or rejected

**Gate 2: System Design Approval**
- Halt before Step 4 if the design is not approved
- User must explicitly confirm the architecture is sound
- Address user concerns or re-design before proceeding

**Gate 3: Roadmap Approval**
- Halt before Step 6 if the roadmap is not approved
- User must explicitly confirm the vertical-slice path and sequencing
- Re-plan if milestones or dependencies are unclear

**Gate 4: Issue Readiness**
- Halt before handoff if any issue is missing mandatory fields
- All issues must pass triage classification
- Return to PRD or system design if issues don't align with the design

---

## Vertical Slice Rule

All issues produced by this workflow must represent vertical slices of V1 behavior:

- **Vertical slice:** An end-to-end feature behavior that can be demoed or verified independently (e.g., "User can create a dashboard and see it in the list")
- **Horizontal layer (forbidden):** Database-only, API-only, UI-only, or tests-only work unless it is independently system-verifiable or demoable

Example of a forbidden horizontal slice: "Add user authentication" (too broad, horizontal across layers).
Example of a correct vertical slice: "User can sign up via email and receive a verification link" (end-to-end, demoable).

---

## When Prototyping is Essential

Do NOT skip Step 2.5 if:

- The user's answers contradict each other and a prototype would clarify
- The API shape or data model is unclear and prototyping would reveal design flaws
- The UI/UX interaction is novel and needs validation before full design
- You're unsure whether the V1 promise is technically feasible

Skip Step 2.5 only when grilling has produced a clear, coherent brief with no open questions about feasibility or design.

---

## Halting and Handoff

If at any step you encounter:

- **Missing required input** (e.g., no approved brief before Step 3): halt, report what's needed, and ask the user to provide it or re-run the upstream step
- **Approval rejected** (user says "not ready yet"): halt, ask what concerns need to be addressed, and offer to re-visit the relevant step
- **Scope creep** (user wants to add significant features during design or PRD): halt, document the new feature request as a separate issue, and confirm the V1 scope is frozen

At final completion, return the full workflow_steps ledger showing all completed gates and issue artifacts.

---

## Integration with Other Workflows

- **If user says "just build it"**: Do NOT skip the full pipeline. Grilling, design, and roadmap exist to prevent wasted work and rebuild. Run the full workflow.
- **If user has an approved V1_IDEA_BRIEF**: Start at Step 3 (v1-system-design), not Step 1.
- **If user has approved system design but no roadmap**: Start at Step 5 (workflow-roadmap).
- **If user has PRDs but no issues**: Start at Step 7 (to-issues) and skip to triage.
- **After V1 ships**: Route subsequent features to `workflow-feature` (not v1-workflow) for minor features, or back to `v1-workflow` for V2 planning.

---

## Example Invocation

```
User: "I want to build a V1 product that helps teams run better standups. Start with the idea."

Response: Invoke v1-idea-grill to:
1. Clarify who the users are (scrum masters, developers, engineering managers)
2. Define the core job (run focused standups without context switching)
3. Identify must-haves (async updates, time constraints, meeting notes)
4. Identify non-goals (advanced analytics, AI summaries for V1)
5. Produce approved V1_IDEA_BRIEF

Then proceed through the full v1-workflow pipeline toward ready-to-implement issues.
```
