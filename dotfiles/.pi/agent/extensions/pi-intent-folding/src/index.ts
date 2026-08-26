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

// Runtime telemetry
import fs from 'fs';
import path from 'path';
import { Intent } from './schema.js';
import { parseIntentYAML, enforceHardGuards, warnSoftGuards } from './guards.js';

interface TelemetryEvent {
  timestamp: string;
  event: string;
  [key: string]: unknown;
}

export class IntentTelemetry {
  private events: TelemetryEvent[] = [];
  private logPath: string;

  constructor(sessionId: string) {
    // ponytail: hardcoded ~/.pi/sessions for v0.1; parameterize in v0.2
    const sessionDir = path.join(process.env.HOME || '', '.pi', 'sessions', sessionId);
    this.logPath = path.join(sessionDir, 'intent-events.jsonl');
    
    if (!fs.existsSync(sessionDir)) {
      fs.mkdirSync(sessionDir, { recursive: true });
    }
  }

  log(event: string, data: Record<string, unknown> = {}): void {
    const entry: TelemetryEvent = {
      timestamp: new Date().toISOString(),
      event,
      ...data,
    };
    this.events.push(entry);
    fs.appendFileSync(this.logPath, JSON.stringify(entry) + '\n');
  }

  getEvents(): TelemetryEvent[] {
    return this.events;
  }

  getLogPath(): string {
    return this.logPath;
  }
}

// Pi extension lifecycle hooks
export interface PiSessionContext {
  sessionId: string;
  intentPath?: string;
  currentTokens: number;
  currentCostUSD: number;
  currentTurns: number;
  model: string;
}

export class IntentMonitor {
  private telemetry: IntentTelemetry;
  private intent: Intent | null = null;
  private foldCount = 0;

  constructor(sessionId: string) {
    this.telemetry = new IntentTelemetry(sessionId);
  }

  loadIntent(intentPath: string): void {
    try {
      const yamlContent = fs.readFileSync(intentPath, 'utf-8');
      const intent = parseIntentYAML(yamlContent);
      this.intent = intent;
      this.telemetry.log('intent_loaded', {
        intent_id: intent.intent.id,
        intent_version: intent.intent.version,
        trigger: intent.fold.trigger,
        threshold: intent.fold.threshold,
        max_context: intent.guards.max_context,
        max_cost_usd: intent.guards.max_cost_usd,
      });
    } catch (error) {
      this.telemetry.log('intent_load_failed', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  }

  checkGuards(ctx: PiSessionContext): void {
    if (!this.intent) return;

    try {
      enforceHardGuards(this.intent, ctx.currentTokens, ctx.currentCostUSD);
      warnSoftGuards(this.intent, ctx.currentTurns);
      
      this.telemetry.log('guard_check', {
        tokens: ctx.currentTokens,
        cost_usd: ctx.currentCostUSD,
        turns: ctx.currentTurns,
        passed: true,
      });
    } catch (error) {
      this.telemetry.log('guard_violation', {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  }

  shouldFold(ctx: PiSessionContext): boolean {
    if (!this.intent) return false;

    const { trigger, threshold } = this.intent.fold;

    let shouldTrigger = false;
    switch (trigger) {
      case 'token_threshold':
        shouldTrigger = ctx.currentTokens >= (threshold || 0);
        break;
      case 'turn_count':
        shouldTrigger = ctx.currentTurns >= (threshold || 0);
        break;
      case 'explicit':
        // Manual fold only
        shouldTrigger = false;
        break;
    }

    if (shouldTrigger) {
      this.telemetry.log('fold_triggered', {
        trigger,
        threshold,
        current_value: trigger === 'token_threshold' ? ctx.currentTokens : ctx.currentTurns,
      });
    }

    return shouldTrigger;
  }

  recordFold(beforeTokens: number, afterTokens: number, beforeCost: number, afterCost: number): void {
    this.foldCount++;
    this.telemetry.log('fold_executed', {
      fold_number: this.foldCount,
      tokens_before: beforeTokens,
      tokens_after: afterTokens,
      tokens_saved: beforeTokens - afterTokens,
      cost_before_usd: beforeCost,
      cost_after_usd: afterCost,
      cost_saved_usd: beforeCost - afterCost,
      preserved_categories: this.intent?.fold.preserve,
      discarded_categories: this.intent?.fold.discard,
    });
  }

  getTelemetry(): IntentTelemetry {
    return this.telemetry;
  }
}

export { IntentMonitor as default };
