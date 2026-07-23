# Task Context Requirements

> These are minimum-context checks. If the task routes to a Superpowers
> skill chain (per workflows.md), the skill handles deeper discovery
> on its own. Use these to fill gaps BEFORE entering the chain, not instead of it.

When Alex's request is missing key details for the task type, ask for the missing pieces BEFORE starting work. Use AskUserQuestion with concise options where possible. Don't ask for everything — just what you can't safely infer from the codebase.

After gathering context, invoke the `workflow-router` skill (the live routing authority) to determine which workflow to follow. The human-readable loop map is at `~/.claude/reference/workflows.md` (on-demand reference; read it if you need the full route table).

## Build a Feature

Minimum context needed:

- **What it does** — the behavior or outcome
- **Where it lives** — which part of the codebase it touches
- **Who/what triggers it** — user action, API call, cron, etc.

Ask if missing:

- Where should this be triggered from? (UI, CLI, API, scheduled)
- Are there existing patterns in the codebase I should follow?
- Should this handle errors silently or surface them to the user?

Example (good): "Add a /prep command that pulls calendar events and recent meeting notes for my next meeting, then generates a one-page prep doc"
Example (vague): "Add meeting prep" — ask what triggers it and what output they expect

## Design a Schema / Template / System

Minimum context needed:

- **What it models** — the thing being categorized or structured
- **How it's used** — who reads it, where it's consumed
- **Scale hint** — how many items, how often it changes

Ask if missing:

- How many categories/levels do you actually need? (Remember: start with 3-5 max)
- What are your naming preferences? (e.g., t-shirt sizes vs numbers vs custom labels)
- Does this need to integrate with an existing system?

Example (good): "Create an effort estimation system for Asana tasks — 3 levels, simple labels I can add as tags"
Example (vague): "Add effort tracking to Asana" — ask how many levels and what format

## Set Up an Integration

Minimum context needed:

- **Which service** — the external system
- **What data flows** — what you're reading/writing
- **Auth method** — do you already have credentials/tokens?

Ask if missing:

- What access level do you have? (admin, member, read-only)
- Is this a work account with IT restrictions?
- Which MCP server or API method should we use?

Example (good): "Connect my personal Gmail to pull unread emails — I already have OAuth set up in ~/.chief-of-staff/"
Example (vague): "Add Gmail" — ask which account, what access, and whether OAuth is set up

## Debug / Fix an Issue

Minimum context needed:

- **What's broken** — the symptom or error
- **When it started** — what changed recently
- **How to reproduce** — steps or trigger

> Note: Once context is gathered, hand off to `superpowers:systematic-debugging`.
> The skill handles root cause analysis, hypothesis testing, and fix verification.

Ask if missing:

- Can you share the error message or logs?
- Did this work before? What changed?
- Is this blocking something urgent?

Example (good): "The /morning command fails to pull calendar events — it worked yesterday, now I get a 401 from Google Calendar MCP"
Example (vague): "Morning briefing is broken" — ask what specific step fails and what error they see

## Refactor / Reorganize Code

Minimum context needed:

- **What's wrong with current state** — why refactor
- **Target outcome** — what "better" looks like
- **Scope boundary** — what NOT to touch

Ask if missing:

- Should this change behavior or just structure?
- Are there files/modules that are off-limits?
- Do we need to maintain backwards compatibility?

Example (good): "Split daily-briefing.js (947 lines) into separate modules per data source — same output, just organized better"
Example (vague): "Clean up the code" — ask which files and what the goal state looks like
