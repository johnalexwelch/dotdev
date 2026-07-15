# Retro Output Template

Load this during Step 4 when drafting the post-mortem.

Save to `docs/executions/<date>-post-mortem.md` using this structure:

```markdown
# Post-Mortem — <repo or effort name>
**Date:** <YYYY-MM-DD>
**Plan:** <relative path to plan>
**Audit:** <relative path to audit>
**Git range:** <since_commit>..HEAD (<N> commits)
**Scope:** complete | partial

## Summary
<One paragraph. What the plan set out to do, what actually got done, what didn't, and whether the overall state improved. Blameless tone.>

## Findings addressed
<Finding-by-finding table per Step 2. If the audit lacked IDs, replace with a phase-by-phase resolution summary.>

## What went as planned
<Phases completed on scope and intent. Brief — one bullet per phase.>

## What drifted
<Phases that deviated. For each:
  - **Phase N — <name>**
  - Planned: <one line>
  - Actual: <one line>
  - Why: <one line>
  - Cost: <time, scope, rework — one line>
Don't sanitize. Drift isn't failure — it's information.>

## New findings (NEW-NN)
<Things discovered during execution that the audit missed. Follow `references/new-findings-rules.md`.>

## Outstanding work
<Findings and tasks still open. Include FIND-NN not yet addressed, skipped or deferred phases, and §9 Open questions from the plan that did not get answered.>

## What I'd change in the next plan
<Concrete lessons about the plan itself. Feeds the next /design-plan invocation.>

## Recommendations for next audit
<What to look for in the next /repo-audit cycle. Usually re-audit areas where NEW-NN findings clustered, run a scoped audit if drift concentrated in one path, or add focus=<slug>.>
```
