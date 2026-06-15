---
name: task-observer
model: haiku
description: Monitors task execution for skill improvement opportunities. Use at the start of multi-step tasks, agentic workflows, substantive tool-using sessions, post-task feedback discussions, or meta-discussions about skills. Also known as "One Skill to Rule Them All".
---

## Deprecation Status

Status: deprecated. Passive skill-improvement monitoring is covered by workflow-effectiveness-audit (active transcript/PR audit) and skill-maintenance (library hygiene).

- Replaced by: workflow-effectiveness-audit, skill-maintenance
- Date: 2026-06-10

---

# Task Observer - Continuous Skill Discovery

**Created by Eoghan Henn / [rebelytics.com](https://rebelytics.com)**

This is the runtime wrapper for One Skill to Rule Them All. It watches real
work for reusable skill improvements, simplifications, and new skill
candidates. It does not replace `skill-creator`; it feeds it with concrete
observations.

**Licence:** This skill is released under Creative Commons Attribution 4.0
International (CC BY 4.0). See `LICENSE.txt`.

**User docs:** For user-facing setup and methodology, use the upstream docs:

- README: <https://github.com/rebelytics/one-skill-to-rule-them-all/blob/main/README.md>
- USER-GUIDE: <https://github.com/rebelytics/one-skill-to-rule-them-all/blob/main/USER-GUIDE.md>

## Runtime Rules

1. At task start, check whether a local observation log exists at
   `skill-observations/log.md`, `.skill-observations/log.md`, or another
   project-configured observation path.
2. When loading any skill, check the observation log for OPEN observations
   tagged to that skill. Apply relevant observations during the current work.
3. Observe silently during the full task session, including post-task feedback
   and methodology discussion.
4. Log an observation within the same turn or immediately following turn when a
   reusable pattern appears. Do not rely on memory for batch logging later.
5. Surface observations only at session end, when user input is needed, or when
   the active skill is producing wrong output.
6. Observations identify what to improve. Do not edit skills during normal work
   unless the user explicitly asks to apply the observation now.

If no observation log exists, continue the task normally and mention at the end
that observation persistence is not configured for this workspace.

## Contract

Consumes: task session context, loaded skills, optional observation log
Produces: appended skill observations and end-of-session observation summary
Requires: writable observation log for persistence; otherwise runs in non-persistent mode
Side effects: appends to `.skill-observations/log.md` or configured observation log
Human gates: skill edits happen only when the user explicitly asks or approves a review action

## What To Observe

Log improvements when:

- The agent fails to follow a skill's documented rules.
- The user corrects output in a way that generalizes beyond the current task.
- A workflow step is consistently too heavy, too weak, skipped, or misplaced.
- A new tool or capability makes part of a skill obsolete or cheaper.
- A recurring multi-step workflow would benefit from a dedicated skill.
- A skill contains dead weight, duplicated rules, or rules that never reach the
  decision point.
- The session reveals a better quality-preserving way to reduce subagent use.

Do not log:

- One-off corrections that do not generalize.
- Preferences already captured in an existing skill.
- Temporary tool failures unrelated to skill methodology.
- Open-source observations whose principle would leak client or project details.

## Subagent Budget Observations

Because subagent load is a recurring workflow cost, watch for review and
verification steps where quality was preserved with fewer agents. Useful
observations should name:

- The task risk level.
- Which independent review evidence was actually needed.
- Which lanes were redundant or valuable.
- Whether a `fast`, `standard`, or `full` review profile would have been enough.

These observations should feed `workflow-review`, `workflow-router`,
`prompt-builder`, and backlog/finalize skills rather than accumulating as
session-specific advice.

## Observation Format

Append observations using this shape:

```markdown
### Observation N: Short title

**Date:** YYYY-MM-DD
**Session context:** Brief task context
**Skill:** existing skill name, or "New skill candidate: name"
**Type:** open-source | internal
**Phase/Area:** section or workflow area

**Issue:** What happened or what pattern emerged.

**Suggested improvement:** Concrete skill change or new skill scope.

**Principle:** Generalizable takeaway.
```

Before writing, read the log to find the highest existing `Observation N` and
append the next number. After writing, re-read that number and renumber if a
parallel session collided.

## References

- `references/operational-reference.md` - logging, archival, taxonomy, and
  confidentiality details.
- `references/review-procedure.md` - periodic review and applying observations.
