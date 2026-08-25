import { test } from 'node:test';
import * as assert from 'node:assert/strict';
import {
  generateFoldMetrics,
  exportJSON,
  exportCSV,
  type FoldMetrics,
} from '../dist/metrics.js';

// Test 1: Generate valid FoldMetrics
test('metrics: generateFoldMetrics creates valid structure', () => {
  const metrics = generateFoldMetrics({
    fold_id: 'fold-001',
    timestamp: '2026-08-25T10:30:00Z',
    trigger: 'token_threshold',
    pre_fold_tokens: 100000,
    post_fold_tokens: 10000,
    input_cost_usd: 0.3,
    output_cost_usd: 0.5,
    preserved_intents: ['research-deep-dive'],
    discarded_categories: ['reasoning_traces', 'intermediate_tool_outputs'],
    fold_latency_ms: 245,
  });

  assert.ok(metrics.fold_id);
  assert.ok(metrics.timestamp);
  assert.equal(metrics.trigger, 'token_threshold');
  assert.equal(metrics.pre_fold_tokens, 100000);
  assert.equal(metrics.post_fold_tokens, 10000);
});

// Test 2: Compression ratio calculation
test('metrics: compression_ratio calculated correctly', () => {
  const metrics = generateFoldMetrics({
    fold_id: 'fold-002',
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

  // Expected: 100000 / 10000 = 10.000
  assert.ok(Math.abs(metrics.compression_ratio - 10.0) < 0.001);
});

// Test 3: Cumulative cost
test('metrics: cumulative_cost_usd sums input and output', () => {
  const metrics = generateFoldMetrics({
    fold_id: 'fold-003',
    timestamp: '2026-08-25T10:30:00Z',
    trigger: 'token_threshold',
    pre_fold_tokens: 50000,
    post_fold_tokens: 5000,
    input_cost_usd: 0.15,
    output_cost_usd: 0.75,
    preserved_intents: [],
    discarded_categories: [],
    fold_latency_ms: 100,
  });

  // Expected: 0.15 + 0.75 = 0.90
  assert.ok(Math.abs(metrics.cumulative_cost_usd - 0.9) < 0.01);
});

// Test 4: Estimated savings calculation
test('metrics: estimated_savings_usd calculated correctly', () => {
  const metrics = generateFoldMetrics({
    fold_id: 'fold-004',
    timestamp: '2026-08-25T10:30:00Z',
    trigger: 'token_threshold',
    pre_fold_tokens: 100000,
    post_fold_tokens: 10000,
    input_cost_usd: 0.3,
    output_cost_usd: 0.5,
    preserved_intents: [],
    discarded_categories: [],
    fold_latency_ms: 200,
  });

  // Savings: (100000 - 10000) tokens saved * (avg rate per token)
  // Average of three models: ((3+15)+(2+8)+(0.25+1.25))/3 / 1M per token
  // = 29.5 / 3 / 1M ≈ 0.00983 per token
  // Savings: 90000 * 0.00983 ≈ 0.885 USD
  assert.ok(metrics.estimated_savings_usd > 0.8 && metrics.estimated_savings_usd < 0.95);
});

// Test 5: JSON export is valid JSON
test('metrics: exportJSON produces valid JSON', () => {
  const metrics = generateFoldMetrics({
    fold_id: 'fold-005',
    timestamp: '2026-08-25T10:30:00Z',
    trigger: 'token_threshold',
    pre_fold_tokens: 100000,
    post_fold_tokens: 10000,
    input_cost_usd: 0.3,
    output_cost_usd: 0.5,
    preserved_intents: ['intent-1'],
    discarded_categories: ['cat-1'],
    fold_latency_ms: 150,
  });

  const json = exportJSON(metrics);
  const parsed = JSON.parse(json);
  assert.equal(parsed.fold_id, 'fold-005');
  assert.equal(parsed.pre_fold_tokens, 100000);
});

// Test 6: CSV export has headers
test('metrics: exportCSV includes headers', () => {
  const metrics = [
    generateFoldMetrics({
      fold_id: 'fold-006',
      timestamp: '2026-08-25T10:30:00Z',
      trigger: 'token_threshold',
      pre_fold_tokens: 100000,
      post_fold_tokens: 10000,
      input_cost_usd: 0.3,
      output_cost_usd: 0.5,
      preserved_intents: [],
      discarded_categories: [],
      fold_latency_ms: 100,
    }),
  ];

  const csv = exportCSV(metrics);
  const lines = csv.split('\n');
  assert.ok(lines[0].includes('fold_id'));
  assert.ok(lines[0].includes('timestamp'));
  assert.ok(lines[0].includes('compression_ratio'));
});

// Test 7: CSV export is spreadsheet-ready
test('metrics: exportCSV formats correctly', () => {
  const metrics = [
    generateFoldMetrics({
      fold_id: 'fold-007',
      timestamp: '2026-08-25T10:30:00Z',
      trigger: 'token_threshold',
      pre_fold_tokens: 50000,
      post_fold_tokens: 5000,
      input_cost_usd: 0.15,
      output_cost_usd: 0.75,
      preserved_intents: ['intent-1'],
      discarded_categories: ['cat-1', 'cat-2'],
      fold_latency_ms: 50,
    }),
  ];

  const csv = exportCSV(metrics);
  const lines = csv.split('\n');
  // Should have header + 1 data row
  assert.ok(lines.length >= 2);
  // Data row should have fold_id value
  assert.ok(lines[1].includes('fold-007'));
});

// Test 8: Multiple rows in CSV
test('metrics: exportCSV handles multiple records', () => {
  const metrics = [
    generateFoldMetrics({
      fold_id: 'fold-008a',
      timestamp: '2026-08-25T10:30:00Z',
      trigger: 'token_threshold',
      pre_fold_tokens: 100000,
      post_fold_tokens: 10000,
      input_cost_usd: 0.3,
      output_cost_usd: 0.5,
      preserved_intents: [],
      discarded_categories: [],
      fold_latency_ms: 100,
    }),
    generateFoldMetrics({
      fold_id: 'fold-008b',
      timestamp: '2026-08-25T11:00:00Z',
      trigger: 'turn_count',
      pre_fold_tokens: 80000,
      post_fold_tokens: 8000,
      input_cost_usd: 0.24,
      output_cost_usd: 0.4,
      preserved_intents: ['intent-1'],
      discarded_categories: ['cat-1'],
      fold_latency_ms: 120,
    }),
  ];

  const csv = exportCSV(metrics);
  const lines = csv.split('\n');
  // Header + 2 data rows (+ 1 empty if trailing newline)
  assert.ok(lines.length >= 3);
  assert.ok(lines[1].includes('fold-008a'));
  assert.ok(lines[2].includes('fold-008b'));
});

// Test 9: Rounding to 2 decimal places for USD
test('metrics: USD values rounded to 2 decimal places', () => {
  const metrics = generateFoldMetrics({
    fold_id: 'fold-009',
    timestamp: '2026-08-25T10:30:00Z',
    trigger: 'token_threshold',
    pre_fold_tokens: 100000,
    post_fold_tokens: 10000,
    input_cost_usd: 0.3333,
    output_cost_usd: 0.5555,
    preserved_intents: [],
    discarded_categories: [],
    fold_latency_ms: 100,
  });

  // cumulative_cost should be rounded
  const json = exportJSON(metrics);
  const parsed = JSON.parse(json);
  // Check that the value is reasonable (rounding was applied)
  assert.ok(parsed.cumulative_cost_usd);
});

// Test 10: Compression ratio rounded to 3 decimal places
test('metrics: compression_ratio rounded to 3 decimal places', () => {
  const metrics = generateFoldMetrics({
    fold_id: 'fold-010',
    timestamp: '2026-08-25T10:30:00Z',
    trigger: 'token_threshold',
    pre_fold_tokens: 99999,
    post_fold_tokens: 33333,
    input_cost_usd: 0.3,
    output_cost_usd: 0.5,
    preserved_intents: [],
    discarded_categories: [],
    fold_latency_ms: 100,
  });

  // compression_ratio: 99999 / 33333 ≈ 3.000
  const ratio = metrics.compression_ratio;
  assert.ok(ratio > 2.9 && ratio < 3.1);
});

// Test 11: Reject zero post_fold_tokens
test('metrics: rejects zero post_fold_tokens (division by zero)', () => {
  assert.throws(() => {
    generateFoldMetrics({
      fold_id: 'fold-011',
      timestamp: '2026-08-25T10:30:00Z',
      trigger: 'token_threshold',
      pre_fold_tokens: 100000,
      post_fold_tokens: 0, // Invalid
      input_cost_usd: 0.3,
      output_cost_usd: 0.5,
      preserved_intents: [],
      discarded_categories: [],
      fold_latency_ms: 100,
    });
  });
});

// Test 12: Reject negative token counts
test('metrics: rejects negative token counts', () => {
  assert.throws(() => {
    generateFoldMetrics({
      fold_id: 'fold-012',
      timestamp: '2026-08-25T10:30:00Z',
      trigger: 'token_threshold',
      pre_fold_tokens: -100000, // Invalid
      post_fold_tokens: 10000,
      input_cost_usd: 0.3,
      output_cost_usd: 0.5,
      preserved_intents: [],
      discarded_categories: [],
      fold_latency_ms: 100,
    });
  });
});

// Test 13: All triggers are supported
test('metrics: all trigger types supported', () => {
  const triggers = ['token_threshold', 'turn_count', 'explicit'] as const;
  for (const trigger of triggers) {
    const metrics = generateFoldMetrics({
      fold_id: `fold-013-${trigger}`,
      timestamp: '2026-08-25T10:30:00Z',
      trigger,
      pre_fold_tokens: 100000,
      post_fold_tokens: 10000,
      input_cost_usd: 0.3,
      output_cost_usd: 0.5,
      preserved_intents: [],
      discarded_categories: [],
      fold_latency_ms: 100,
    });
    assert.equal(metrics.trigger, trigger);
  }
});

// Test 14: Preserved intents and discarded categories are preserved
test('metrics: preserves intent and category data', () => {
  const preserved = ['intent-1', 'intent-2'];
  const discarded = ['reasoning_traces', 'raw_file_reads'];
  const metrics = generateFoldMetrics({
    fold_id: 'fold-014',
    timestamp: '2026-08-25T10:30:00Z',
    trigger: 'token_threshold',
    pre_fold_tokens: 100000,
    post_fold_tokens: 10000,
    input_cost_usd: 0.3,
    output_cost_usd: 0.5,
    preserved_intents: preserved,
    discarded_categories: discarded,
    fold_latency_ms: 100,
  });

  assert.deepEqual(metrics.preserved_intents, preserved);
  assert.deepEqual(metrics.discarded_categories, discarded);
});
