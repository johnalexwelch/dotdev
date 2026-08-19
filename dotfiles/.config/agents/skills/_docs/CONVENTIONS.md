# Skills Corpus — Conventions

Author-facing rules for the personal skills corpus. See `decision-log.md` for the decisions behind them.

## Sub-skill invocation & resolution (D-003)

When one skill's step **is** another skill, follow these rules so the chain can't go hollow.

### 1. Invocation form

Use the explicit form:

```
Load and run `<name>/SKILL.md`        # for a workflow step
follow `<name>`                        # for a library/scaffold the skill builds on
```

Do **not** rely on flow-arrow prose (`grill-with-docs → to-prd → to-issues`) or a bare `/name` mention as the *invocation*. Arrows are a **map** — useful for the reader, but they don't tell the agent to load and run anything. Every arrow step that is a real skill must also have an explicit `Load and run` line in the steps.

### 2. Resolution

`<name>/SKILL.md` resolves against the **active skills root** (`~/.claude/skills` on a Claude host) — a single symlink to `~/.config/agents/skills`, with `~/dotdev/dotfiles/.config/agents/skills` (canon) as the source of truth behind it (stowed via `~/.config/agents`). A referenced skill must be **present in the active root**, not merely present in canon. A skill that exists in canon but isn't linked in (e.g. not yet stowed) is invisible at runtime — referencing it produces a hollow loop (an orchestrator that dies at a step it can't load).

### 3. Availability guard

`lint-skill-refs.sh [root]` checks every active skill's explicit refs resolve to other active skills, and exits non-zero on a dangling ref. Run it after adding a cross-skill reference or changing which skills are linked. It catches the failure class where a linked orchestrator references an unlinked sub-skill.

**Current coverage:** the lint only sees the explicit form (rule 1). Orchestrators still using arrow-only references are not yet checked — converting them to explicit refs (and linking their targets) is incremental cleanup the lint will drive.

## Output contract

User-facing skill output follows the ADHD communication contract (`~/.claude/output-styles/adhd.md`, canonical rules in the `i-have-adhd` skill); machine-facing artifacts (PR bodies, lane reviews, ledger evidence, handoffs targeted at agents) keep their own contracts and are exempt.

## Run-scoped artifact paths (D-006 Phase 5a)

Multi-agent runs MUST use run-scoped paths for shared artifacts — lane review files, probe scripts, PR-body drafts, anything one agent writes for another to read. Canonical shape (or a scratchpad subdirectory keyed by run id):

```text
/tmp/ledger-lanes-<run-id>/<artifact>
```

Never use bare shared paths like `/tmp/logic-review.md`: with parallel runs live, a bare path is cross-run bleed — a stale artifact from another run satisfies existence and content checks it was never part of (4 observed collisions on 2026-08-18). The kernel's review stamp accepts explicit lane paths via `--attest lanes=`; always pass run-scoped ones.
