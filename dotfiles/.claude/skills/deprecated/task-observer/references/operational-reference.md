# Task Observer Operational Reference

Use this file only when the short `SKILL.md` needs more detail.

## Activation Setup

For reliable activation, add an instruction to the project configuration:

```markdown
At the start of any task-oriented session - any interaction where you will use
tools and produce deliverables - invoke the task-observer skill before beginning
work.

When loading any skill, check the observation log for OPEN observations tagged
to that skill. Apply their insights to the current work, even if the skill file
has not been updated yet.
```

Description-level matching is useful but not sufficient for a skill that should
run across many task types.

## Skill Taxonomy

Open-source skills are client-agnostic and methodology-driven. They should
include attribution, license, feedback path, and no project-identifying details.

Internal skills contain user, client, or project-specific rules. Keep them
shorter and less formal. Do not over-engineer internal working documents.

## Lean Content Rule

A skill should contain only content that changes agent behavior at execution
time. Move changelogs, long rationale, maintainer notes, and detailed examples
that are not needed at runtime into references.

## Logging Safety

When logging an observation:

1. Search the whole log for existing `### Observation N:` headings.
2. Use the next highest number.
3. Immediately before append, re-check the proposed number does not already
   exist.
4. After append, re-read the log and confirm the number appears once.
5. If a collision occurred, renumber the just-written entry to max+1.

Append new observations to the end of the log. Do not insert observations
mid-file and do not use alternative ID formats.

## Confidentiality

For open-source observations, strip client names, project names, URLs, domain
specific identifiers, and examples specific enough to identify the client.

Before turning observations into an open-source skill, run:

1. Source-material sweep for identifying details.
2. Draft sweep for identifying details.
3. Cross-example re-identification sweep: check whether multiple sanitized
   examples together reveal a client or project.

When in doubt, make the observation internal or generalize the principle.
