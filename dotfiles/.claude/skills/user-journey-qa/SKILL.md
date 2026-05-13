---
name: user-journey-qa
description: Playwright-first UX regression verification for user-facing changes
codex-compatible: false
---

# User Journey QA

## Purpose

Verify that user-facing changes don't break critical user journeys. Uses Playwright MCP for browser automation. This is a quality gate, not a test-writing skill — it verifies existing journeys still work after changes.

## When to invoke

- User-facing behavior changed
- Frontend code changed (components, pages, routing)
- Auth, onboarding, payment, or navigation flows modified
- Issue or PRD marks manual QA required
- PRD includes user journey acceptance criteria
- After execute-phase on frontend work

## Project configuration

Each project defines its critical journeys in `docs/agents/user-journeys.md`:

```markdown
# User Journeys

## Authentication
- [ ] User can sign up with email
- [ ] User can log in with existing credentials
- [ ] User sees error on invalid credentials
- [ ] User can reset password

## Checkout
- [ ] User can add item to cart
- [ ] User can proceed to checkout
- [ ] User can complete payment
- [ ] User sees confirmation

## Navigation
- [ ] All primary nav links resolve
- [ ] Back button works correctly
- [ ] Deep links load correct content
```

If `docs/agents/user-journeys.md` doesn't exist, the skill halts and asks the user to define journeys first.

## Process

### 1. Identify affected journeys
- Read the issue/PRD/PR description for claimed changes
- Read `docs/agents/user-journeys.md` for the full journey list
- Map changes to affected journeys (e.g., auth code changed → Authentication journeys)

### 2. Generate Playwright scripts
For each affected journey step:
- Generate a Playwright test that exercises the step through the browser
- Use realistic test data
- Include assertions for expected outcomes
- Include screenshot capture on failure

### 3. Execute via Playwright MCP
- Run generated scripts via the Playwright MCP server
- Capture results (pass/fail per step)
- On failure: capture screenshot, DOM state, console errors

### 4. Report
```markdown
## User Journey QA Report

### Affected journeys: [list]

### Results
| Journey | Step | Status | Notes |
|---------|------|--------|-------|
| Auth | Sign up with email | PASS | |
| Auth | Login with credentials | FAIL | Button not clickable (screenshot attached) |

### Failures requiring attention
- [detailed failure descriptions with evidence]

### Verdict: PASS / FAIL / PARTIAL
```

## Limitations

- Cannot verify subjective UX quality (only functional correctness)
- Requires running application (dev server or staging URL)
- Flaky network/timing issues may cause false failures — retry once before reporting

## Contract

Consumes: issue/PRD/PR description, project user-journeys.md, running application URL
Produces: UX verification report with pass/fail per journey step, screenshots on failure
Requires: playwright-mcp
Side effects: none (read-only browser interaction against running app)
Human gates: none (informational output only — does not block merge)

## Context

Typical workflows: workflow-build-one (optional gate), workflow-debug (after fix)
Pairs well with: execute-phase, workflow-review, workflow-finalize
