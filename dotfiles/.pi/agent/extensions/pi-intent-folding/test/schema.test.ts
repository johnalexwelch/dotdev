import { test } from 'node:test';
import * as assert from 'node:assert/strict';
import { IntentSchema } from '../dist/schema.js';
import { parse as parseYaml } from 'yaml';

// Type-only import for tests (compile-time only)
import type { Intent } from '../dist/schema.js';

// Test 1: Valid minimal intent with token_threshold trigger
test('schema: valid intent with token_threshold trigger', () => {
  const yaml = `
intent:
  id: research-task
  version: 1
  description: Deep research with automatic folding
fold:
  trigger: token_threshold
  threshold: 24000
  preserve:
    - user_query
    - decisions
  discard:
    - intermediate_tool_outputs
guards:
  max_context: 120000
  max_cost_usd: 5.00
`;
  const data = parseYaml(yaml);
  const result = IntentSchema.safeParse(data);
  assert.ok(result.success, `Schema validation failed: ${JSON.stringify(result.error)}`);
  const intent = result.data as any;
  assert.equal(intent.intent.id, 'research-task');
  assert.equal(intent.fold.trigger, 'token_threshold');
  assert.equal(intent.fold.threshold, 24000);
  assert.equal(intent.fold.summary_budget, 2000); // default
});

// Test 2: Valid intent with turn_count trigger
test('schema: valid intent with turn_count trigger', () => {
  const yaml = `
intent:
  id: iterative-task
  version: 1
  description: Task that folds after N turns
fold:
  trigger: turn_count
  threshold: 10
  preserve:
    - final_answer
  discard:
    - reasoning_traces
guards:
  max_context: 100000
  max_cost_usd: 3.00
`;
  const data = parseYaml(yaml);
  const result = IntentSchema.safeParse(data);
  assert.ok(result.success);
  const intent = result.data as any;
  assert.equal(intent.fold.trigger, 'turn_count');
  assert.equal(intent.fold.threshold, 10);
});

// Test 3: Valid intent with explicit trigger (no threshold needed)
test('schema: valid intent with explicit trigger', () => {
  const yaml = `
intent:
  id: manual-fold
  version: 1
  description: Explicit manual fold trigger
fold:
  trigger: explicit
  preserve:
    - user_query
    - decisions
    - error_context
    - final_answer
  discard:
    - intermediate_tool_outputs
    - reasoning_traces
    - raw_file_reads
guards:
  max_context: 120000
  max_cost_usd: 5.00
  max_turns: 50
`;
  const data = parseYaml(yaml);
  const result = IntentSchema.safeParse(data);
  assert.ok(result.success);
  const intent = result.data as any;
  assert.equal(intent.fold.trigger, 'explicit');
  assert.ok(!intent.fold.threshold);
});

// Test 4: Missing required field (intent.id)
test('schema: rejects missing intent.id', () => {
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
  max_cost_usd: 5.00
`;
  const data = parseYaml(yaml);
  const result = IntentSchema.safeParse(data);
  assert.ok(!result.success);
});

// Test 5: Missing required field (guards.max_context)
test('schema: rejects missing guards.max_context', () => {
  const yaml = `
intent:
  id: test
  version: 1
  description: Missing guard
fold:
  trigger: explicit
  preserve:
    - user_query
  discard:
    - reasoning_traces
guards:
  max_cost_usd: 5.00
`;
  const data = parseYaml(yaml);
  const result = IntentSchema.safeParse(data);
  assert.ok(!result.success);
});

// Test 6: Invalid trigger type
test('schema: rejects invalid trigger type', () => {
  const yaml = `
intent:
  id: invalid-trigger
  version: 1
  description: Bad trigger
fold:
  trigger: auto_fold
  threshold: 24000
  preserve:
    - user_query
  discard:
    - reasoning_traces
guards:
  max_context: 120000
  max_cost_usd: 5.00
`;
  const data = parseYaml(yaml);
  const result = IntentSchema.safeParse(data);
  assert.ok(!result.success);
});

// Test 7: token_threshold without threshold value
test('schema: rejects token_threshold without threshold', () => {
  const yaml = `
intent:
  id: missing-threshold
  version: 1
  description: Missing threshold
fold:
  trigger: token_threshold
  preserve:
    - user_query
  discard:
    - reasoning_traces
guards:
  max_context: 120000
  max_cost_usd: 5.00
`;
  const data = parseYaml(yaml);
  const result = IntentSchema.safeParse(data);
  assert.ok(!result.success);
});

// Test 8: explicit trigger with threshold (should fail)
test('schema: rejects explicit trigger with threshold', () => {
  const yaml = `
intent:
  id: explicit-with-threshold
  version: 1
  description: Explicit should not have threshold
fold:
  trigger: explicit
  threshold: 24000
  preserve:
    - user_query
  discard:
    - reasoning_traces
guards:
  max_context: 120000
  max_cost_usd: 5.00
`;
  const data = parseYaml(yaml);
  const result = IntentSchema.safeParse(data);
  assert.ok(!result.success);
});

// Test 9: Empty preserve array (should fail)
test('schema: rejects empty preserve array', () => {
  const yaml = `
intent:
  id: empty-preserve
  version: 1
  description: No preserved categories
fold:
  trigger: explicit
  preserve: []
  discard:
    - reasoning_traces
guards:
  max_context: 120000
  max_cost_usd: 5.00
`;
  const data = parseYaml(yaml);
  const result = IntentSchema.safeParse(data);
  assert.ok(!result.success);
});

// Test 10: Custom summary_budget
test('schema: accepts custom summary_budget', () => {
  const yaml = `
intent:
  id: custom-summary
  version: 1
  description: Custom budget
fold:
  trigger: explicit
  summary_budget: 4000
  preserve:
    - user_query
  discard:
    - reasoning_traces
guards:
  max_context: 120000
  max_cost_usd: 5.00
`;
  const data = parseYaml(yaml);
  const result = IntentSchema.safeParse(data);
  assert.ok(result.success);
  const intent = result.data as any;
  assert.equal(intent.fold.summary_budget, 4000);
});

// Test 11: README example validates cleanly
test('schema: README example YAML validates', () => {
  const yaml = `
intent:
  id: research-deep-dive
  version: 1
  description: Deep research with automatic folding
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
`;
  const data = parseYaml(yaml);
  const result = IntentSchema.safeParse(data);
  assert.ok(result.success);
  const intent = result.data as any;
  assert.equal(intent.intent.description, 'Deep research with automatic folding');
  assert.equal(intent.guards.max_turns, 50);
});

// Test 12: Type exports are available (compile-time only)
test('schema: exports IntentSchema for runtime use', () => {
  assert.ok(IntentSchema, 'IntentSchema should be exported');
  assert.ok(IntentSchema.safeParse, 'IntentSchema should have safeParse method');
});
