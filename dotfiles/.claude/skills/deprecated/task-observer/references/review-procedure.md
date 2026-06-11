# Task Observer Review Procedure

Use this reference during scheduled or user-requested observation reviews.

## When To Act

Apply observations only when:

- The user explicitly asks to update a skill or act on an observation.
- A scheduled/comprehensive review is running.
- A skill is actively producing wrong output and immediate correction is needed.

Normal task sessions log observations; they do not edit skills unless asked.

## Review Steps

1. Archive resolved observations from prior sessions.
2. Read all OPEN observations.
3. Group by target skill or new-skill candidate.
4. For each group, decide: apply, defer, decline, or split into separate work.
5. Prefer simplifying existing skills before adding new rules.
6. For low-risk wording changes, edit directly.
7. For structural changes, use `skill-creator` or a written edit plan.
8. Mark observations ACTIONED or DECLINED only after the change or decision is
   recorded.

## Subagent Budget Review

During review, specifically ask:

- Did any workflow use more subagents than the risk justified?
- Did a single independent reviewer catch the same issues a multi-lane review
  would have caught?
- Did a full review prevent a real miss?
- Should the profile trigger move between `fast`, `standard`, and `full`?

Propagate proven answers into the owning workflow skill, not just into
task-observer.
