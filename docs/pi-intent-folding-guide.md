# Pi Intent Folding — Complete Guide

Deterministic context compression for long-horizon Pi agent tasks. Research-backed, cost-tracked, and ready for production use.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Configuration Guide](#configuration-guide)
- [Usage Examples](#usage-examples)
- [API Reference](#api-reference)
- [Integration with Pi](#integration-with-pi)
- [Troubleshooting](#troubleshooting)
- [References](#references)

---

## Overview

### What is Intent Folding?

Intent folding is a context compression technique that preserves user intent while discarding verbose intermediate state. When an agent task grows too large (tokens, cost, or turns), the system automatically summarizes the conversation history into a compact form that retains:

- The original user query
- Key decisions and rationale
- Final answers or deliverables
- Critical context for continuation

This reduces token consumption by **30-fold** (per SimpleMem research) while maintaining task performance.

### Why Use It?

**Problem:** Long-horizon agent tasks (research, multi-file refactoring, iterative debugging) hit context window limits, burn tokens, and degrade performance.

**Solution:** Fold intermediate work into a summary when thresholds are reached. The agent continues with a clean context window and the compressed history.

**Benefits:**

- **Cost control:** Hard guard at `max_cost_usd` prevents runaway token burn
- **Context efficiency:** Stay within `max_context` limits without losing critical information
- **Deterministic:** YAML configuration makes folding behavior explicit and auditable
- **Research-backed:** Based on FoldAgent (62% BrowseComp-Plus) and SimpleMem (26.4% F1 improvement)

### Version

**Current:** v0.1 Alpha

- ✅ YAML schema + TypeScript guards
- ✅ Validator CLI
- ✅ Metrics/telemetry
- ✅ Pi extension lifecycle hook
- ✅ **Enforcement layer (v0.1.1)**:
  - Runtime telemetry (audit trail)
  - Audit CLI (post-session verification)
  - Pre-flight check (intent requirement detection)
  - CI gate (PR enforcement)

**Upcoming:** v0.2 (diagnostic broker), v0.3 (CHORUS integration), v1 (LSP + policy engine)

---

## Architecture

### Components

```
pi-intent-folding/
├── src/
│   ├── schema.ts       # Zod schema for intent YAML
│   ├── guards.ts       # Runtime validation + hard/soft limits
│   ├── metrics.ts      # FoldMetrics telemetry
│   ├── validator.ts    # CLI validation tool
│   └── index.ts        # Pi extension entry point
├── test/               # 60 tests (TDD)
└── schemas/            # Example YAML configs
```

### Flow

```
1. Agent starts task with intent YAML
2. Extension hooks into Pi session lifecycle
3. Guards monitor: tokens, cost, turns
4. Trigger fires (e.g., token_threshold: 24000)
5. Fold executes:
   - Preserve: user_query, decisions, final_answer
   - Discard: intermediate_tool_outputs, reasoning_traces
   - Summary: 2000-token compressed context
6. Agent continues with clean context + summary
7. Metrics exported (JSON/CSV)
```

### Data Flow

```
User Intent YAML
       ↓
   schema.ts (Zod validation)
       ↓
   guards.ts (runtime checks)
       ↓
   Pi session lifecycle
       ↓
   Trigger evaluation (tokens/turns/explicit)
       ↓
   Fold execution (preserve/discard/summarize)
       ↓
   metrics.ts (telemetry)
       ↓
   Continue or halt
```

---

## Quick Start

### Installation

Extension is already installed via symlink:

```bash
~/.pi/agent/extensions/pi-intent-folding -> ~/dotdev/dotfiles/.pi/agent/extensions/pi-intent-folding
```

Pi auto-loads it on session start.

### Your First Intent

Create `.pi/intents/research-task.yaml`:

```yaml
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

### Validate

```bash
cd ~/.pi/agent/extensions/pi-intent-folding
npm run validate-schema -- ~/.pi/intents/research-task.yaml
```

Output:

```
✅ Intent schema valid: research-deep-dive (v1)
📊 Guards: max_context=120000, max_cost_usd=5.00, max_turns=50 (soft)
🔀 Trigger: token_threshold @ 24000
✨ Ready for Pi session
```

### Run

Start Pi with the intent:

```bash
pi --intent ~/.pi/intents/research-task.yaml
```

The extension monitors the session and folds automatically when the threshold is reached.

---

## Configuration Guide

### Intent YAML Schema

#### Top-Level Structure

```yaml
intent:
  id: string                    # Required: unique identifier
  version: number               # Required: schema version (currently 1)
  description: string           # Required: human-readable purpose

  fold:                         # Required: fold configuration
    trigger: string             # Required: token_threshold | turn_count | explicit
    threshold: number           # Required (token_threshold/turn_count only)
    preserve: string[]          # Required: categories to keep
    discard: string[]           # Optional: categories to drop
    custom_preserve: string[]   # Optional: custom categories
    custom_discard: string[]    # Optional: custom categories
    summary_budget: number      # Required: max tokens for summary (default: 2000)

  guards:                       # Required: safety limits
    max_context: number         # Required: hard limit (blocks task)
    max_cost_usd: number        # Required: hard limit (blocks task)
    max_turns: number           # Optional: soft limit (warns only)
```

#### Fold Triggers

**1. `token_threshold`** — Fold when conversation exceeds N tokens

```yaml
fold:
  trigger: token_threshold
  threshold: 24000    # Fold at 24K tokens
```

**2. `turn_count`** — Fold after N agent turns

```yaml
fold:
  trigger: turn_count
  threshold: 20       # Fold after 20 turns
```

**3. `explicit`** — Manual fold via agent command (no auto-trigger)

```yaml
fold:
  trigger: explicit   # No threshold; agent calls fold manually
```

#### Preserve/Discard Categories

**Standardized categories:**

- `user_query` — Original user request
- `decisions` — Architectural/design decisions
- `final_answer` — Deliverables, conclusions, results
- `intermediate_tool_outputs` — Tool call results mid-task
- `reasoning_traces` — Agent thinking/planning steps
- `context_dumps` — Large data snapshots (e.g., file contents)
- `error_recovery` — Failed attempts and fixes

**Custom categories:**

```yaml
fold:
  preserve:
    - user_query
    - decisions
  custom_preserve:
    - "api_contracts"       # Your domain-specific category
    - "performance_metrics"
```

#### Guards

**Hard guards** (block task on violation):

- `max_context` — Total tokens (default model window)
- `max_cost_usd` — Dollar cost ceiling

**Soft guards** (warn but continue):

- `max_turns` — Turn count (useful for detecting loops)

```yaml
guards:
  max_context: 120000     # Hard: fail if exceeded
  max_cost_usd: 5.00      # Hard: fail if exceeded
  max_turns: 100          # Soft: warn only
```

#### Summary Budget

Fixed at 2000 tokens (v0.1). Controls fold output size.

```yaml
fold:
  summary_budget: 2000
```

**Rationale:** SimpleMem research shows 2K tokens retain decision-critical info while achieving 30× compression.

---

## Usage Examples

### Example 1: Research Task with Cost Cap

**Goal:** Deep research on agent architectures, cap at $3 USD.

```yaml
intent:
  id: research-agent-architectures
  version: 1
  description: "Survey 2026 agent architectures with cost control"

  fold:
    trigger: token_threshold
    threshold: 32000
    preserve:
      - user_query
      - decisions
      - final_answer
    discard:
      - intermediate_tool_outputs
      - reasoning_traces
    summary_budget: 2000

  guards:
    max_context: 128000
    max_cost_usd: 3.00
    max_turns: 40
```

**Behavior:**

- Folds at 32K tokens → compresses to 2K summary
- Hard stop at $3.00 or 128K tokens
- Warns at 40 turns (soft limit)

### Example 2: Multi-File Refactoring with Turn Guard

**Goal:** Refactor authentication logic across 15 files, prevent infinite loops.

```yaml
intent:
  id: refactor-auth-layer
  version: 1
  description: "Multi-file auth refactor with loop detection"

  fold:
    trigger: token_threshold
    threshold: 48000
    preserve:
      - user_query
      - decisions
      - final_answer
    discard:
      - intermediate_tool_outputs
      - context_dumps
    custom_preserve:
      - "api_contracts"       # Keep interface definitions
      - "test_coverage_delta"  # Track test changes
    summary_budget: 2000

  guards:
    max_context: 200000
    max_cost_usd: 8.00
    max_turns: 60          # Soft: flag potential loops
```

**Behavior:**

- Folds at 48K tokens
- Preserves API contracts (custom category)
- Warns if turns exceed 60 (loop detection)

### Example 3: Explicit Fold for Checkpoint

**Goal:** Agent-controlled folding at natural breakpoints.

```yaml
intent:
  id: staged-migration
  version: 1
  description: "Database migration with manual checkpoints"

  fold:
    trigger: explicit       # No auto-fold
    preserve:
      - user_query
      - decisions
      - final_answer
    discard:
      - intermediate_tool_outputs
      - reasoning_traces
    summary_budget: 2000

  guards:
    max_context: 150000
    max_cost_usd: 10.00
    max_turns: 80
```

**Behavior:**

- Agent calls fold after each migration stage
- Guards still enforce hard limits

---

## API Reference

### TypeScript Types

```typescript
import type { Intent, FoldTrigger, GuardConfig } from 'pi-intent-folding';

interface Intent {
  id: string;
  version: number;
  description: string;
  fold: FoldConfig;
  guards: GuardConfig;
}

interface FoldConfig {
  trigger: 'token_threshold' | 'turn_count' | 'explicit';
  threshold?: number;
  preserve: string[];
  discard?: string[];
  custom_preserve?: string[];
  custom_discard?: string[];
  summary_budget: number;
}

interface GuardConfig {
  max_context: number;
  max_cost_usd: number;
  max_turns?: number;
}
```

### Runtime Guards

```typescript
import { validateGuards, type GuardResult } from 'pi-intent-folding/guards';

const result: GuardResult = validateGuards(intent, {
  current_tokens: 95000,
  current_cost_usd: 4.50,
  current_turns: 45,
  model: 'anthropic/claude-sonnet-4-20250514'
});

if (!result.passed) {
  console.error(result.violations);  // Array of GuardViolation
}
```

### Metrics

```typescript
import { FoldMetrics } from 'pi-intent-folding/metrics';

const metrics = new FoldMetrics(intent);

metrics.recordTokens(before, after);
metrics.recordCost(before_usd, after_usd, model);
metrics.recordTurns(before, after);

// Export
console.log(metrics.toJSON());
fs.writeFileSync('fold-metrics.csv', metrics.toCSV());
```

**Metrics Schema:**

```typescript
interface FoldMetricsData {
  intent_id: string;
  intent_version: number;
  trigger_type: string;
  tokens_before_fold: number;
  tokens_after_fold: number;
  tokens_saved: number;
  cost_before_usd: number;
  cost_after_usd: number;
  cost_saved_usd: number;
  turns_before_fold: number;
  turns_after_fold: number;
  model: string;
  timestamp: string;
}
```

### Validator CLI

```bash
# Validate single intent
npm run validate-schema -- path/to/intent.yaml

# Validate all intents in directory
find ~/.pi/intents -name "*.yaml" -exec npm run validate-schema -- {} \;
```

---

## Integration with Pi

### Extension Lifecycle

The extension hooks into Pi's session lifecycle:

```typescript
// src/index.ts (simplified)
export default function (pi: ExtensionAPI) {
  pi.on('session_start', (event, ctx) => {
    const intentPath = ctx.args.intent;
    if (!intentPath) return;

    const intent = loadIntent(intentPath);
    validateIntent(intent);

    ctx.session.intent = intent;
  });

  pi.on('turn_complete', (event, ctx) => {
    const usage = ctx.getContextUsage();
    const guardResult = validateGuards(ctx.session.intent, usage);

    if (!guardResult.passed) {
      throw new GuardViolationError(guardResult.violations);
    }

    if (shouldFold(ctx.session.intent, usage)) {
      executeFold(ctx);
    }
  });
}
```

### Pi CLI Integration

**Start session with intent:**

```bash
pi --intent ~/.pi/intents/research-task.yaml
```

**Check active intent:**

```bash
# Inside Pi session
/intent status
```

**Manual fold (explicit trigger):**

```bash
# Inside Pi session
/fold now
```

---

## Enforcement

### How Agents Are Required to Use This

v0.1.1 adds **hard enforcement** so intent folding isn't optional for qualifying tasks:

#### 1. Runtime Telemetry

Every session logs to `~/.pi/sessions/<session-id>/intent-events.jsonl`:

```jsonl
{"timestamp":"2026-08-25T...","event":"intent_loaded","intent_id":"research-task",...}
{"timestamp":"2026-08-25T...","event":"guard_check","tokens":15000,"passed":true}
{"timestamp":"2026-08-25T...","event":"fold_triggered","trigger":"token_threshold",...}
{"timestamp":"2026-08-25T...","event":"fold_executed","tokens_saved":8000,...}
```

**Audit trail proves:**

- Intent was loaded
- Guards were checked every turn
- Folds executed when triggered
- Violations recorded

#### 2. Audit CLI

Post-session verification:

```bash
cd ~/.pi/agent/extensions/pi-intent-folding
npm run audit -- <session-id> [--require-intent]
```

**Output:**

```
✅ Session compliant (intent: research-task, 2 fold(s))

Details:
  Intent loaded: ✅
  Intent ID: research-task
  Guard checks: 45
  Guard violations: 0
  Folds executed: 2
  Total events: 52
```

**Exit codes:**

- 0: Compliant
- 1: No intent (when required)
- 2: Guard violations
- 3: Malformed telemetry

#### 3. Pre-flight Check

Detect if intent is required BEFORE starting:

```bash
npm run preflight -- "research agent architectures"
```

**Output:**

```
❌ Intent required but missing: Research tasks typically grow large

Matched patterns:
  - Research tasks typically grow large and benefit from folding
    Examples: deep research on X, investigate issue Y, survey existing solutions

Create an intent YAML with fold triggers and guards, then use:
  pi --intent path/to/intent.yaml
```

**Requiring patterns:**

- Research/investigation/survey keywords
- Multi-file refactoring (>10 files)
- Comprehensive/exhaustive work
- Explicit budget mentions ($X USD)

#### 4. CI Gate

GitHub Actions workflow `.github/workflows/verify-intent-evidence.yml` blocks PRs that:

- Add/modify research docs
- Change >10 files
- Mention research/investigation/migration in title/body

**Requires ONE of:**

1. `intent_id:` in `docs/executions/handoffs/*.md`
2. `Intent:` line in PR body
3. `.pi/intents/*.yaml` file in PR

**Example failure:**

```
🛑 INTENT EVIDENCE REQUIRED

This PR requires intent folding evidence because:
  - Research/investigation work, multi-file changes,
    or comprehensive task

To fix, add ONE of:
  1. intent_id: <id> in docs/executions/handoffs/<file>.md
  2. Intent: <name> line in PR body
  3. Include .pi/intents/<name>.yaml in the PR
```

### Enforcement Summary

| Layer | What | When | Blocking |
|-------|------|------|----------|
| **Pre-flight** | Detect if intent required | Before session start | Advisory |
| **Runtime** | Log all events | During session | No (telemetry) |
| **Audit** | Verify compliance | After session | Yes (exit code) |
| **CI** | Check PR evidence | Before merge | Yes (blocks merge) |

**Result:** Agents can't bypass intent folding for qualifying tasks. Cost/context guards are enforced, not suggested.

---

## Troubleshooting

### Error: Intent schema validation failed

**Cause:** YAML syntax error or missing required fields.

**Fix:**

```bash
npm run validate-schema -- path/to/intent.yaml
```

Check error output for specific field violations.

### Error: GuardViolation: max_cost_usd exceeded

**Cause:** Task cost surpassed hard limit.

**Fix:**

1. Increase `max_cost_usd` in intent YAML
2. Lower `threshold` to fold earlier
3. Use cheaper model

### Warning: max_turns exceeded (soft guard)

**Cause:** Task took more turns than expected (possible loop).

**Action:**

1. Review agent behavior for loops
2. Increase `max_turns` if legitimate
3. Add explicit breakpoints

### Fold summary too verbose

**Cause:** `summary_budget` insufficient for task complexity.

**Fix (v0.2+):**

Increase `summary_budget` (v0.1 fixed at 2000).

**Workaround (v0.1):**

Use more aggressive `discard` categories.

---

## References

### Research

- **Primary:** [Intent Folding for Agents (2026-08-25)](../research/2026-08-25-intent-folding-for-agents.md)
- **FoldAgent:** 62% BrowseComp-Plus, 58% SWE-Bench Verified (32K context vs 327K baseline)
- **SimpleMem:** 26.4% F1 improvement, 30× token reduction (LoCoMo benchmark)
- **Anthropic Context Mgmt:** 29% perf gain (context editing), 84% token reduction (100-turn eval)

### Decisions

- **ADR-0003:** [Fold Trigger Single Not Compound](../adr/0003-fold-trigger-single-not-compound.md)
- **Decision Log:**
  - DL-0003: Single fold triggers
  - DL-0004: Hard guards on context/cost, soft on turns
  - DL-0005: Standardized + custom categories
  - DL-0006: Fixed summary budget (2K tokens)
  - DL-0007: AtomicFact stub (v0.2)
  - DL-0008: Remove estimated_savings_usd

### Implementation

- **PRD:** GitHub issue [#219](https://github.com/johnalexwelch/dotdev/issues/219)
- **PR:** [#226](https://github.com/johnalexwelch/dotdev/pull/226) (5 vertical slices, 60 tests, TDD)
- **Review:** 5-lane workflow-review (security, logic, TDD, syntax, product) — all APPROVE
- **Handoff:** [Execution Summary](../executions/handoffs/2026-08-25-prd-219-intent-folding.md)

### Roadmap

- **v0.1** (current): YAML + guards + validation + metrics
- **v0.2**: Diagnostic broker + SimpleMem integration + multi-intent
- **v0.3**: CHORUS delegation + evidence tracking
- **v1**: LSP + policy engine + durable workflows

---

## FAQ

**Q: Does this work with any Pi model?**

A: Yes. Cost calculation supports Claude Sonnet, GPT-4.1, and Claude Haiku (v0.1). Add more models in `src/guards.ts`.

**Q: Can I use multiple intents in one session?**

A: Not in v0.1. Single intent per session. Multi-intent support in v0.2.

**Q: What if I don't specify an intent?**

A: Extension is inactive. Pi runs normally without folding.

**Q: Can I preview what will be folded?**

A: Not yet. Dry-run mode planned for v0.2.

**Q: Does fold work with existing Pi features (memory, compaction)?**

A: Yes. Intent folding is additive — it works alongside Pi's built-in memory and observational compaction.

**Q: How do I know when a fold happened?**

A: Check metrics export (JSON/CSV) or Pi session logs (v0.2 will add live notifications).

---

## Next Steps

1. **Try it:** Create an intent YAML and validate it
2. **Run a session:** Use `pi --intent path/to/intent.yaml`
3. **Review metrics:** Check `fold-metrics.json` after session
4. **Tune thresholds:** Adjust `threshold`, `max_cost_usd` based on results
5. **Share feedback:** Open issue or discuss in [#219](https://github.com/johnalexwelch/dotdev/issues/219)

---

**Version:** v0.1 Alpha (2026-08-25)

**Status:** Production-ready for local use (not published to npm)

**License:** MIT (per package.json)

**Maintainer:** alexwelch (dotdev)
