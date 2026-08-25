import { IntentSchema, type Intent } from './schema.js';
import { parse as parseYaml } from 'yaml';

/**
 * Runtime validation and hard/soft limit enforcement for intent configuration.
 *
 * Hard guards (throw on breach):
 * - max_context: Maximum token budget for session
 * - max_cost_usd: Maximum USD cost ceiling
 *
 * Soft guards (warn on breach):
 * - max_turns: Maximum turn count (advisory only)
 *
 * Reference: docs/research/2026-08-25-intent-folding-for-agents.md (Finding 5)
 * Decision: DL-0004 (hard vs soft guards)
 */

// Model pricing rates (as of 2026-08)
// Reference: Finding 6 in research doc
const MODEL_RATES: Record<string, Record<'input' | 'output', number>> = {
  'claude-sonnet-4': { input: 3.0, output: 15.0 },
  'gpt-4.1': { input: 2.0, output: 8.0 },
  'claude-haiku-4': { input: 0.25, output: 1.25 },
};

export class GuardViolationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'GuardViolationError';
  }
}

/**
 * Calculate cost in USD for tokens at a given model's rate.
 * Rates are stored per-1M tokens.
 *
 * @param tokens Number of tokens consumed
 * @param type 'input' or 'output' token type
 * @param model Model identifier (e.g., 'claude-sonnet-4')
 * @returns Cost in USD
 */
export function calculateCost(
  tokens: number,
  type: 'input' | 'output',
  model: string = 'claude-sonnet-4'
): number {
  const rates = MODEL_RATES[model] || MODEL_RATES['claude-sonnet-4'];
  const ratePerMillion = rates[type];
  return (tokens / 1_000_000) * ratePerMillion;
}

/**
 * Enforce hard guards: throw if context or cost exceed limits.
 *
 * Hard guards check in order: max_context, then max_cost_usd.
 * Includes user-actionable error messages and remediation hints.
 *
 * @param intent Parsed intent configuration
 * @param currentTokens Current context token count
 * @param currentCostUsd Current cumulative cost in USD
 * @throws GuardViolationError if hard guard is breached
 */
export function enforceHardGuards(
  intent: Intent,
  currentTokens: number,
  currentCostUsd: number
): void {
  // Check max_context (hard limit)
  if (currentTokens > intent.guards.max_context) {
    const limit = intent.guards.max_context.toLocaleString();
    const current = currentTokens.toLocaleString();
    throw new GuardViolationError(
      `Context exceeded: ${limit} tokens max, current: ${current}.\n` +
      `Remediation: Reduce fold.summary_budget (currently ${intent.fold.summary_budget}) ` +
      `or lower fold.trigger threshold.`
    );
  }

  // Check max_cost_usd (hard limit)
  if (currentCostUsd > intent.guards.max_cost_usd) {
    const limit = intent.guards.max_cost_usd.toFixed(2);
    const current = currentCostUsd.toFixed(2);
    throw new GuardViolationError(
      `Cost ceiling exceeded: $${limit} max, current: $${current}.\n` +
      `Remediation: Use a cheaper model, reduce context size, or increase max_cost_usd limit.`
    );
  }
}

/**
 * Warn on soft guards: log advisory warnings but do not throw.
 *
 * Soft guards are informational; exceeding them does not halt execution.
 *
 * @param intent Parsed intent configuration
 * @param currentTurns Current turn count
 */
export function warnSoftGuards(intent: Intent, currentTurns: number): void {
  // Check max_turns (soft limit)
  if (intent.guards.max_turns !== undefined && currentTurns > intent.guards.max_turns) {
    const limit = intent.guards.max_turns;
    console.warn(
      `[WARN] Intent ${intent.intent.id}: Turn count ${currentTurns} / ${limit} max (soft limit). ` +
      `Execution may become inefficient or expensive.`
    );
  }
}

/**
 * Parse intent YAML into typed Intent object.
 *
 * Uses Zod schema for runtime validation. Throws on schema violation.
 *
 * @param yamlString YAML string to parse
 * @returns Validated Intent object
 * @throws GuardViolationError if schema validation fails
 */
export function parseIntentYAML(yamlString: string): Intent {
  let parsed: unknown;

  try {
    parsed = parseYaml(yamlString);
  } catch (err) {
    throw new GuardViolationError(`Failed to parse YAML: ${(err as Error).message}`);
  }

  const result = IntentSchema.safeParse(parsed);

  if (!result.success) {
    const errors = result.error.errors.map((e) => `${e.path.join('.')}: ${e.message}`).join('; ');
    throw new GuardViolationError(`Intent schema validation failed: ${errors}`);
  }

  return result.data;
}

/**
 * Validate and enforce all guards (hard + soft).
 * Hard guard violations throw; soft guard violations warn.
 *
 * @param intent Parsed intent configuration
 * @param currentTokens Current context token count
 * @param currentCostUsd Current cumulative cost in USD
 * @param currentTurns Current turn count
 */
export function validateAllGuards(
  intent: Intent,
  currentTokens: number,
  currentCostUsd: number,
  currentTurns: number
): void {
  enforceHardGuards(intent, currentTokens, currentCostUsd);
  warnSoftGuards(intent, currentTurns);
}
