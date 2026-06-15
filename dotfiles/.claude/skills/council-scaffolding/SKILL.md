---
name: council-scaffolding
model: opus
reasoning: high
description: Foundational reference pattern for council-style skills. Loaded by sibling skills such as analysis-council, worldbuilding-council, metric-council, vendor-council, and narrative-council. Never invoked directly.
user-invocable: false
disable-model-invocation: true
---

# Council Scaffolding (Foundation)

## Model selection

Judgment personas and the synthesis run on **Opus** (persona `default_model: opus`); reserve **Sonnet/Haiku** for narrow, mechanical lenses. If the synthesis is delegated to a subagent rather than the main session, use **Opus**.


This skill is a **library**, not a workflow. Council skills (`analysis-council`, `worldbuilding-council`, etc.) reference it for shared mechanics. If you are invoking it directly, you probably want `analysis-council` instead.

## What a council is

A council assembles 2–5 named experts who each evaluate a topic through their lens, then synthesize their disagreements into a hybrid output. Each expert runs as a fresh subagent so its context is independent. Councils default to 2 rounds of debate (lens → response). Feedback-rich domains (worldbuilding, narrative) may use round-1 waves for sequential dependencies, then go fully parallel.

The pattern is built around three primitives:

1. **Persona** — a reusable expert definition in `_personas/<name>.md`
2. **Roster** — a council's `roster.yml` declaring required + optional personas, dispatch mode, post-process pipeline, and per-council overlays
3. **Synthesizer** — the council `SKILL.md` itself, which dispatches personas, runs rounds, and produces the final synthesis

Read `COUNCIL-PATTERN.md` for the full reference.

## Persona schema

Every `_personas/<name>.md` file uses this canonical frontmatter:

```yaml
---
name: <kebab-case-name>
description: <one-line lens summary>
default_subagent_type: oh-my-claudecode:analyst   # or :critic, :scientist, :architect, :writer, general-purpose
default_model: opus                                # or sonnet, haiku
tool_access:
  - graphify                                       # opt-in to knowledge graph
  - web_fetch                                      # opt-in to external research
context_dependencies:
  worldbuilding: [anthropologist, cartographer]    # personas that should run before this one in a given council
  analysis: []
---

# Voice
<2–4 sentences capturing the expert's posture, vocabulary, and what they are most allergic to>

# Lens
<bulleted list of 4–8 things this persona is always looking for>

# Anti-patterns
<bulleted list of 3–6 ways this persona fails — too-easy approvals, lens drift, over-reach>

# Falsifier prompt
<one sentence: "If <X>, then I withdraw my objection / change my read.">
```

## Output schema (per persona)

Every persona returns a markdown block with this header and these sections (sections may be omitted when empty):

```yaml
---
expert: <name>
confidence: high | medium | low
rounds_participated: 1
status: contributing | concluded | timed_out
---
```

```markdown
## Lens summary
One paragraph: what this expert is reading in the topic.

## Challenges
- **[HIGH]** <claim being challenged> — damage-if-true: <effect> × plausibility: <likelihood>
- **[MED]** ...
- **[LOW]** ...

## What's not shown
What this analysis omits, hides, or treats as obvious that this expert wouldn't grant.

## Falsifier
"I withdraw the HIGH challenge if <specific evidence or argument>."

## Verification  <!-- only when council was invoked with --verify -->
- Claim: <specific testable claim>
- Verified: yes | no | inconclusive
- Evidence: <links, tool output, grep result>

## Response to other experts  <!-- round 2+ only -->
Brief reply (≤80 lines) to specific points raised by other personas.
```

## Dispatch contract

A council orchestrator (the `SKILL.md` of `analysis-council`, etc.) does the following:

1. Load `roster.yml`. Resolve persona set:
   - `--fast` → use `required` only
   - default → `required` + smart-picked from `optional` (≤ `limits.max_experts`)
   - `--council <comma-list>` → user explicit
2. For each persona, dispatch a fresh subagent via the `Agent` tool using `persona.default_subagent_type` and `persona.default_model`. Inline the persona's voice/lens/anti-patterns into the subagent prompt.
3. **Round 1**:
   - If `round_1_dispatch: parallel` (default): dispatch all personas in a single message with multiple Agent tool uses.
   - If `round_1_dispatch: waves` (worldbuilding, narrative): dispatch wave A in parallel, await all, then dispatch wave B with wave A outputs as context, etc.
4. **Round 2** (when enabled): every persona runs in parallel with all round-1 outputs as context. Each persona writes a `## Response to other experts` section.
5. **Synthesize**: the orchestrator (running in the main session, *not* a subagent) reads all persona outputs and produces:
   - Headline synthesis (≤8 lines)
   - Disagreements section (what experts split on)
   - Per-expert sections, 80-line cap each
   - Confidence overall: derived from per-expert confidence + agreement
6. **Post-process**: run `humanizer` and the council's `domain_cleaner` (e.g., `slop-cleaner (analysis mode)`) per `post_process` config.
7. **Persist**: write to `.council/<sub>/<YYYY-MM-DD>-<slug>.md` with a JSON sidecar.

## Verify mode (`--verify`)

Opt-in. When set:
- Each persona may use its declared `tool_access` (graphify, web_fetch) to test ONE specific claim.
- Hard budget: ≤25 tool calls per council, ≤$1.25, ≤5 min wall-clock.
- A `[VERIFIED: <claim breaks>]` finding trumps lens-only disagreement during synthesis.

## Graphify integration

Auto-detect: if `graphify-out/` or `.council/graphify-out/` exists in the working directory, mention to personas and tag graph-sourced findings `[GRAPH]`. Opt-in `--graph` flag forces the council to run a graphify ingestion first.

## Persistence layout

```
.council/
├── analysis/        # analysis-council outputs
├── worldbuilding/   # worldbuilding-council outputs
├── metric/
├── vendor/
├── narrative/
├── graphify-out/    # shared knowledge graph
└── missions/        # narrative-purpose-guide outputs
```

In-project `.council/` is preferred; falls back to `~/.council-sessions/<project-slug>/`. Auto-`.gitignore` on first write.

## Contract

Consumes: persona definitions, roster.yml, topic
Produces: synthesis + per-expert sections + JSON sidecar, persisted to .council/<sub>/
Requires: subagent dispatch via Agent tool
Side effects: writes to .council/ in cwd or ~/.council-sessions/ fallback
Human gates: none by default — council is fire-and-read

## Context

Typical workflows: invoked by sibling council skills, not by users directly
Pairs well with: graphify, humanizer, slop-cleaner (analysis mode), slop-cleaner (docs mode)
