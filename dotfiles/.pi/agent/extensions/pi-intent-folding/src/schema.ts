import { z } from 'zod';

/**
 * Zod schema for intent folding configuration.
 * Encodes the YAML grammar for intent definitions with fold triggers and guards.
 *
 * Reference: docs/research/2026-08-25-intent-folding-for-agents.md (Finding 1, Finding 5)
 * ADR: docs/adr/0003-fold-trigger-single-not-compound.md
 */

// Fold trigger types - single trigger per intent, never compound (ADR-0003)
const FoldTriggerType = z.enum(['token_threshold', 'turn_count', 'explicit']);

// Intent core metadata
const IntentMetadata = z.object({
  id: z.string().min(1, 'Intent ID must not be empty'),
  version: z.number().int().min(1, 'Intent version must be >= 1'),
  description: z.string().min(1, 'Description must not be empty'),
});

// Fold configuration with conditional threshold requirement
const FoldConfig = z.object({
  trigger: FoldTriggerType,
  threshold: z.number().int().positive('Threshold must be a positive integer').optional(),
  preserve: z.array(z.string()).min(1, 'Must preserve at least one category'),
  discard: z.array(z.string()).min(1, 'Must discard at least one category'),
  summary_budget: z.number().int().positive('Summary budget must be positive').default(2000),
})
  .refine(
    (data) => {
      // Token threshold and turn_count triggers require a threshold value
      if ((data.trigger === 'token_threshold' || data.trigger === 'turn_count') && !data.threshold) {
        return false;
      }
      // Explicit trigger does not need threshold
      if (data.trigger === 'explicit' && data.threshold !== undefined) {
        return false;
      }
      return true;
    },
    (data) => {
      if (data.trigger === 'token_threshold' && !data.threshold) {
        return { message: 'threshold required for token_threshold trigger', path: ['threshold'] };
      }
      if (data.trigger === 'turn_count' && !data.threshold) {
        return { message: 'threshold required for turn_count trigger', path: ['threshold'] };
      }
      if (data.trigger === 'explicit' && data.threshold !== undefined) {
        return { message: 'threshold must not be set for explicit trigger', path: ['threshold'] };
      }
      return { message: 'Unknown fold configuration error' };
    }
  );

// Guards: hard limits on context/cost, soft on turns (DL-0004)
const Guards = z.object({
  max_context: z.number().int().positive('max_context must be positive'),
  max_cost_usd: z.number().positive('max_cost_usd must be positive'),
  max_turns: z.number().int().positive('max_turns must be positive').optional(),
});

// Forward-compatible AtomicFact stub for v0.2+ (DL-0007)
const AtomicFactStub = z.object({
  id: z.string(),
  content: z.string(),
  source_turn: z.number().int(),
  timestamp: z.string(),
  intent_tag: z.string(),
  confidence: z.number().min(0).max(1),
  supersedes: z.string().optional(),
}).strict().optional();

// Complete Intent schema
export const IntentSchema = z.object({
  intent: IntentMetadata,
  fold: FoldConfig,
  guards: Guards,
  atomic_facts_stub: AtomicFactStub.optional(), // v0.2+ forward compatibility
}).strict();

// Type exports for TypeScript consumers
export type Intent = z.infer<typeof IntentSchema>;
export type FoldTrigger = z.infer<typeof FoldTriggerType>;
export type FoldConfiguration = z.infer<typeof FoldConfig>;
export type GuardsConfiguration = z.infer<typeof Guards>;
export type AtomicFact = z.infer<typeof AtomicFactStub>;
