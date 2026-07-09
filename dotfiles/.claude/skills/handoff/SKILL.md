---
name: handoff
model: sonnet
reasoning: high
description: Compact the current conversation into a handoff document for another agent to pick up. Invoked manually ("handoff", "wrap up session") or automatically by any workflow that halts or completes with remaining work.
argument-hint: "What will the next session focus on?"
codex-compatible: true
---

# Handoff

Compress the current session into a handoff document so a fresh agent can continue without losing context. Works in two modes: manual (user-invoked) and automatic (workflow-invoked at exit points).

## Contract

Consumes: `docs/executions/state.yaml` (primary source for run state / next steps when present), current conversation context, exit reason (manual, halt, completion), remaining work items
Produces: handoff document at <repo-root>/docs/executions/handoffs/<date>-<slug>.md (persistent) mirrored to ~/.chorus/handoffs/<repo-name>/ (survives worktree teardown); paths always printed absolute
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

Always write **two copies** and always print **absolute paths** (never relative):

1. **Repo copy** — `docs/executions/handoffs/<date>-<slug>.md` (discoverable by next agent, commits with the branch).
2. **Global mirror** — `~/.chorus/handoffs/<repo-name>/<date>-<slug>.md`. Survives worktree destruction, so the handoff is recoverable even after the worktree is deleted.

Derive the absolute repo copy path with `git rev-parse --show-toplevel` (never assume cwd). Create the global dir with `mkdir -p ~/.chorus/handoffs/<repo-name>` and copy the file there after writing.

| Context | Repo copy | Global mirror | Why |
|---------|-----------|---------------|-----|
| Inside a project repo | `<repo-root>/docs/executions/handoffs/<date>-<slug>.md` | `~/.chorus/handoffs/<repo-name>/<date>-<slug>.md` | Repo copy is discoverable; mirror survives worktree deletion |
| No project / ephemeral | `mktemp -t handoff-XXXXXX.md` | `~/.chorus/handoffs/_ephemeral/<date>-<slug>.md` | Temp file printed to user; mirror is the durable copy |
| Codex task | `<repo-root>/docs/executions/handoffs/<date>-<slug>.md` committed to branch | `~/.chorus/handoffs/<repo-name>/<date>-<slug>.md` | Survives across Codex sessions and worktree teardown |

## Process

0. If `docs/executions/state.yaml` exists, read it first — use its `workflow`, `steps`, and `next` as the source of truth for "Where we are" and "Next steps". Fall back to conversation context only when the file is absent. Schema: `../_docs/state-cockpit.md`.
1. Determine storage paths. Resolve the repo root with `git rev-parse --show-toplevel` and build the **absolute** repo-copy path from it. Set `repo-name` to the basename of the repo root.
2. Determine exit context (manual vs auto, exit reason, remaining items).
3. If remaining items include ready-for-agent issues, invoke `prompt-builder` for each to generate ready-to-use prompts.
4. Fill in the **Start here** directive (top of the document structure) with the real first next step and any open blocker.
5. Write the handoff document to the repo copy, then `mkdir -p` the global dir and copy it to the global mirror.
6. Print BOTH absolute paths (repo copy + global mirror), then the paste line the user hands to the next session:
   `Resume: read <absolute-handoff-path> and follow "Start here".` Prefer the global mirror path in the Resume line since it outlives the worktree. If auto-invoked, keep the whole output to those lines.

## Handoff document structure

```text
# Handoff — [short title of current work]

Exit: [manual | halt: <reason> | completion with follow-ups | backlog run complete]
Target: [claude | codex | either]
Generated: [timestamp]

## Start here (resuming agent)

This section makes the handoff self-executing: the next session only needs the
file path. Paste `Resume: read <this-path> and follow "Start here".` into a fresh
agent. Because this directive lives inside the handoff, it does NOT tell the agent
to "read this handoff" — it's already here.

> You are resuming multi-session work in `<repo>`. Recover state before acting:
>
> 1. Read `docs/executions/state.yaml` if present — SOURCE OF TRUTH for the active
>    `workflow`, completed `steps`, and the `next` queue. Resume from `next`; do
>    not redo completed steps. (Schema: `skills/_docs/state-cockpit.md`.)
> 2. Read the paths under "Files to read first" (bottom of this doc) to rebuild context.
>
> Then do Next step 1: `<first next step>`. If `state.yaml` and this doc disagree,
> `state.yaml` wins on run status.
> `<if a blocker is open:>` STOP first and resolve: `<blocker + the decision needed>`.

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

## Suggested skills

[Skills the next session should consider invoking, given what remains.]
- `workflow-debug` — PR #143 CI failure needs diagnosis
- `receive-review` — PR #142 has unresolved review comments

## Files to read first

[Paths the next agent should read to reconstruct context quickly. **Always ABSOLUTE paths** — the resuming session may run from a git worktree with a different cwd and cannot resolve repo-relative paths. Use URLs for issues/PRs.]
- /Users/you/repo/docs/plans/2026-05-13-design.md
- /Users/you/repo/docs/executions/handoffs/ (previous handoffs in this chain)
```

## Handoff chains

When a fresh session picks up a handoff and itself needs to hand off again, it should:

1. Read the previous handoff(s) in `docs/executions/handoffs/` to avoid repeating context
2. Reference the previous handoff by path rather than duplicating its content
3. Only document what changed since the last handoff

This keeps multi-session work from ballooning handoff size.

## Rules

- Do NOT duplicate content already in artifacts (PRDs, plans, ADRs, issues, commits). Reference by path or URL.
- Redact any sensitive information before writing — API keys, passwords, tokens, and personally identifiable information must not appear in the handoff document.
- Keep it under 200 lines. Compression, not transcription.
- Auto-handoffs from workflows should be factual and terse. No ceremony.
- If the exit reason is a blocker, be specific about what decision the human needs to make. "Needs human" alone is not actionable.
- For Codex targets: include full prompt-builder outputs. Codex cannot ask questions.
- For Claude targets: prompts can be lighter (Claude can ask the user).
- Always include the **Start here** directive near the top of the handoff, and print the `Resume: read <path> ...` paste line last. The user pastes the path, not the whole prompt. If no `state.yaml` exists, drop its step 1 and boot off "Files to read first" only. For Codex the directive must be self-contained (no "ask the user"); for Claude it may leave a decision to the user.
- Always print handoff paths as **absolute** paths (resolved via `git rev-parse --show-toplevel`), never relative.
- Always write the global mirror under `~/.chorus/handoffs/<repo-name>/` so the handoff survives worktree destruction.
- Always print the global mirror path as the last line of output (it is the durable reference).
