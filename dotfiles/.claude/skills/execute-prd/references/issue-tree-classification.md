# Issue Tree Classification Rules

Load this during Phase 2 when building the parent PRD issue tree.

Classify each child issue:

| Classification | Meaning | Action |
|---------------|---------|--------|
| `ready implementation` | Clear acceptance criteria, unblocked, no overlap | Execute |
| `already implemented` | Existing PR covers this | Reconcile only |
| `blocked` | Depends on another child or external work | Skip, document |
| `needs triage` | Vague acceptance criteria or unclear scope | Skip, flag |
| `not AFK-safe` | Requires human judgment | Skip, flag |
| `duplicate` | Overlapping open or merged PR | Skip, reconcile |

Never fabricate acceptance criteria. For execution, absent or materially ambiguous criteria mean `needs triage`; do not dispatch the child. `[inferred]` criteria are allowed only in planning summaries, not child execution briefs or AFK prompts.
