# Council Pattern — Long-form Reference

This is the full reference for council-style skills. The `SKILL.md` in this directory is the loadable summary; this document goes deep on dispatch mechanics, edge cases, and rationale.

## Why councils

A single LLM critique tends to converge on a "balanced" middle. A council forces disagreement to surface by dispatching independent subagents with named lenses. Each expert is a fresh context — no contamination from prior turns, no incentive to harmonize. The synthesis step preserves disagreement instead of erasing it.

Councils are useful when:

- The topic is a judgment call, not a fact lookup
- You want multiple priors stress-testing your thinking
- A single reviewer would miss a domain you don't know to ask about
- Disagreement itself is information

Councils are wrong when:

- The question has a single correct answer reachable by reading code or docs
- Speed matters more than depth (use `analysis-council --fast` or skip the council)
- You already know what you want to hear (council won't fix motivated reasoning)

## Round structure

### Round 1: lens pass

Every persona reads the topic and produces:

- Lens summary
- Challenges (HIGH / MED / LOW with damage × plausibility)
- What's not shown
- Falsifier

No persona sees any other persona's output in round 1 unless using **waves**.

### Round 2: response pass (default on)

Every persona sees all round-1 outputs and writes a `## Response to other experts` section. They may withdraw, sharpen, or escalate their original challenges. They may also concede.

Round 2 is **always parallel** — even in wave-based councils. Waves only apply to round 1.

### Round 3 (auto-recommended for feedback-rich topics)

When a council's `recommend_round_3` flag is set AND round 2 produced ≥3 fresh challenges, the orchestrator recommends running a third round. The user opts in.

## Waves (round-1 only, opt-in per council)

For councils where some personas depend on others' framing (e.g., military-strategist needs cartographer + economist + historian first), the roster declares:

```yaml
round_1_dispatch: waves
waves:
  - waveA: [anthropologist, cartographer, ecologist]
  - waveB: [economist, historian, theologian]
  - waveC: [political-scientist, linguist]
  - waveD: [military-strategist]
```

Orchestrator dispatches wave A in parallel, awaits all responses, then passes wave A outputs as context to wave B, and so on.

**Do not** use waves in analysis councils. Most analysis personas don't have meaningful order dependencies and waves add latency without payoff.

## Subagent dispatch

The orchestrator (running in the main session) calls the `Agent` tool once per persona per round. For round 1 parallel mode, all Agent calls go in a single tool-use message.

Example (round 1 parallel, 3 personas):

```
Agent(subagent_type="oh-my-claudecode:analyst", model="opus", prompt="<persona:skeptical-data-scientist inlined> + <topic>")
Agent(subagent_type="oh-my-claudecode:scientist", model="opus", prompt="<persona:statistician inlined> + <topic>")
Agent(subagent_type="oh-my-claudecode:critic", model="opus", prompt="<persona:counterfactual-check inlined> + <topic>")
```

All three run concurrently. The orchestrator does not write any analytical content during dispatch — only the synthesis step at the end.

## Synthesis

The orchestrator (NOT a subagent) reads all persona outputs and produces:

```markdown
# Council on: <topic>

## Synthesis
<≤8 lines. The hybrid read. Lead with what experts agreed on, then where they split.>

## Where experts disagreed
- <persona-A> argued <X>; <persona-B> argued <Y>. The crux is <Z>.
- ...

## What would change the picture
Bulleted falsifiers from across personas. The 3–5 most pivotal pieces of evidence to seek.

## Confidence: high | medium | low
<one sentence: where the confidence comes from, or what's still uncertain>

## Per-expert reads
### skeptical-data-scientist (confidence: high)
<their full markdown, 80-line cap>

### decision-scientist (confidence: medium)
<their full markdown, 80-line cap>

...
```

The synthesis **must not force consensus**. If experts split, the synthesis says so. Confidence drops when experts disagree on HIGH challenges.

## Persistence

Every council run writes:

- `.council/<sub>/<YYYY-MM-DD>-<slug>.md` — the full output above
- `.council/<sub>/<YYYY-MM-DD>-<slug>.json` — structured sidecar with persona list, model, tool counts, confidence, raw challenges

Slug is derived from the topic (kebab-case, first ~6 words). On collision, append `-v2`, `-v3`, etc.

Auto-`.gitignore` `.council/` on first write if `.gitignore` exists and doesn't already cover it.

Fallback: if cwd is not writable or not a project (no `.git`), write to `~/.council-sessions/<project-slug>/`.

## Post-process pipeline

Per-council, declared in `roster.yml`:

```yaml
post_process:
  humanizer: true                # strip AI patterns from the synthesis section
  domain_cleaner: null                    # or a domain-specific cleanup skill
```

Only the **synthesis** section runs through humanizer/cleaner. Per-expert sections preserve each persona's voice — that's the whole point.

Worldbuilding and narrative councils typically set both to `null` — preserving voice matters more than removing AI patterns there.

## Verify mode

Opt-in via `--verify` flag. When set:

- Each persona MAY use its declared `tool_access` (graphify queries, web_fetch, grep) to test ONE specific claim it raises.
- The persona's `## Verification` section records the test.
- Budget: ≤25 tool calls across the whole council, ≤$1.25 estimated, ≤5 min wall-clock.
- The orchestrator's synthesis weighs `[VERIFIED: <claim breaks>]` findings above lens-only disagreement.

Personas WITHOUT `tool_access` in their frontmatter cannot verify — they fall back to lens-only.

## Graphify integration

Two modes:

1. **Auto-detect** (default): if `graphify-out/` or `.council/graphify-out/` exists, the orchestrator mentions available graph queries in each persona's prompt. Personas may tag findings `[GRAPH]` when they used graph data.
2. **Forced** (`--graph`): orchestrator runs `graphify` on the topic input before dispatching round 1. The resulting graph is available to all personas with `tool_access: [graphify]`.

## Tuning per council

Use `roster.yml.overlays` to add council-specific guidance to a persona without forking the persona file:

```yaml
overlays:
  skeptical-data-scientist: |
    For this council, weight COPPA/child-data-privacy lenses heavily.
    Flag any analysis that depends on under-13 user data without parent consent context.
```

The overlay is appended to the persona's lens section at dispatch time.

## Failure modes

- **Persona times out** (subagent crashes / runs over budget): mark `status: timed_out` in its output, exclude from synthesis, note in `## Where experts disagreed` that this persona didn't return.
- **Round 2 produces no new content**: synthesizer notes "round 2 added no new challenges" and proceeds.
- **All personas concur**: that's a real signal — synthesis says so, confidence: high, and includes a brief "what would have to be true for this to be wrong" section.
- **Cannot persist** (read-only fs): write to `~/.council-sessions/` and tell the user.

## Composition with other skills

Councils consume from:

- `graphify` — knowledge graph context
- Topic inputs from `analysis-design`, `metric-design`, etc.

Councils feed into:

- `decision-memo` — turns a council output into an executive-ready memo
- `strategic-analysis-review` — reviews a memo that incorporated the council
- `humanizer` — already applied via post_process

Routing tiebreaker for users:

- "Challenge my thinking on X" → council
- "Is this claim right?" → council with `--fast`
- "Polish this memo" → `strategic-analysis-review` (not a council)
