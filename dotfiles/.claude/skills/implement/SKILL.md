---
name: implement
model: sonnet
reasoning: medium
description: Implement a piece of work from a PRD, issue, or spec. Use when the user says "implement this", "build this", "write the code for", or hands you a PRD/issue to execute.
---

## Contract

Consumes: PRD, issue, or spec; codebase context; CONTEXT.md; ADRs
Produces: committed, tested, reviewed implementation on the current branch
Requires: git, project test runner
Side effects: modifies source files, creates commits
Human gates: public interface confirmation before writing tests or code (see tdd planning gate); ambiguous acceptance criteria → halt and ask

## Context

Typical workflows: feature development (after to-prd/to-issues/triage); for worktree-tracked AFK work use workflow-build-one instead
Pairs well with: tdd, pr-review, diagnose, improve-codebase-architecture

# Implement

## 0. Before writing any code

Read:
- The full PRD or issue body including acceptance criteria
- CONTEXT.md (if present) — use its vocabulary in all code and commits
- ADRs in the area you're touching — do not re-litigate settled decisions
- Existing tests for similar modules — understand test conventions before adding new ones

If the issue is a bug, use `diagnose` first. Implementation starts after Phase 5 of the diagnosis loop.

## 1. Plan the slice

Identify the smallest vertical slice that satisfies the first acceptance criterion end-to-end. Confirm the public interface with the user before writing tests or code — this is the `tdd` planning gate.

If acceptance criteria are ambiguous or missing, halt and ask. Do not invent scope.

## 2. Build test-first via TDD

Invoke the `tdd` skill. Do not substitute ad-hoc test writing for the TDD loop — run the skill. Key rules:

- One test → one implementation → repeat (vertical, not horizontal)
- Tests verify behavior through public interfaces only
- Run typechecks after each green cycle, not just at the end
- Run the single test file regularly; run the full suite at end of session

See [tdd/SKILL.md](../tdd/SKILL.md) for the full loop, anti-patterns, and checklist.

## 3. Typecheck continuously

Run the project's typecheck command after every meaningful code change — not just at the end. Catching type errors mid-slice is faster than batch-fixing at the end.

## 4. Commit in vertical slices

Each commit should represent a working, tested, demoable slice of behavior — not a layer or a file. Commit message: what behavior this delivers, which acceptance criterion it satisfies.

```
feat: [behavior delivered]

Closes #<issue>
AC: [acceptance criterion text]
```

Do not leave uncommitted changes when handing off.

## 5. Self-review before declaring done

Run `pr-review` (or equivalent) against the branch before calling it done. Check:
- Standards axis: does the code follow repo conventions?
- Spec axis: does every acceptance criterion have a corresponding passing test?

For every finding: either fix it in the current branch, file a follow-on issue, or leave a code comment explaining why it's deferred. Do not discard findings silently.

After all ACs are satisfied, check them off on the originating issue: `gh issue edit <number> --body "..."` or use `gh issue comment` to mark each criterion complete. Leave the issue in a state a future reader can confirm is done.

## 6. Final gate

```
[ ] All acceptance criteria have passing tests
[ ] Typechecks pass
[ ] Full test suite passes
[ ] No uncommitted changes
[ ] pr-review run and findings addressed (fixed, filed, or documented — none dropped)
[ ] Commit message references the issue
[ ] Acceptance criteria checked off on the originating issue
```
