# Token/context efficiency — baseline + optimization approach

Research asset for [ticket #74](https://github.com/johnalexwelch/dotdev/issues/74) (map [#68](https://github.com/johnalexwelch/dotdev/issues/68)). 2026-07-09. Includes FIND-26 (pi context-stack overlap).

## Question

Where does the token/context budget go during sessions, and what is the optimization approach? Establish a baseline, then rank the levers — and deconflict the pi context-stack (do not add).

## Baseline: where the budget goes

Two kinds of cost, and they behave very differently:

- **Fixed per-turn overhead** — paid on *every* LLM call, whether or not you use it: tool schemas, the skill listing, the system-prompt style/instruction blocks, package instruction text. This is the dominant lever because it multiplies across every turn.
- **Variable/growing** — messages, assistant thinking, tool calls, and tool results. Grows with the session; capped by compaction.

### The baseline instrument already exists — don't build one

`context-inspector` (`/context`) writes a local HTML donut/stacked-bar attributing the *current* session's context to: system prompt, **active tool-schema overhead**, user/assistant messages, thinking, tool calls, tool results, bash output, images, compaction summaries — plus top tools/paths and largest segments. It makes no network calls and adds nothing to model context. **That is the baseline measurement tool.** Exact numbers are session-specific, so the durable baseline is the *shape* below; run `/context` in a representative session for live attribution.

### Structural attribution (what's observable now)

- **Tool schemas are the largest fixed cost.** ~24 pi packages are installed and many register tools: pi-lens (~20 lens/ast tools), `taskflow`, `agent-browser` (its README alone is 77 KB; the tool schema is correspondingly huge — `electron`/`job`/`qa`/`semanticAction` variants), web-access, codemapper (5 tools), github-tools, pr-ally, triage, goal, ci/release helpers. Every one ships a JSON schema on every turn.
- **Skill listing** — ~93–98 skills under `~/.claude/skills` are listed by name + description in the system prompt. Bodies load on demand (only names cost per-turn). `cache-optimizer` already compresses this listing.
- **Style/wrapper blocks** — ponytail/caveman/rtk/toon (via `pix-optimizer`) add system-prompt bytes but *reduce* output + tool-result bytes; net positive across a multi-turn session.
- **Tool results** — the biggest variable consumer; `hypa` reduces shell/tool output deterministically at emit-time.

## Ranked levers

1. **Prune tool schemas (biggest fixed lever).** Unload packages whose tools a given session won't use. `agent-browser` + `taskflow` + the full lens suite are the heaviest schemas; a "lean" default profile that omits them, with a "full" profile for browser/orchestration work, cuts fixed per-turn cost the most. *This is the design-plan-worthy lever.*
2. **Deconflict overlapping compressors (FIND-26)** — see decision below. One removal (headroom), zero additions.
3. **Keep tool-result compression** — `hypa` (deterministic, local).
4. **Keep earlier compaction** — `context-cap` clamps effective window to 200k so pi compacts before the "dumb zone" (~183k).
5. **Keep prompt-cache hygiene** — `cache-optimizer` reorders stable content to front + compresses the skill listing → higher provider KV-cache hit rate.

## FIND-26 decision: deconflict the two suspected pairs

The audit flagged two "redundant pairs." Inspecting actual behavior: **one pair is genuinely redundant, one is not.**

| Pair | Redundant? | Decision | Why |
|---|---|---|---|
| `headroom` ↔ `hypa` | **Yes** | **Drop `headroom`, keep `hypa`** | Both reduce tool output. `hypa` is local, deterministic, testable, acts at command emit-time, no extra process. `headroom` is an *LLM* compressor behind a local proxy that needs `pip install "headroom-ai[proxy]"` + a running server on :8788 — nondeterministic, a privacy surface, and a fresh-Mac install liability (ties to #73 portability). Running both stacks a reactive re-compressor on already-reduced output. |
| `cache-optimizer` ↔ `pix-optimizer` | **No** | **Keep both** | Name-based pairing; mechanisms differ. `cache-optimizer` works the **input** side (provider KV/prompt-cache hit rate, system-prompt reordering, skill-listing compression). `pix-optimizer` works the **output** side (caveman/rtk/toon/ponytail verbosity toggles compressing model responses + tool-output wrappers). Complementary, not overlapping. |

**Resulting stack** (context-relevant packages): `context-cap`, `context-inspector`, `cache-optimizer`, `pix-optimizer`, `hypa` retained with distinct roles; **`headroom` removed.**

## Handoff

- **Immediate decision (this ticket):** drop `headroom` → one-line removal from `dotfiles/.pi/agent/settings.json` `packages[]`, mirrored to decision-log. Small enough to fold into the next settings edit; not its own build.
- **Deferred build (routes to `/design-plan` → `/execute-phase`):** session tool-schema profiles (lean vs full). This is lever #1 and the largest win; it's execution, not a frontier decision. #71 deferred the context-budget lever here (#74); #74 now hands lever #1 down the funnel.

## ponytail note

Skipped building any custom token-measurement tooling — `context-inspector`'s `/context` already attributes the budget. Add bespoke measurement only if `/context` proves insufficient for the profiling in lever #1.
