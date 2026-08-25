/**
 * pi-intent-folding: Extension entry point
 *
 * Exports all public APIs for schema, guards, metrics, and validation.
 * Auto-discoverable via Pi's extension loader at ~/.pi/agent/extensions/
 *
 * Public API:
 * - Schema: IntentSchema, type Intent
 * - Guards: enforceHardGuards, warnSoftGuards, parseIntentYAML, validateAllGuards, calculateCost
 * - Metrics: generateFoldMetrics, exportJSON, exportCSV
 * - Validator: validateIntentFile, formatValidationError
 */

// Schema & Types
export { IntentSchema } from './schema.js';
export type { Intent, FoldTrigger, FoldConfiguration, GuardsConfiguration, AtomicFact } from './schema.js';

// Guards
export {
  enforceHardGuards,
  warnSoftGuards,
  parseIntentYAML,
  validateAllGuards,
  calculateCost,
  GuardViolationError,
} from './guards.js';

// Metrics
export { generateFoldMetrics, exportJSON, exportCSV } from './metrics.js';
export type { FoldMetrics, FoldMetricsInput } from './metrics.js';

// Validator
export { validateIntentFile, formatValidationError, runValidatorCLI } from './validator.js';
export type { ValidationError, ValidationResult } from './validator.js';

// Extension metadata (for Pi discovery)
export const PI_EXTENSION_METADATA = {
  name: 'pi-intent-folding',
  version: '0.1.0',
  description: 'Deterministic intent folding for Pi agents - YAML schema + TypeScript guards + cost tracking',
  apis: [
    'IntentSchema',
    'enforceHardGuards',
    'warnSoftGuards',
    'parseIntentYAML',
    'validateAllGuards',
    'calculateCost',
    'generateFoldMetrics',
    'exportJSON',
    'exportCSV',
    'validateIntentFile',
    'formatValidationError',
  ],
};
