import { test } from 'node:test';
import * as assert from 'node:assert/strict';

// Test 1: Extension exports all required APIs
test('index: exports all public APIs', async () => {
  const ext = await import('../dist/index.js');

  // Schema and types
  assert.ok(ext.IntentSchema, 'IntentSchema should be exported');

  // Guards
  assert.ok(ext.enforceHardGuards, 'enforceHardGuards should be exported');
  assert.ok(ext.warnSoftGuards, 'warnSoftGuards should be exported');
  assert.ok(ext.parseIntentYAML, 'parseIntentYAML should be exported');
  assert.ok(ext.validateAllGuards, 'validateAllGuards should be exported');
  assert.ok(ext.calculateCost, 'calculateCost should be exported');
  assert.ok(ext.GuardViolationError, 'GuardViolationError should be exported');

  // Metrics
  assert.ok(ext.generateFoldMetrics, 'generateFoldMetrics should be exported');
  assert.ok(ext.exportJSON, 'exportJSON should be exported');
  assert.ok(ext.exportCSV, 'exportCSV should be exported');

  // Validator
  assert.ok(ext.validateIntentFile, 'validateIntentFile should be exported');
  assert.ok(ext.formatValidationError, 'formatValidationError should be exported');
});

// Test 2: IntentSchema is a Zod schema
test('index: IntentSchema is a Zod schema with safeParse', async () => {
  const ext = await import('../dist/index.js');
  assert.ok(ext.IntentSchema.safeParse, 'IntentSchema should have safeParse method');
  assert.ok(ext.IntentSchema.parse, 'IntentSchema should have parse method');
});

// Test 3: Guard functions are callable
test('index: guard functions are callable', async () => {
  const ext = await import('../dist/index.js');
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
  ext.enforceHardGuards(intent, 50000, 2.0);
  ext.warnSoftGuards(intent, 10);

  const yaml = `
intent:
  id: test
  version: 1
  description: test
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
  const parsed = ext.parseIntentYAML(yaml);
  assert.equal(parsed.intent.id, 'test');
});

// Test 4: Metrics functions are callable
test('index: metrics functions are callable', async () => {
  const ext = await import('../dist/index.js');

  const metrics = ext.generateFoldMetrics({
    fold_id: 'test-fold',
    timestamp: '2026-08-25T10:30:00Z',
    trigger: 'token_threshold',
    pre_fold_tokens: 100000,
    post_fold_tokens: 10000,
    input_cost_usd: 0.3,
    output_cost_usd: 0.5,
    preserved_intents: [],
    discarded_categories: [],
    fold_latency_ms: 100,
  });

  assert.ok(metrics);
  const json = ext.exportJSON(metrics);
  assert.ok(json);
  const csv = ext.exportCSV([metrics]);
  assert.ok(csv.includes('fold_id'));
});

// Test 5: Validator functions are callable
test('index: validator functions are callable', async () => {
  const ext = await import('../dist/index.js');
  assert.ok(typeof ext.validateIntentFile === 'function');
  assert.ok(typeof ext.formatValidationError === 'function');
});

// Test 6: calculateCost is available
test('index: calculateCost is available', async () => {
  const ext = await import('../dist/index.js');
  const cost = ext.calculateCost(1000000, 'input', 'claude-sonnet-4');
  assert.ok(cost > 0);
  assert.ok(Math.abs(cost - 3.0) < 0.1);
});

// Test 7: No import errors or console noise during load
test('index: loads without errors', async () => {
  // This test just checks that import succeeds (no errors thrown)
  const ext = await import('../dist/index.js');
  assert.ok(ext);
});

// Test 8: Extension metadata (if present)
test('index: all exports are functions or objects', async () => {
  const ext = await import('../dist/index.js');

  const keys = Object.keys(ext);
  assert.ok(keys.length > 0, 'Extension should export at least one API');

  for (const key of keys) {
    const value = (ext as any)[key];
    const type = typeof value;
    assert.ok(
      type === 'function' || type === 'object',
      `Exported ${key} should be a function or object, got ${type}`
    );
  }
});

// Test 9: Error types are exported
test('index: error types are exported', async () => {
  const ext = await import('../dist/index.js');
  assert.ok(ext.GuardViolationError);
  const err = new ext.GuardViolationError('Test error');
  assert.equal(err.name, 'GuardViolationError');
  assert.equal(err.message, 'Test error');
});

// Test 10: Extension can be used for end-to-end validation
test('index: end-to-end validation flow works', async () => {
  const ext = await import('../dist/index.js');

  const yaml = `
intent:
  id: e2e-test
  version: 1
  description: End-to-end test
fold:
  trigger: token_threshold
  threshold: 24000
  preserve:
    - user_query
    - decisions
  discard:
    - intermediate_tool_outputs
    - reasoning_traces
guards:
  max_context: 120000
  max_cost_usd: 5.0
  max_turns: 50
`;

  // Parse
  const intent = ext.parseIntentYAML(yaml);
  assert.equal(intent.intent.id, 'e2e-test');

  // Enforce guards
  ext.enforceHardGuards(intent, 50000, 2.5);

  // Generate metrics
  const metrics = ext.generateFoldMetrics({
    fold_id: 'e2e-test-fold',
    timestamp: new Date().toISOString(),
    trigger: 'token_threshold',
    pre_fold_tokens: 100000,
    post_fold_tokens: 10000,
    input_cost_usd: 0.3,
    output_cost_usd: 0.5,
    preserved_intents: ['e2e-test'],
    discarded_categories: ['reasoning_traces'],
    fold_latency_ms: 150,
  });

  // Export
  const json = ext.exportJSON(metrics);
  const parsed = JSON.parse(json);
  assert.equal(parsed.fold_id, 'e2e-test-fold');
});
