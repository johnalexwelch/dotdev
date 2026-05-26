---
name: analysis-council
description: Convenes a council of 2–5 named experts (skeptical-data-scientist, decision-scientist, statistician, causal-reasoner, counterfactual-check, governance-reviewer, exec-audience-stand-in, ops-analyst, economist) to stress-test an analysis, claim, or piece of reasoning. Graph-first by default — auto-loads decision-history, prior-analysis, ADR, and codebase context from `graphify-out/` when present so experts see the analysis in context of prior work. Use when the user says "challenge my thinking," "what am I missing," "pressure-test this," "is this analysis right," "what would a skeptic say," or before any high-stakes analytical conclusion. Default skill for getting multiple expert priors on a judgment call. Supports --fast (2 personas, 1 round, for quick claim checks) and --verify (personas may test specific claims with tool access).
---

# Analysis Council

## Purpose

Run a multi-lens council on an analytical topic. Each persona is a fresh subagent with a named lens. The output is a synthesis that preserves disagreement, not a balanced summary.

This is the **daily-driver** skill for "challenge my thinking" and "what am I missing." It collapses what used to be `findings-interrogator`, `analysis-grill`, `counterfactual-check`, and `causal-review` into one entry point with modes.

## When to invoke

Invoke when the user says any of:
- "Challenge my thinking on X"
- "What am I missing here"
- "Pressure-test this"
- "Is this analysis right"
- "What would a skeptic / data scientist / decision scientist say"
- "Get me a second opinion on this read"
- "I want to challenge [a claim, a memo, an interpretation]"
- "Other opinions on this"

**Routing tiebreaker** with sibling skills:
- "Challenge my thinking" / "what am I missing" → **analysis-council** (default mode)
- "Is this single claim right?" / "fast check on X" → **analysis-council --fast**
- "Polish this memo" / "review this draft" → **strategic-analysis-review** (not a council)
- "Build me an analysis from scratch" → **analysis-design** then loop back to council

## Modes

| Mode | Personas | Rounds | When |
|------|---------|--------|------|
| `--fast` | required only (skeptical-data-scientist + decision-scientist) | 1 | Quick claim check, ~3 min |
| default | required + 2–3 from optional | 2 | "Challenge my thinking" — daily driver |
| `--council <names>` | user-specified | 2 | User wants specific experts |
| `--verify` | as above, plus tool access | 2 | Verify-mode adds graphify/web fetch claim-testing |
| `--graph` | as above | 2 | Force graphify ingestion before round 1 |
| `--round-3` | as above | 3 | When round 2 produced new challenges |

Modes can combine: `--fast --verify`, `--graph --council skeptical-data-scientist,statistician`.

## Process

### 1. Parse invocation

Read the user's prompt. Identify:
- The **topic**: claim, draft, analysis, interpretation being challenged
- The **mode flags**: `--fast`, `--verify`, `--graph`, `--council <list>`, `--round-3`
- The **stakes signal**: words like "high-stakes," "board," "promote this," "irreversible" → bias toward default or `--round-3`; words like "quick," "before EOD" → bias toward `--fast`

If the topic is unclear or the user is asking the council to do something a council can't do (e.g., write the analysis), say so and route them.

### 2. Resolve roster

Load `roster.yml`. Compute the persona set:
- Always include `roster.required`: `skeptical-data-scientist`, `decision-scientist`
- For default mode, smart-pick 2–3 from `roster.optional` based on topic keywords:
  - Causal language ("X causes Y", "drove the lift") → add `causal-reasoner`
  - Cohort / retention / segmentation / sample-size → add `statistician`
  - Counterfactual framing missing → add `counterfactual-check`
  - Child data / COPPA / privacy / GDPR / regulatory → add `governance-reviewer`
  - Board / ELT / executive audience → add `exec-audience-stand-in`
  - Operational / process / SLA → add `ops-analyst`
  - Money / unit economics / pricing / vendor → add `economist`
- For `--fast`: required only
- For `--council <list>`: user-specified (must include at least the 2 required)
- Cap at `roster.limits.max_experts`

### 2.5. Load context (GRAPH-FIRST — default behavior)

Auto-detect graphify-out in this order:
1. `.council/graphify-out/` in cwd
2. `graphify-out/` in cwd
3. `docs/graphify-out/`, `decisions/graphify-out/`

**If found (or `--graph` is passed)**:
- Extract entities from the topic: metric names, service names, project codenames, ADR numbers, person names, decision titles, prior analysis names.
- Query the graph for each entity. Pull: the entity's node, 1-hop neighbors, contradicting edges, related ADRs, prior decisions on the same question, related code modules.
- Bundle into a **context block** prefixed to every persona's dispatch prompt:
  ```
  ## Prior context (from knowledge graph)
  Entities in topic: <list>
  Related ADRs / decisions: <list with refs>
  Prior analyses on this question: <list>
  Related code modules / metrics / dashboards: <list>
  Contested or contradicted prior claims: <list>
  ```
- Tag any persona finding that builds on graph context as `[GRAPH]` in the synthesis.

**If no graph + no `--graph` flag**: skip context block. Add a one-line note in synthesis: "No knowledge graph detected — council reviewed without prior-decision context. Consider graphify on `docs/` or `decisions/` for richer priors."

**If `--no-graph` is passed**: force-skip even if graph exists. Useful for clean-slate review.

`--fast` mode: still loads graph if available, but only the headline entities (1-hop only).

### 3. Dispatch round 1 (parallel)

For each persona in the resolved set:
- Read `_personas/<name>.md`. Inline the Voice + Lens + Anti-patterns + Falsifier sections into the subagent prompt.
- Apply any matching `roster.overlays.<name>` text as additional council-specific guidance.
- If `--verify` and the persona has `tool_access`, mention the budget (≤25 tool calls total council-wide, ≤5 min wall-clock) and ask the persona to verify at most ONE specific claim.
- If `--graph` or `.council/graphify-out/` exists, mention available graph queries.

Dispatch all personas in a single message with multiple `Agent` tool calls (parallel). Use each persona's `default_subagent_type` and `default_model`.

Wait for all to complete.

### 4. Dispatch round 2 (parallel, unless `--fast`)

For each persona, dispatch a second subagent with:
- The same persona inlining
- All round-1 outputs as additional context
- Instruction: "Write a `## Response to other experts` section. Withdraw, sharpen, or escalate your round-1 challenges. ≤80 lines."

All in parallel.

### 5. Synthesize (in main session — NOT a subagent)

Read all persona outputs. Produce:

```markdown
# Council on: <topic>

## Synthesis
<≤8 lines. Hybrid read. What experts agreed on first, then where they split.>

## Where experts disagreed
- <persona-A> argued <X>; <persona-B> argued <Y>. The crux is <Z>.
- ...

## What would change the picture
- <falsifier 1>
- <falsifier 2>
- ...

## Confidence: high | medium | low
<one sentence justification: agreement level + per-expert confidence>

## Per-expert reads

### skeptical-data-scientist (confidence: high)
<their full markdown, 80-line cap>

### decision-scientist (confidence: medium)
<their full markdown, 80-line cap>

...
```

**Rules for synthesis:**
- Lead with what experts agreed on, then where they split.
- Do NOT force consensus. Disagreement is the output, not a failure.
- If a persona returned `[VERIFIED: <claim breaks>]`, that finding outranks lens-only disagreement.
- Confidence: `high` when ≥3 personas concur with `high` confidence on the headline; `low` when experts split on a HIGH challenge.

### 6. Post-process

Per `roster.yml.post_process`:
- If `humanizer: true`: run the **Synthesis** section through the `humanizer` skill. (Not the per-expert sections — those preserve voice.)
- If `domain_cleaner: analysis-slop-cleaner`: also run synthesis through it.

### 7. Persist

Write to:
- `.council/analysis/<YYYY-MM-DD>-<topic-slug>.md` — full markdown
- `.council/analysis/<YYYY-MM-DD>-<topic-slug>.json` — sidecar: personas, model, rounds, confidence, tool counts

If cwd is not a git repo or not writable: `~/.council-sessions/<project-slug>/analysis/...`.

Auto-`.gitignore` `.council/` on first write if `.gitignore` exists and doesn't already cover it.

### 8. Report back

Print to the user:
- The synthesis section
- One-line summary of disagreement (if any)
- File path of the persisted output
- If `--round-3` was recommended (round 2 produced ≥3 fresh challenges): say so and offer to run it.

## Contract

Consumes: topic (claim, draft, analysis, interpretation), mode flags, optional graphify-out/
Produces: council synthesis + per-expert reads, persisted to .council/analysis/
Requires: subagent dispatch via Agent tool, _personas/, _council-scaffolding/
Side effects: writes to .council/analysis/ in cwd or ~/.council-sessions/ fallback
Human gates: none — fire-and-read by design

Runtime requirement: at least 2 personas must return successfully. If fewer, report failure and skip persistence.

## Context

Typical workflows: pre-memo stress-test, claim verification, "challenge my thinking" sessions, pre-board prep
Pairs well with: graphify (knowledge graph input), decision-memo (downstream), strategic-analysis-review (memo review of council output), humanizer (post-process), analysis-slop-cleaner (post-process)

Reference: see sibling `_council-scaffolding/COUNCIL-PATTERN.md` for the full pattern reference (waves, verify mode, persistence layout, failure modes).
