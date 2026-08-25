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

Consumes: workflow-ledger run state — `ledger.sh show` / the branch's committed `docs/executions/runs/<run_id>.yaml` (primary source for run state / next steps when present), current conversation context, exit reason (manual, halt, completion), remaining work items
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

- `exit_reason`: why the workflow stopped. Use the canonical machine-readable vocabulary (shared with the relay runner, see "Relay" below): `complete`, `completion-with-follow-ups`, `halt-for-continuation` (includes halts for context limit), `needs-human` (pair with a NEEDS_HUMAN blocker description)
- `remaining_items`: list of concrete next steps
- `target_tool`: claude or codex (inferred from current environment if not specified)

The auto-handoff is silent — it writes the file and reports the path without ceremony.

## When workflows MUST auto-handoff

| Exit condition | Workflow(s) | What goes in the handoff |
|---------------|-------------|--------------------------|
| Halted: review needs human | workflow-deliver | Review findings, file paths, what the reviewer flagged |
| Halted: issue unclear | workflow-deliver | What's ambiguous, what question to ask |
| Halted: CI exhaustion (3 attempts) | workflow-finalize, watch-ci | CI logs, what was tried, diagnosis hint |
| Halted: needs-human diagnosis | workflow-deliver (kind=bug) | Diagnosis artifact path, reproduction steps |
| Halted: architecture-review needed | workflow-deliver (kind=bug) | Diagnosis findings, why it's architectural |
| Halted: unsafe-for-afk | workflow-deliver (kind=bug) | What makes it unsafe, what a human should verify |
| Completed with follow-ups | workflow-finalize | NEW-NN findings, follow-up issues created |
| Backlog run finished | run-backlog | Summary of results, failed issues, remaining queue |
| Codex task done | any (via prompt-builder) | What was done, PR link, anything that needs human review |

When workflows complete cleanly with NO remaining work, skip the handoff.

## Handoff storage

Always write **two copies** and always print **absolute paths** (never relative):

1. **Repo copy** — `docs/executions/handoffs/<date>-<slug>.md` (discoverable by next agent, commits with the branch).
2. **Global mirror** — `~/.chorus/handoffs/<repo-name>/<date>-<slug>.md`. Survives worktree destruction, so the handoff is recoverable even after the worktree is deleted.

Derive the absolute repo copy path with `git rev-parse --show-toplevel` (never assume cwd). **Derive `<repo-name>` separately** — it must stay STABLE across worktrees, so do NOT use `--show-toplevel` for it: under a git worktree that returns a transient slug (e.g. `worktree-brave-field-ff10`), and the mirror would land in a dir destroyed with the worktree — defeating its purpose. Use the main repo's common git dir instead:

```bash
agd=$(git rev-parse --absolute-git-dir)   # always absolute (git >=2.13); worktree-safe
repo=$(basename "${agd%%/.git*}")          # stable repo name, e.g. dotdev
```

Run this, read the LITERAL output, and hardcode it — do NOT pass `$repo`/`$agd` into `mkdir`/`cp` (see the shell-variable warning below). Create the global dir with `mkdir -p /Users/<you>/.chorus/handoffs/<repo-name>` — the home directory fully expanded (read it from `echo ~` output first if unsure) — and copy the file there after writing. Never pass a `~`-prefixed path to `mkdir`/`cp`: some bash tools (observed: pi's) do not tilde-expand, so `mkdir -p ~/.chorus/...` creates a literal `~/` directory skeleton inside the cwd (fake home trees were found in the chorus repo root and several `.herdr` worktrees this way).

**The path has two parts:** a STABLE group (`<repo-name>`, from git above — keeps a project's handoffs collocated) + a MEANINGFUL per-file slug (`<date>-<slug>`, where the slug is the work gist / caller arg, falling back to the branch name when no arg is given). Put "meaningful to the work" only in the slug, never in the group.

**Use fully literal absolute paths in the `mkdir -p` and `cp` commands — expand `~`, the repo-name, and the filename yourself before running.** Do NOT rely on `$HOME`, `$DEST`, or other shell variables/locals: the bash tool has been observed to expand them to empty strings, silently running `mkdir`/`cp` against `/` or with empty args. **Also do NOT use multi-line command blocks here: the bash tool has been observed to flatten newlines into spaces, so a `cp <src> <dst>` followed by a newline `ls -la <dst>` runs as one command `cp <src> <dst> ls -la <dst>` — creating a *directory* named `<dst>` with the file copied inside it.** Run `mkdir`, `cp`, and the verify as **separate single-line, `&&`-chained, literal-path** commands. Verify with `ls -la` of the literal mirror path afterward, and confirm it is a **file, not a directory** (a trailing `/` or a same-named child means the flatten bug bit — flatten it back with `mv`).

| Context | Repo copy | Global mirror | Why |
|---------|-----------|---------------|-----|
| Inside a project repo | `<repo-root>/docs/executions/handoffs/<date>-<slug>.md` | `~/.chorus/handoffs/<repo-name>/<date>-<slug>.md` | Repo copy is discoverable; mirror survives worktree deletion |
| No project / ephemeral | `mktemp -t handoff-XXXXXX.md` | `~/.chorus/handoffs/_ephemeral/<date>-<slug>.md` | Temp file printed to user; mirror is the durable copy |
| Codex task | `<repo-root>/docs/executions/handoffs/<date>-<slug>.md` committed to branch | `~/.chorus/handoffs/<repo-name>/<date>-<slug>.md` | Survives across Codex sessions and worktree teardown |

## Process

0. Recover run state, preferring the live ledger: `workflow-ledger/scripts/ledger.sh show` (the git-dir state is per-worktree and authoritative). If the kernel cannot run, read the active run's committed per-run snapshot `docs/executions/runs/<run_id>.yaml` (the file changed on this branch; newest by `git log` when several exist) — **but first, check whether the current branch is behind the verified workflow base** (the branch's merge-base against origin/main; this prevents stale state from a rebased or orphaned checkout). If behind, read the base copy instead: `git show $(git merge-base HEAD origin/main):docs/executions/runs/<run_id>.yaml`. Use its `workflow`, `steps`, and `next` as the source of truth for "Where we are" and "Next steps". Fall back to conversation context only when no run state exists. (`docs/executions/state.yaml` is a frozen legacy record — do not trust it for current state.)
1. Determine storage paths. Resolve the repo root with `git rev-parse --show-toplevel` and build the **absolute** repo-copy path from it. Set `repo-name` from the main repo's git dir (worktree-safe), NOT the toplevel: `agd=$(git rev-parse --absolute-git-dir); repo=$(basename "${agd%%/.git*}")`. Capture the literal value for the later mkdir/cp.
2. Determine exit context (manual vs auto, exit reason, remaining items).
2.5. **Live queue refresh** (only when the user explicitly asks "what's current?", "what's the latest?", or similar). Re-read open `ready-for-agent` issues from `gh issue list` and relevant PR merge states from `gh pr list --state open` for the active workflow. If the recorded run state (ledger / per-run snapshot) conflicts with what you see live (e.g., an issue is closed, or a PR is merged), emit an explicit **conflict note** in the handoff ("Issue #X shown as open in the run state but closed in gh; PR #Y merged since the snapshot was written") and use the live state as the source of truth for the handoff.
3. If remaining items include actionable next-step issues, invoke `prompt-builder` for each to generate ready-to-use prompts. Treat the `ready-for-agent` label as a signal, not a strict gate — an issue tagged only `type:task` (or unlabeled) that is otherwise clearly actionable still qualifies; use judgment rather than skipping it on label technicality.
4. Fill in the **Start here** directive (top of the document structure) with the real first next step and any open blocker.
5. **Pre-flight check before you send the next command**: does it contain a literal newline separating two commands (not `&&`)? Does it pair `mkdir` with a `cp`/`install` that reads the directory it just created? If either is yes, split it — do not send it as written. This has been observed to bite even immediately after reading this exact warning; treat it as a checklist, not context to skim.
   Write the handoff document to the repo copy, then `mkdir -p` the global dir and copy it to the global mirror. Copy **one file per command with fully literal paths**, and verify each with `ls` immediately after — shell wrappers can silently reorder or no-op a multi-target `mkdir`/`cp` (observed failure: a mangled `mkdir` created directories *named after* the handoff files). If `cp` misbehaves, `install -m644 <src> <dst>` is a reliable fallback.
   `mkdir` and the `cp`/`install` that follows it are **sequentially dependent, not independent** — the copy reads a directory the mkdir just created. Never issue them as parallel/batched tool calls in the same turn, even when the rest of that turn's calls are genuinely independent and can be batched. Run mkdir, then cp/install, then the ls verification, as three separate single-line tool calls, in that order.
6. Print BOTH absolute paths (repo copy + global mirror), then the paste line the user hands to the next session:
   `Resume: read <absolute-handoff-path> and follow "Start here".` Prefer the global mirror path in the Resume line since it outlives the worktree. If auto-invoked, keep the whole output to those lines.

## Handoff document structure

```text
# Handoff — [short title of current work]

Exit: [manual | halt: <reason> | completion with follow-ups | backlog run complete]
exit_reason: needs-human
[^ replace with exactly ONE value from the vocabulary in "Automatic (workflow exit)".
 The default is the fail-safe value on purpose: an unedited template must stop a
 relay, never report the work complete.
 Keep the vocabulary legend itself out of the handoff body: the relay's gate scan
 matches gate words anywhere in the file, so an echoed legend stops the loop.]
Target: [claude | codex | either]
Generated: [timestamp]

## Standing permissions / corrected policies

[ONLY if the current session includes workflow overrides or standing grants issued by the user. Explicit grants only, no inferred permissions. Scoped to named repos/issue-sets and the specific gate they waive. Examples: "AFK merge authority for #123 in [repo]" (waives reviewer-validation), "Skip [gate-name] for [condition]". Cannot waive secret-custody gates or a maintainer-decision gate; list only gates that CAN be waived. Omit this section if no overrides are in effect.]

## Start here (resuming agent)

This section makes the handoff self-executing: the next session only needs the
file path. Paste `Resume: read <this-path> and follow "Start here".` into a fresh
agent. Because this directive lives inside the handoff, it does NOT tell the agent
to "read this handoff" — it's already here.

> You are resuming multi-session work in `<repo>`. Recover state before acting:
>
> 0. **Work happens in `<absolute-work-repo-root>`.** `<if cwd ≠ the work repo — e.g.
>    you are resuming inside a different repo's git worktree:>` your cwd is NOT this
>    repo. `cd <absolute-work-repo-root>` first, and every `gh` call needs
>    `--repo <owner/slug>` (a bare `gh issue view` resolves against the cwd repo and
>    will hit the wrong project).
> 1. Recover run state — `workflow-ledger/scripts/ledger.sh show`, falling back to
>    the branch's committed `docs/executions/runs/<run_id>.yaml` — SOURCE OF TRUTH
>    for the active `workflow`, completed `steps`, and the `next` queue. Resume
>    from `next`; do not redo completed steps.
> 2. Read the paths under "Files to read first" (bottom of this doc) to rebuild context.
> `<if the next step is to work a specific issue/ticket — grill, decide, implement:>`
>    VERIFY it is still open before starting: `gh issue view <N> --repo <owner/slug> --json state,comments`.
>    This handoff is a proxy — a concurrent agent may have closed/resolved it since it was written.
>    If already CLOSED or carrying a resolution, STOP and reconcile (mirror the locked outcome), do not redo the work.
>
> Then do Next step 1: `<first next step>`. If the recorded run state and this doc
> disagree, the run state wins on run status.
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

## Sibling worktrees / concurrent sessions

[ONLY in a multi-worktree / parallel-agent context (e.g. herdr running several
worktrees at once). Name the sibling worktrees in flight and whether THIS
subtree depends on / is blocked by them — framed by WORKTREE, not just ticket
blockers, since the operator thinks in parallel sessions. Skip entirely for a
single-worktree session.]
- worktree-foo (#123): independent, no dependency.
- worktree-bar (#124): this subtree's report layer depends on it shipping first.

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
2. workflow-deliver on issue #18
3. watch-ci on PR #143

## Ready-to-use prompts

[For each actionable next step (not blocked on human input), a
prompt-builder output ready for copy-paste into Claude or Codex.]

### Issue #18 — [title]

[Full prompt-builder output here]

## Suggested skills

[Skills the next session should consider invoking, given what remains.]
- `workflow-deliver` (kind=bug) — PR #143 CI failure needs diagnosis
- `receive-review` — PR #142 has unresolved review comments

## Files to read first

[Paths the next agent should read to reconstruct context quickly. **Always ABSOLUTE paths** — the resuming session may run from a git worktree with a different cwd and cannot resolve repo-relative paths. Use URLs for issues/PRs. Prefer durable repo paths over session-scratch temp files — see Rules.]
- /Users/you/repo/docs/plans/2026-05-13-design.md
- /Users/you/repo/docs/executions/handoffs/ (previous handoffs in this chain)
```

## Handoff chains

When a fresh session picks up a handoff and itself needs to hand off again, it should:

1. Read the previous handoff(s) in `docs/executions/handoffs/` to avoid repeating context
2. Reference the previous handoff by path rather than duplicating its content
3. Only document what changed since the last handoff

This keeps multi-session work from ballooning handoff size.

## Relay (autonomous handoff chaining)

`workflow-ledger/scripts/relay.sh` automates handoff chains: headless legs read the handoff, continue the run, and rewrite it with an explicit `exit_reason:` line.

```bash
relay.sh --handoff <file> [--max-legs N=5] [--repo <path>]
```

Continues only on AFK-eligible exit_reasons (`completion-with-follow-ups`, `halt-for-continuation`). Stops on `complete`, NEEDS_HUMAN, missing exit_reason, max legs, or claude error.

## Rules

- Do NOT duplicate content already in artifacts (PRDs, plans, ADRs, issues, commits). Reference by path or URL.
- Prefer durable, repo-relative artifact paths over session-scratch temp files (e.g. `/tmp/...`, `/private/tmp/.../scratchpad/...`). If an artifact referenced in the handoff exists only as ephemeral scratch, either copy it into the repo (e.g. under `docs/executions/` or another suitable `docs/` subdir) before referencing it, or explicitly flag it as likely-gone and give the exact command to regenerate it.
- Redact any sensitive information before writing — API keys, passwords, tokens, and personally identifiable information must not appear in the handoff document.
- Do NOT record volatile environment/session state (active `gh`/CLI account, cwd, env vars, selected profile, temp paths) as settled fact — it is a proxy that may be stale by resume time. Emit an explicit verify-and-set step instead (e.g. `gh auth switch -u <user>` as step 1) so the resumer establishes the state rather than trusting a possibly-wrong assertion.
- Keep it under 200 lines. Compression, not transcription.
- Auto-handoffs from workflows should be factual and terse. No ceremony.
- If the exit reason is a blocker, be specific about what decision the human needs to make. "Needs human" alone is not actionable.
- For Codex targets: include full prompt-builder outputs. Codex cannot ask questions.
- For Claude targets: prompts can be lighter (Claude can ask the user).
- Always include the **Start here** directive near the top of the handoff, and print the `Resume: read <path> ...` paste line last. The user pastes the path, not the whole prompt. If no run state exists (no live ledger, no per-run snapshot), drop its step 1 and boot off "Files to read first" only. For Codex the directive must be self-contained (no "ask the user"); for Claude it may leave a decision to the user.
- Always print handoff paths as **absolute** paths (resolved via `git rev-parse --show-toplevel`), never relative. This applies to EVERY path in the body too ("Files to read first", "What was done", artifact references), not just the printed Resume line — repo-relative paths like `cora/docs/foo.md` do not resolve when the resumer's cwd is a different repo's worktree, which is the common case.
- When the handoff's cwd will differ from the work repo (e.g. the session runs inside another repo's worktree while the map/issues/code live elsewhere), the **Start here** directive MUST name the absolute work-repo root AND the required `gh --repo <owner/slug>` flag. Do not assume the resumer can infer the work repo from cwd — a bare `gh` call resolves against the cwd repo and silently targets the wrong project.
- Always write the global mirror under `~/.chorus/handoffs/<repo-name>/` so the handoff survives worktree destruction. Derive `<repo-name>` from `git rev-parse --absolute-git-dir` (strip `/.git*`, then basename) — never from `--show-toplevel`, which is a transient slug under worktrees.
- Always print the global mirror path as the last line of output (it is the durable reference).
- **Handoff files and checkout dirtiness**: A repo-copy handoff file at `docs/executions/handoffs/<date>-<slug>.md` makes the current checkout dirty (untracked) unless committed, .gitignore'd, or removed. If the user asked for a "clean primary" checkout or emphasized not mixing this session's artifacts with unrelated in-flight work, ASK before writing the repo copy: "This handoff file will create an untracked file in the repo. Shall I commit it to the branch, write mirror-only, or add it to .gitignore?" Respect the user's choice. For most sessions, the default (write both) is fine; this gate is for precision in environments where checkout state is tightly managed.
- **Env-assumption notes**: When origin is self-hosted (Forgejo/Gitea), state that `gh` won't work and name the right tool (`tea`, `curl`, raw API). Always include IP alongside LAN hostnames — the resuming machine may lack the `/etc/hosts` entry.
