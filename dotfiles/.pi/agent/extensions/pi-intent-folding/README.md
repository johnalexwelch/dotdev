# pi-intent-folding

Deterministic intent folding for Pi agents.

## Overview

Research-backed context compression system that preserves user intent across long-horizon agent runs. Based on 2026 academic findings (FoldAgent, SimpleMem, Anthropic production patterns).

## Status

**v0.1 Alpha** — YAML schema + TypeScript guards + compiler/linter + cost tracking

## Architecture

See `docs/research/2026-08-25-intent-folding-for-agents.md` (project root) for full research context.

### Core Components

1. **YAML Schema** (`schemas/intent-schema.yaml`) — Declarative intent definitions with fold triggers and guards
2. **TypeScript Guards** (`src/guards.ts`) — Runtime validation and hard/soft limit enforcement
3. **Validator/Linter** (`src/validator.ts`) — Schema validation CLI
4. **Cost Tracking** (`src/metrics.ts`) — FoldMetrics telemetry
5. **Pi Extension** (`src/index.ts`) — Hooks into Pi agent lifecycle

### Key Decisions

- **Single fold triggers** (not compound) — ADR-0003
- **Hard guards on context/cost, soft on turns** — DL-0004
- **Standardized + custom categories** — DL-0005
- **Fixed summary budget (2K tokens)** — DL-0006
- **Forward-compatible AtomicFact stub** — DL-0007

See `docs/decision-log.md` and `docs/adr/` (project root) for full decision context.

## Installation

```bash
cd dotfiles/.pi/agent/extensions/pi-intent-folding
npm install
npm run build
```

Pi will auto-load from `~/.pi/agent/extensions/` on next session.

## Usage

Create an intent YAML file:

```yaml
# .pi/intents/my-research-task.yaml
intent:
  id: research-deep-dive
  version: 1
  description: "Deep research with automatic folding"
  
  fold:
    trigger: token_threshold
    threshold: 24000
    preserve:
      - user_query
      - decisions
      - final_answer
    discard:
      - intermediate_tool_outputs
      - reasoning_traces
    summary_budget: 2000
    
  guards:
    max_context: 120000
    max_cost_usd: 5.00
    max_turns: 50
```

Validate:

```bash
npm run validate-schema -- .pi/intents/my-research-task.yaml
```

## Development

```bash
npm test           # Run tests
npm run build      # Compile TypeScript
npm run lint       # Lint source
```

## Roadmap

- **v0.1** (current): YAML + guards + validation + metrics
- **v0.2**: Diagnostic broker + SimpleMem integration + multi-intent support
- **v0.3**: CHORUS delegation + evidence tracking
- **v1**: LSP + policy engine + durable workflows

## References

- Research: `docs/research/2026-08-25-intent-folding-for-agents.md`
- Decisions: `docs/decision-log.md` (DL-0003 through DL-0008)
- ADRs: `docs/adr/0003-fold-trigger-single-not-compound.md`
- Context: `docs/CONTEXT.md` (Intent Folding concepts)
