---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up. Invoked manually ("handoff", "wrap up session") or automatically by any workflow that halts or completes with remaining work.
argument-hint: "What will the next session focus on?"
codex-compatible: true
---

# Handoff

Compress the current session into a handoff document so a fresh agent can continue without losing context. Works in two modes: manual (user-invoked) and automatic (workflow-invoked at exit points).

## Contract

Consumes: current conversation context, exit reason (manual, halt, completion), remaining work items
Produces: handoff document at docs/executions/handoffs/<date>-<slug>.md (persistent) or mktemp (ephemeral)
Requires: none
Side effects: creates handoff file; for Codex, writes to project directory
Human gates: none

## Soft Context

Typical workflows: mandatory exit for all workflows with remaining work, session boundary, context window limit
Pairs well with: all workflow skills (handoff is their universal exit step), prompt-builder (generates ready-to-use prompts for next-session items)

## Invocation modes

### Manual

User says "handoff", "wrap up session", "save context". Produces a handoff and prints the path.

### Automatic (workflow exit)

Workflows invoke handoff at every exit point where work remains. The calling workflow passes:

- `exit_reason`: why the workflow stopped (completion, halt, blocker, context_limit)
- `remaining_items`: list of concrete next steps
- `target_tool`: claude or codex (inferred from current environment if not specified)

The auto-handoff is silent — it writes the file and reports the path without ceremony.

## When workflows MUST auto-handoff

| Exit condition | Workflow(s) | What goes in the handoff |
|---------------|-------------|--------------------------|
| Halted: review needs human | workflow-build-one, workflow-debug | Review findings, file paths, what the reviewer flagged |
| Halted: issue unclear | workflow-build-one | What's ambiguous, what question to ask |
| Halted: CI exhaustion (3 attempts) | workflow-finalize, watch-ci | CI logs, what was tried, diagnosis hint |
| Halted: needs-human diagnosis | workflow-debug | Diagnosis artifact path, reproduction steps |
| Halted: architecture-review needed | workflow-debug | Diagnosis findings, why it's architectural |
| Halted: unsafe-for-afk | workflow-debug | What makes it unsafe, what a human should verify |
| Completed with follow-ups | workflow-finalize | NEW-NN findings, follow-up issues created |
| Backlog run finished | run-backlog | Summary of results, failed issues, remaining queue |
| Codex task done | any (via prompt-builder) | What was done, PR link, anything that needs human review |

When workflows complete cleanly with NO remaining work, skip the handoff.

## Handoff storage

| Context | Path | Why |
|---------|------|-----|
| Inside a project repo | `docs/executions/handoffs/<date>-<slug>.md` | Persists with the project, discoverable by next agent |
| No project / ephemeral | `mktemp -t handoff-XXXXXX.md` | Temp file, printed to user |
| Codex task | `docs/executions/handoffs/<date>-<slug>.md` committed to branch | Survives across Codex sessions |

## Process

1. Determine storage path (project repo vs temp).
2. Determine exit context (manual vs auto, exit reason, remaining items).
3. If remaining items include ready-for-agent issues, invoke `prompt-builder` for each to generate ready-to-use prompts.
4. Write the handoff document.
5. Print the path. If auto-invoked, keep it to one line.

## Handoff document structure

```text
# Handoff — [short title of current work]

Exit: [manual | halt: <reason> | completion with follow-ups | backlog run complete]
Target: [claude | codex | either]
Generated: [timestamp]

## Where we are

[One paragraph: what was being worked on, what state it is in now.]

## What was done this session

[Bulleted list of concrete outcomes. Reference artifacts by path or URL.]
- Completed X (see docs/plans/2026-05-13-design.md)
- Opened PR #142 for Y
- Created 3 issues: #15, #16, #17

## What is NOT done

[Bulleted list of remaining work. Be specific about state.]
- Issue #18 is ready-for-agent but not started
- PR #142 CI is red — needs diagnose (3 auto-fix attempts exhausted)
- Review on PR #143 flagged 2 blockers — needs human judgment

## Blockers requiring human input

[Only if the exit reason involves a human gate. Be specific about what
decision is needed, not just "needs human".]
- PR #142 review: reviewer asked whether we should use Strategy A or B
  for the caching layer. See review comment at [URL]. Pick one and
  the next session can proceed.

## Key decisions made

[Only include if decisions were made that a fresh agent needs to know.]
- Chose approach A over B because [reason] (see ADR-0004)

## Next steps

[Ordered list of what the next session should do.]
1. Resolve blocker on PR #142 (human decision needed first)
2. workflow-build-one on issue #18
3. watch-ci on PR #143

## Ready-to-use prompts

[For each actionable next step (not blocked on human input), a
prompt-builder output ready for copy-paste into Claude or Codex.]

### Issue #18 — [title]

[Full prompt-builder output here]

## Files to read first

[Paths the next agent should read to reconstruct context quickly.]
- docs/plans/2026-05-13-design.md
- docs/executions/handoffs/ (previous handoffs in this chain)
```

## Handoff chains

When a fresh session picks up a handoff and itself needs to hand off again, it should:

1. Read the previous handoff(s) in `docs/executions/handoffs/` to avoid repeating context
2. Reference the previous handoff by path rather than duplicating its content
3. Only document what changed since the last handoff

This keeps multi-session work from ballooning handoff size.

## Rules

- Do NOT duplicate content already in artifacts (PRDs, plans, ADRs, issues, commits). Reference by path or URL.
- Keep it under 200 lines. Compression, not transcription.
- Auto-handoffs from workflows should be factual and terse. No ceremony.
- If the exit reason is a blocker, be specific about what decision the human needs to make. "Needs human" alone is not actionable.
- For Codex targets: include full prompt-builder outputs. Codex cannot ask questions.
- For Claude targets: prompts can be lighter (Claude can ask the user).
- Always print the handoff file path as the last line of output.
