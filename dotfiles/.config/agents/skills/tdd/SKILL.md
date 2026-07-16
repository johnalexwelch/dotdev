---
name: tdd
model: sonnet
reasoning: medium
description: Test-driven development with red-green-refactor loop. Use when user wants to build features or fix bugs using TDD, mentions "red-green-refactor", wants integration tests, or asks for test-first development.
---

## Contract

Consumes: behavior specification (user-confirmed interface + behaviors), codebase
Produces: tests and implementation code (red-green-refactor cycles)
Requires: project-test-runner
Side effects: creates/modifies source and test files
Human gates: planning phase (interface and behavior confirmation before any code)

Runtime note: a project test runner or executable verification harness is required to execute the red-green loop and is discovered from repo files or CI workflows. If none exists, halt before implementation.

For AFK or workflow-driven usage, the planning gate is satisfied only when the issue acceptance criteria or diagnosis artifact explicitly name the public interface and behaviors to test. Otherwise halt for human clarification before writing tests or code.

## Context

Typical workflows: feature development, bug fixing (test-first)
Pairs well with: diagnose, implement, execute-phase, improve-codebase-architecture, codebase-design

# Test-Driven Development

## Philosophy

**Core principle**: Tests should verify behavior through public interfaces, not implementation details. Code can change entirely; tests shouldn't.

**Good tests** are integration-style: they exercise real code paths through public APIs. They describe *what* the system does, not *how* it does it. A good test reads like a specification - "user can checkout with valid cart" tells you exactly what capability exists. These tests survive refactors because they don't care about internal structure.

**Bad tests** are coupled to implementation. They mock internal collaborators, test private methods, or verify through external means (like querying a database directly instead of using the interface). The warning sign: your test breaks when you refactor, but behavior hasn't changed. If you rename an internal function and tests fail, those tests were testing implementation, not behavior.

See [tests.md](tests.md) for examples and [mocking.md](mocking.md) for mocking guidelines.

## Anti-Pattern: Tautological Tests

A tautological test **can never disagree with the code** — it passes by construction. The tell: the expected value is computed the same way the implementation computes it.

```typescript
// Tautological — the test mirrors the implementation, can never catch a bug
expect(add(a, b)).toBe(a + b);

// Correct — expected value from an independent source of truth
expect(add(2, 3)).toBe(5);
```

Expected values must come from an **independent source of truth**: a known-good literal, a worked example, the spec, or a manually-verified result. Never derive the expected value the same way the code under test derives it.

## Anti-Pattern: Horizontal Slices

**DO NOT write all tests first, then all implementation.** This is "horizontal slicing" - treating RED as "write all tests" and GREEN as "write all code."

This produces **crap tests**:

- Tests written in bulk test *imagined* behavior, not *actual* behavior
- You end up testing the *shape* of things (data structures, function signatures) rather than user-facing behavior
- Tests become insensitive to real changes - they pass when behavior breaks, fail when behavior is fine
- You outrun your headlights, committing to test structure before understanding the implementation

**Correct approach**: Vertical slices via tracer bullets. One test → one implementation → repeat. Each test responds to what you learned from the previous cycle. Because you just wrote the code, you know exactly what behavior matters and how to verify it.

```
WRONG (horizontal):
  RED:   test1, test2, test3, test4, test5
  GREEN: impl1, impl2, impl3, impl4, impl5

RIGHT (vertical):
  RED→GREEN: test1→impl1
  RED→GREEN: test2→impl2
  RED→GREEN: test3→impl3
  ...
```

## Workflow

### 1. Planning

When exploring the codebase, use the project's domain glossary so that test names and interface vocabulary match the project's language, and respect ADRs in the area you're touching.

Before writing any code:

- [ ] Confirm with user what interface changes are needed
- [ ] Confirm with user which seams to test — a [seam](../codebase-design/SKILL.md) is the public boundary a test observes behavior through, never internals. No test is written at an unconfirmed seam.
- [ ] Identify opportunities for [deep modules](deep-modules.md) (small interface, deep implementation)
- [ ] Design interfaces for [testability](interface-design.md)
- [ ] List the seams and behaviors to test (not implementation steps)
- [ ] Get user approval on the plan

Ask: "What should the public interface look like? Which seams should we test, and which behaviors at each?"

**You can't test everything.** Agreeing the seams up front with the user, before any test is written, is how testing effort lands on critical paths and complex logic instead of every possible edge case.

### 2. Tracer Bullet

Write ONE test that confirms ONE thing about the system:

```
RED:   Write test for first behavior → test fails
GREEN: Write minimal code to pass → test passes
```

This is your tracer bullet - proves the path works end-to-end.

> **Resuming / handed-off work still starts RED.** Picking up a phase
> mid-stream, from a summary, or from another session's handoff does NOT
> license writing implementation first. Write the failing test for the next
> behavior before any code, even when the surrounding scaffolding already
> exists.

### 3. Incremental Loop

For each remaining behavior:

```
RED:   Write next test → fails
GREEN: Minimal code to pass → passes
```

Rules:

- One test at a time
- Only enough code to pass current test
- Don't anticipate future tests
- Keep tests focused on observable behavior

### 4. Stop at Green

**Refactoring is not part of this loop.** Once a cycle is GREEN, stop — don't extract duplication, deepen modules, or apply cleanups here. Refactoring happens during review (see the self-review step of `implement`, which runs `pr-review`), not as part of this loop.

## Checklist Per Cycle

```
[ ] Test describes behavior, not implementation
[ ] Test uses public interface only
[ ] Test would survive internal refactor
[ ] Code is minimal for this test
[ ] No speculative features added
```
