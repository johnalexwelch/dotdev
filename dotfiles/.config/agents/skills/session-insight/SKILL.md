---
name: session-insight
model: sonnet
reasoning: medium
description: Reflect on the current session's META (how the work was done, not what was built) and propose concrete, evidence-backed improvements to skills, CLAUDE.md, and workflows — including capturing a repeatable workflow from the session as a skill-draft proposal (the skillify job). Use at end of session, after a rough patch, or when the user says "reflect", "what did we learn", "how could this have gone better", "improve the skills based on this", "skillify", or "turn this into a skill".
codex-compatible: true
---

# Session Insight

## Purpose

Forward-looking, proactive reflection loop. Complements `workflow-effectiveness-audit`
(which is backward-looking, failure-gated, and compliance-focused across many
transcripts). This skill runs on a *single* session — including a smooth one — and
turns lived friction into durable improvements to the skill system.

- Audit answers: "were the skills obeyed?" (evidence-gated, needs a failure)
- Insight answers: "should the skills change?" (fires on any session, including clumsy-but-successful)
- Insight also **extracts**: when a repeatable workflow emerges, capture it as a skill-draft proposal (the skillify job) so it lands in the reflection file instead of evaporating.

## Contract

Consumes: the current session transcript, `~/dotdev/dotfiles/.config/agents/skills/` (canonical Stow source in this repo)
Produces: a persisted reflection at `~/dotdev/docs/executions/reflections/<date>-<slug>.md` plus a prioritized, diff-shaped improvement list
Requires: nothing (stdlib/native only — keeps `codex-compatible: true`)
Side effects: writes a reflection file under `~/dotdev/docs/executions/reflections/`; NEVER edits skills without approval
Human gates: approval before editing any skill, `docs/agents/habits.md` (or other durable agent docs), or creating issues

## Context

Typical use: end-of-session, post-correction, weekly personal retro
Pairs well with: workflow-effectiveness-audit (heavy governance sweep), write-a-skill
(when a lesson becomes a new skill), workflow-router (ROUTER_LEARNING_NOTE feeds this)

## Process

### 1. Analyze the session (META, not output)

**Pass A — what happened.** Review the conversation and identify:
- Problem-solving approach; tool-usage patterns (right tool? used well?)
- Clarifications, iterations, pivots, backtracking
- **Corrections**: every time the user redirected the agent — the strongest signal
- **Ground-truth vs proxy**: did the agent trust a proxy (spec/charter doc, git ancestry, cached or assumed state) instead of the authoritative source (running code/tests, PR/API state, a live check)? When a proxy and the authoritative source disagree, the authoritative source wins. Flag any conflict classified as blocking or resolved from a proxy before the code/state was checked. **When resuming a handoff that proposes a code/skill fix, re-run the fix in its edge contexts (subdirectory, worktree, no-arg) before applying — the proposing session's "proof it works" is a proxy and may have tested only the happy path.**

**Pass B — improvement hunt (fires even with zero failures/corrections).** A smooth session can still expose better skills. Scan for all of these:
- **Friction**: anything clumsy, slow, verbose, or repetitive — even where it *worked* and the user never complained. Manual steps that could be a skill affordance; re-derived context; awkward tool sequences.
- **Enhancement**: an existing skill did its job but could do it better — a missing default, a helpful check, a sharper output shape, a faster path.
- **Gap**: work that had **no owning skill**, or a skill that silently didn't cover the case that arose. Name the narrowest skill that *should* own it (or flag a `write-a-skill` candidate — but only for a genuinely repeatable pattern, not a one-off).
- **Ambiguity**: wording in a skill that *could* be misread or that permitted a wrong turn — whether or not it caused a problem this session. Ambiguity is a finding on its own; it need not have already failed.
- **Better way found**: did an improvised workflow, ad-hoc technique, tool, or deviation from the usual skill **outperform the established approach**? This is a positive discovery, not a failure — the standard worked, but something worked *better*. Capture (a) what was tried, (b) what made it better (faster, cleaner, fewer steps, safer, higher quality), and (c) the trigger conditions under which it wins. Route it: fold into the owning skill if it refines an existing flow, or flag a `write-a-skill` candidate if it is a genuinely new repeatable pattern. Do not formalize a lucky one-off — require a plausible repeat.
- **Skill extraction (skillify)**: did the session accomplish a repeatable multi-step workflow worth capturing as its *own* new skill? A Gap or a Better-way-found often is one. When it clears the quality gate below, don't leave it as a one-line flag — capture the full draft payload (see Skill Extraction Candidates) so the downstream backlog can act on it without re-deriving the session.

**Skill-extraction quality gate** — before proposing any *new* skill, require all three true (else it's documentation or a one-off, not a skill):
- "Could someone Google this in 5 minutes?" → **No**
- "Is it specific to this codebase, project, or workflow?" → **Yes**
- "Did it take real debugging, design, or operational effort to discover?" → **Yes**

A correction is the strongest signal, but it is not the only one. Report improvement opportunities from Pass B even when nothing went wrong.

### 2. Assemble the reflection (persisted by default)

Write a reflection file by default so insights accumulate for cross-session
analysis and macro-pattern review.

Default path:

`~/dotdev/docs/executions/reflections/<date>-<slug>.md`

Naming:

- `<date>` = `YYYY-MM-DD`
- `<slug>` = 2-6 word kebab gist, stable and descriptive enough for later audits

Also present a concise inline summary in the response so users can approve
follow-up changes without opening the file first.

Structure (for the persisted file and inline summary):

```markdown
# Session Reflection: <title>
**Date**: YYYY-MM-DD
**Goal**: <one line>

## What Went Well
- <technique / tool use / communication pattern that worked>

## What Went Wrong / Friction
- <approach that stalled, tool misuse, avoidable iteration>

## Corrections
| # | What the user corrected | Root cause | Owning skill/file |
| 1 | ... | ... | <narrowest skill that owns it> |

## Lessons
1. **<title>**: <insight + why it matters>

## Proposed Improvements
- [ ] `<file>` — <specific, diff-shaped change> (priority: high|med|low)

## Skill Extraction Candidates
<!-- only when a repeatable workflow passed the quality gate; omit the section entirely otherwise -->
- **Proposed skill**: `<name>` · **target**: `<path/location>` · **invocation**: model|user
  - **Trigger / leading word**: <what should invoke it>
  - **Inputs**: <what it consumes>
  - **Steps**: <ordered; each with a checkable completion criterion>
  - **Success criteria**: <observable done-state>
  - **Constraints / pitfalls**: <gotchas discovered this session>
  - **Verification evidence**: <what proved it worked this session>
  - **Quality gate**: googleable=No · specific=Yes · real-effort=Yes
  - **Open questions**: <anything too fuzzy to encode yet>
```

### 3. Route improvements to the NARROWEST owner

- Change the single skill that owns the failure, not every workflow that touched it
  (e.g. unresolved PR comments → `receive-review`, not every delivery skill).
- A repeated conversational correction → the skill whose wording allowed it.
- A genuinely new repeatable multi-step pattern → recommend `write-a-skill`, don't inline it.
- Do NOT propose abstractions for a one-off. Premature generalization is a finding, not a fix.

### 4. Respect the Stow + Codex seam (hard rules)

- Edits target the **canonical source**: `~/dotdev/dotfiles/.config/agents/skills/<name>/SKILL.md`.
  Dotdev canonical skills live only under `.config/agents/skills`. Editing `~/.claude/skills/` (the runtime mirror, not the dotfiles source) directly is a known defect (audit gap #19) — never do it.
  The **git repo root is `~/dotdev`, not `~/dotdev/dotfiles`** (dotfiles is a subdir). So `git add`/`git commit` the edit as `dotfiles/.config/agents/skills/<name>/SKILL.md` from the repo root, or `cd ~/dotdev/dotfiles` first — a bare `.config/agents/skills/...` pathspec from the root fails ("pathspec did not match").
- After an approved edit, remind: run `~/dotdev/dotfiles/.config/agents/skills/sync-codex-skills.sh --apply`
  to mirror into `~/.codex/skills`. Do not invoke via `~/.claude/skills/…` — that path may be a broken symlink.
- If a proposed skill needs MCP or interactive tools, set `codex-compatible: false`
  in its frontmatter (audit gap #20).

### 5. Present, then STOP

Output the reflection + the improvement list. Do not edit skills, edit `docs/agents/habits.md` / CLAUDE.md / AGENTS.md,
or create issues until the user approves the specific change list. For durable agent policy, prefer `docs/agents/habits.md`
over the OpenWiki-managed stubs.

## Rules

- Every proposed change cites session evidence (a quote, a correction, a stalled step).
- Be honest and specific; vague reflections aren't actionable.
- Cost consciousness: this skill is overhead. Keep the reflection tight — quality over length.
- Skip empty sections. A session with no friction **and** no Pass-B improvement opportunity gets a two-line reflection and no changes. Absence of a *correction* is not absence of an *opportunity* — still run Pass B.
- Never simplify away the approval gate before touching skills.
