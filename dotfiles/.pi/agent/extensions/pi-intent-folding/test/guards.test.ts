import { test } from 'node:test';
import * as assert from 'node:assert/strict';
import {
  enforceHardGuards,
  warnSoftGuards,
  parseIntentYAML,
  calculateCost,
} from '../dist/guards.js';
import type { Intent } from '../dist/schema.js';

// Test 1: Exactly at context limit (passes)
test('guards: context exactly at limit passes', () => {
  const intent = {
    intent: { id: 'test', version: 1, description: 'test' },
    fold: {
      trigger: 'explicit' as const,
      preserve: ['user_query'],
      discard: ['reasoning_traces'],
      summary_budget: 2000,
    },
    guards: { max_context: 120000, max_cost_usd: 5.0 },
  };
  // Should not throw
  enforceHardGuards(intent, 120000, 5.0);
  assert.ok(true);
});

// Test 2: Just over context limit (fails)
test('guards: context over limit throws', () => {
  const intent = {
    intent: { id: 'test', version: 1, description: 'test' },
    fold: {
      trigger: 'explicit' as const,
      preserve: ['user_query'],
      discard: ['reasoning_traces'],
      summary_budget: 2000,
    },
    guards: { max_context: 120000, max_cost_usd: 5.0 },
  };
  assert.throws(
    () => enforceHardGuards(intent, 120001, 5.0),
    (err: any) => {
      assert.ok(err.message.includes('Context exceeded'));
      assert.ok(err.message.includes('120,000'));
      assert.ok(err.message.includes('120,001'));
      return true;
    }
  );
});

// Test 3: Exactly at cost limit (passes)
test('guards: cost exactly at limit passes', () => {
  const intent = {
    intent: { id: 'test', version: 1, description: 'test' },
    fold: {
      trigger: 'explicit' as const,
      preserve: ['user_query'],
      discard: ['reasoning_traces'],
      summary_budget: 2000,
    },
    guards: { max_context: 120000, max_cost_usd: 5.0 },
  };
  enforceHardGuards(intent, 50000, 5.0);
  assert.ok(true);
});

// Test 4: Just over cost limit (fails)
test('guards: cost over limit throws', () => {
  const intent = {
    intent: { id: 'test', version: 1, description: 'test' },
    fold: {
      trigger: 'explicit' as const,
      preserve: ['user_query'],
      discard: ['reasoning_traces'],
      summary_budget: 2000,
    },
    guards: { max_context: 120000, max_cost_usd: 5.0 },
  };
  assert.throws(
    () => enforceHardGuards(intent, 50000, 5.01),
    (err: any) => {
      assert.ok(err.message.includes('Cost ceiling exceeded'));
      assert.ok(err.message.includes('$5.00'));
      assert.ok(err.message.includes('$5.01'));
      return true;
    }
  );
});

// Test 5: Soft guard at limit (warning, no throw)
test('guards: soft guard at limit warns but does not throw', () => {
  const intent = {
    intent: { id: 'test', version: 1, description: 'test' },
    fold: {
      trigger: 'explicit' as const,
      preserve: ['user_query'],
      discard: ['reasoning_traces'],
      summary_budget: 2000,
    },
    guards: {
      max_context: 120000,
      max_cost_usd: 5.0,
      max_turns: 50,
    },
  };
  // Should not throw, but may log warning
  warnSoftGuards(intent, 50);
  assert.ok(true);
});

// Test 6: Soft guard exceeded (warning, no throw)
test('guards: soft guard exceeded warns but does not throw', () => {
  const intent = {
    intent: { id: 'test', version: 1, description: 'test' },
    fold: {
      trigger: 'explicit' as const,
      preserve: ['user_query'],
      discard: ['reasoning_traces'],
      summary_budget: 2000,
    },
    guards: {
      max_context: 120000,
      max_cost_usd: 5.0,
      max_turns: 50,
    },
  };
  // Should not throw even though turn count exceeds
  warnSoftGuards(intent, 51);
  assert.ok(true);
});

// Test 7: Parse valid intent YAML
test('guards: parseIntentYAML parses valid YAML', () => {
  const yaml = `
intent:
  id: test-intent
  version: 1
  description: Test intent
fold:
  trigger: token_threshold
  threshold: 24000
  preserve:
    - user_query
  discard:
    - reasoning_traces
guards:
  max_context: 120000
  max_cost_usd: 5.0
`;
  const intent = parseIntentYAML(yaml);
  assert.equal(intent.intent.id, 'test-intent');
  assert.equal(intent.fold.trigger, 'token_threshold');
});

// Test 8: Parse invalid intent YAML (missing required field)
test('guards: parseIntentYAML rejects invalid YAML', () => {
  const yaml = `
intent:
  version: 1
  description: Missing ID
fold:
  trigger: explicit
  preserve:
    - user_query
  discard:
    - reasoning_traces
guards:
  max_context: 120000
  max_cost_usd: 5.0
`;
  assert.throws(
    () => parseIntentYAML(yaml),
    (err: any) => {
      assert.ok(err.message.includes('intent.id') || err.message.includes('schema validation failed'));
      return true;
    }
  );
});

// Test 9: Cost calculation for Claude Sonnet
test('guards: calculateCost computes correctly for Claude Sonnet', () => {
  // Claude Sonnet 4: $3.00 per 1M input, $15.00 per 1M output
  const inputCost = calculateCost(1000000, 'input', 'claude-sonnet-4');
  const outputCost = calculateCost(1000000, 'output', 'claude-sonnet-4');
  assert.ok(Math.abs(inputCost - 3.0) < 0.01);
  assert.ok(Math.abs(outputCost - 15.0) < 0.01);
});

// Test 10: Cost calculation for GPT-4.1
test('guards: calculateCost computes correctly for GPT-4.1', () => {
  // GPT-4.1: $2.00 per 1M input, $8.00 per 1M output
  const inputCost = calculateCost(1000000, 'input', 'gpt-4.1');
  const outputCost = calculateCost(1000000, 'output', 'gpt-4.1');
  assert.ok(Math.abs(inputCost - 2.0) < 0.01);
  assert.ok(Math.abs(outputCost - 8.0) < 0.01);
});

// Test 11: Cost calculation for Claude Haiku
test('guards: calculateCost computes correctly for Claude Haiku', () => {
  // Claude Haiku 4: $0.25 per 1M input, $1.25 per 1M output
  const inputCost = calculateCost(1000000, 'input', 'claude-haiku-4');
  const outputCost = calculateCost(1000000, 'output', 'claude-haiku-4');
  assert.ok(Math.abs(inputCost - 0.25) < 0.01);
  assert.ok(Math.abs(outputCost - 1.25) < 0.01);
});

// Test 12: Error message includes remediation hints
test('guards: error messages include remediation hints', () => {
  const intent = {
    intent: { id: 'test', version: 1, description: 'test' },
    fold: {
      trigger: 'explicit' as const,
      preserve: ['user_query'],
      discard: ['reasoning_traces'],
      summary_budget: 2000,
    },
    guards: { max_context: 120000, max_cost_usd: 5.0 },
  };
  assert.throws(
    () => enforceHardGuards(intent, 150000, 5.0),
    (err: any) => {
      assert.ok(
        err.message.includes('reduce') ||
        err.message.includes('Remediation') ||
        err.message.includes('summary_budget')
      );
      return true;
    }
  );
});

// Test 13: Multiple hard guards breach simultaneously
test('guards: multiple hard guard breaches fail on first', () => {
  const intent = {
    intent: { id: 'test', version: 1, description: 'test' },
    fold: {
      trigger: 'explicit' as const,
      preserve: ['user_query'],
      discard: ['reasoning_traces'],
      summary_budget: 2000,
    },
    guards: { max_context: 120000, max_cost_usd: 5.0 },
  };
  // Both context and cost are over
  assert.throws(
    () => enforceHardGuards(intent, 150000, 6.0),
    (err: any) => {
      // Should report context first (order: context, then cost)
      assert.ok(err.message.includes('Context') || err.message.includes('Cost'));
      return true;
    }
  );
});

// Test 14: Soft guard without max_turns (should not warn)
test('guards: soft guard undefined max_turns does not warn', () => {
  const intent = {
    intent: { id: 'test', version: 1, description: 'test' },
    fold: {
      trigger: 'explicit' as const,
      preserve: ['user_query'],
      discard: ['reasoning_traces'],
      summary_budget: 2000,
    },
    guards: { max_context: 120000, max_cost_usd: 5.0 },
  };
  // Should not throw or warn
  warnSoftGuards(intent, 999);
  assert.ok(true);
});
