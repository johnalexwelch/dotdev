import type { FoldTrigger } from './schema.js';

/**
 * FoldMetrics: Telemetry for context folding operations.
 *
 * Captures token counts, costs, and efficiency metrics for each fold operation.
 * Reference: docs/research/2026-08-25-intent-folding-for-agents.md (Finding 6)
 * Decision: DL-0006 (fixed summary budget), DL-0007 (forward-compatible stub)
 */

export interface FoldMetrics {
  fold_id: string;
  timestamp: string; // ISO 8601
  trigger: FoldTrigger;

  // Token accounting
  pre_fold_tokens: number;
  post_fold_tokens: number;
  compression_ratio: number; // pre / post, rounded to 3 decimals

  // Cost accounting (in USD)
  input_cost_usd: number;
  output_cost_usd: number;
  cumulative_cost_usd: number; // input + output, rounded to 2 decimals
  estimated_savings_usd: number; // tokens saved * avg rate, rounded to 2 decimals

  // Intent tracking
  preserved_intents: string[];
  discarded_categories: string[];

  // Timing
  fold_latency_ms: number;

  // Forward-compatible v0.2+ stub (empty in v0.1)
  atomic_facts_stub?: unknown[];
}

export interface FoldMetricsInput {
  fold_id: string;
  timestamp: string;
  trigger: FoldTrigger;
  pre_fold_tokens: number;
  post_fold_tokens: number;
  input_cost_usd: number;
  output_cost_usd: number;
  preserved_intents: string[];
  discarded_categories: string[];
  fold_latency_ms: number;
}

/**
 * Average model rates for savings estimation (per 1M tokens).
 * Sources: research Finding 6, 2026-08 pricing snapshot
 */
const AVG_MODEL_RATE = ((3.0 + 15.0) + (2.0 + 8.0) + (0.25 + 1.25)) / 3 / 1_000_000; // ~0.0095 per token

/**
 * Generate FoldMetrics from input parameters.
 * Validates inputs and calculates derived fields.
 *
 * @param input Fold parameters
 * @returns FoldMetrics with calculated fields
 * @throws Error if validation fails (e.g., negative tokens, zero post_fold)
 */
export function generateFoldMetrics(input: FoldMetricsInput): FoldMetrics {
  // Validate inputs
  if (input.pre_fold_tokens < 0) {
    throw new Error('pre_fold_tokens must be non-negative');
  }
  if (input.post_fold_tokens <= 0) {
    throw new Error('post_fold_tokens must be positive (cannot be zero to avoid division by zero)');
  }
  if (input.input_cost_usd < 0 || input.output_cost_usd < 0) {
    throw new Error('Cost values must be non-negative');
  }
  if (input.fold_latency_ms < 0) {
    throw new Error('fold_latency_ms must be non-negative');
  }

  // Calculate compression ratio
  const compression_ratio = Number((input.pre_fold_tokens / input.post_fold_tokens).toFixed(3));

  // Calculate cumulative cost
  const cumulative_cost_usd = Number(
    (input.input_cost_usd + input.output_cost_usd).toFixed(2)
  );

  // Calculate estimated savings
  const tokens_saved = input.pre_fold_tokens - input.post_fold_tokens;
  const estimated_savings_usd = Number((tokens_saved * AVG_MODEL_RATE).toFixed(2));

  return {
    fold_id: input.fold_id,
    timestamp: input.timestamp,
    trigger: input.trigger,
    pre_fold_tokens: input.pre_fold_tokens,
    post_fold_tokens: input.post_fold_tokens,
    compression_ratio,
    input_cost_usd: input.input_cost_usd,
    output_cost_usd: input.output_cost_usd,
    cumulative_cost_usd,
    estimated_savings_usd,
    preserved_intents: input.preserved_intents,
    discarded_categories: input.discarded_categories,
    fold_latency_ms: input.fold_latency_ms,
    atomic_facts_stub: undefined, // v0.1 stub; v0.2 populates this
  };
}

/**
 * Export single FoldMetrics to JSON string.
 *
 * @param metrics FoldMetrics object
 * @returns JSON string representation
 */
export function exportJSON(metrics: FoldMetrics): string {
  return JSON.stringify(metrics, null, 2);
}

/**
 * Export array of FoldMetrics to CSV string.
 * Includes headers and is spreadsheet-ready.
 *
 * @param metrics Array of FoldMetrics objects
 * @returns CSV string with headers
 */
export function exportCSV(metrics: FoldMetrics[]): string {
  if (metrics.length === 0) {
    return '';
  }

  // Headers (order matches FoldMetrics structure)
  const headers = [
    'fold_id',
    'timestamp',
    'trigger',
    'pre_fold_tokens',
    'post_fold_tokens',
    'compression_ratio',
    'input_cost_usd',
    'output_cost_usd',
    'cumulative_cost_usd',
    'estimated_savings_usd',
    'preserved_intents',
    'discarded_categories',
    'fold_latency_ms',
  ];

  // Data rows
  const rows = metrics.map((m) => [
    csvEscape(m.fold_id),
    csvEscape(m.timestamp),
    csvEscape(m.trigger),
    m.pre_fold_tokens.toString(),
    m.post_fold_tokens.toString(),
    m.compression_ratio.toString(),
    m.input_cost_usd.toFixed(2),
    m.output_cost_usd.toFixed(2),
    m.cumulative_cost_usd.toFixed(2),
    m.estimated_savings_usd.toFixed(2),
    csvEscape(m.preserved_intents.join(';')),
    csvEscape(m.discarded_categories.join(';')),
    m.fold_latency_ms.toString(),
  ]);

  // Join header and rows with newlines
  const headerLine = headers.join(',');
  const dataLines = rows.map((row) => row.join(','));

  return [headerLine, ...dataLines].join('\n');
}

/**
 * Escape CSV values (quotes, commas, newlines).
 * If value contains comma, quote, or newline, wrap in quotes and escape quotes.
 *
 * @param value String to escape
 * @returns Escaped value
 */
function csvEscape(value: string): string {
  if (value.includes(',') || value.includes('"') || value.includes('\n')) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}
