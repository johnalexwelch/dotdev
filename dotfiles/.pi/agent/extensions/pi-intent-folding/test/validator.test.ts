import { test } from 'node:test';
import * as assert from 'node:assert/strict';
import { validateIntentFile, formatValidationError } from '../dist/validator.js';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';

// Test 1: Valid YAML file passes
test('validator: valid intent file passes', () => {
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

  const tmpFile = path.join(os.tmpdir(), `intent-${Date.now()}.yaml`);
  try {
    fs.writeFileSync(tmpFile, yaml);
    const result = validateIntentFile(tmpFile);
    assert.ok(result.valid);
    assert.equal(result.errors.length, 0);
  } finally {
    fs.unlinkSync(tmpFile);
  }
});

// Test 2: Invalid trigger reported
test('validator: invalid trigger reported with error', () => {
  const yaml = `
intent:
  id: test-intent
  version: 1
  description: Test intent
fold:
  trigger: autocomplete
  threshold: 24000
  preserve:
    - user_query
  discard:
    - reasoning_traces
guards:
  max_context: 120000
  max_cost_usd: 5.0
`;

  const tmpFile = path.join(os.tmpdir(), `intent-${Date.now()}.yaml`);
  try {
    fs.writeFileSync(tmpFile, yaml);
    const result = validateIntentFile(tmpFile);
    assert.ok(!result.valid);
    assert.ok(result.errors.length > 0);
    assert.ok(
      result.errors[0].message.includes('trigger') ||
      result.errors[0].message.includes('autocomplete')
    );
  } finally {
    fs.unlinkSync(tmpFile);
  }
});

// Test 3: Missing required field reported
test('validator: missing required field reported', () => {
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

  const tmpFile = path.join(os.tmpdir(), `intent-${Date.now()}.yaml`);
  try {
    fs.writeFileSync(tmpFile, yaml);
    const result = validateIntentFile(tmpFile);
    assert.ok(!result.valid);
    assert.ok(result.errors.length > 0);
    assert.ok(
      result.errors[0].message.includes('intent') &&
      result.errors[0].message.includes('id')
    );
  } finally {
    fs.unlinkSync(tmpFile);
  }
});

// Test 4: token_threshold without threshold reported
test('validator: token_threshold without threshold reported', () => {
  const yaml = `
intent:
  id: test-intent
  version: 1
  description: Test intent
fold:
  trigger: token_threshold
  preserve:
    - user_query
  discard:
    - reasoning_traces
guards:
  max_context: 120000
  max_cost_usd: 5.0
`;

  const tmpFile = path.join(os.tmpdir(), `intent-${Date.now()}.yaml`);
  try {
    fs.writeFileSync(tmpFile, yaml);
    const result = validateIntentFile(tmpFile);
    assert.ok(!result.valid);
    assert.ok(result.errors.length > 0);
    assert.ok(
      result.errors[0].message.includes('threshold') ||
      result.errors[0].message.includes('token_threshold')
    );
  } finally {
    fs.unlinkSync(tmpFile);
  }
});

// Test 5: Format error message with suggestions
test('validator: formatValidationError includes suggestions', () => {
  const error = {
    message: 'unknown trigger',
    path: ['fold', 'trigger'],
    line: 5,
    column: 3,
  };

  const formatted = formatValidationError('test.yaml', error);
  assert.ok(formatted.includes('test.yaml'));
  assert.ok(formatted.includes('5'));
  assert.ok(formatted.includes('error'));
});

// Test 6: Syntax error in YAML reported
test('validator: YAML syntax error reported', () => {
  const yaml = `
intent:
  id: test
  version: 1
  description: Test
fold:
  trigger: [invalid yaml syntax here
  preserve:
    - user_query
`;

  const tmpFile = path.join(os.tmpdir(), `intent-${Date.now()}.yaml`);
  try {
    fs.writeFileSync(tmpFile, yaml);
    const result = validateIntentFile(tmpFile);
    assert.ok(!result.valid);
    assert.ok(result.errors.length > 0);
    assert.ok(result.errors[0].message.includes('Failed to parse'));
  } finally {
    fs.unlinkSync(tmpFile);
  }
});

// Test 7: File not found error
test('validator: file not found reported', () => {
  const nonExistentFile = path.join(os.tmpdir(), `nonexistent-${Date.now()}.yaml`);
  const result = validateIntentFile(nonExistentFile);
  assert.ok(!result.valid);
  assert.ok(result.errors.length > 0);
  assert.ok(result.errors[0].message.includes('not found') || result.errors[0].message.includes('ENOENT'));
});

// Test 8: All trigger types pass
test('validator: all valid trigger types pass', () => {
  const triggers = ['token_threshold', 'turn_count', 'explicit'];
  for (const trigger of triggers) {
    const yaml = trigger === 'explicit'
      ? `
intent:
  id: test-${trigger}
  version: 1
  description: Test
fold:
  trigger: ${trigger}
  preserve:
    - user_query
  discard:
    - reasoning_traces
guards:
  max_context: 120000
  max_cost_usd: 5.0
`
      : `
intent:
  id: test-${trigger}
  version: 1
  description: Test
fold:
  trigger: ${trigger}
  threshold: 100
  preserve:
    - user_query
  discard:
    - reasoning_traces
guards:
  max_context: 120000
  max_cost_usd: 5.0
`;

    const tmpFile = path.join(os.tmpdir(), `intent-${trigger}-${Date.now()}.yaml`);
    try {
      fs.writeFileSync(tmpFile, yaml);
      const result = validateIntentFile(tmpFile);
      assert.ok(result.valid, `${trigger} should be valid`);
    } finally {
      fs.unlinkSync(tmpFile);
    }
  }
});

// Test 9: Result includes file path
test('validator: result includes file path', () => {
  const yaml = `
intent:
  id: test-intent
  version: 1
  description: Test intent
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

  const tmpFile = path.join(os.tmpdir(), `intent-${Date.now()}.yaml`);
  try {
    fs.writeFileSync(tmpFile, yaml);
    const result = validateIntentFile(tmpFile);
    assert.equal(result.file_path, tmpFile);
  } finally {
    fs.unlinkSync(tmpFile);
  }
});

// Test 10: Multiple errors reported
test('validator: multiple errors reported', () => {
  const yaml = `
intent:
  version: 1
fold:
  trigger: invalid_trigger
  preserve: []
guards:
  max_cost_usd: 5.0
`;

  const tmpFile = path.join(os.tmpdir(), `intent-${Date.now()}.yaml`);
  try {
    fs.writeFileSync(tmpFile, yaml);
    const result = validateIntentFile(tmpFile);
    assert.ok(!result.valid);
    assert.ok(result.errors.length > 0);
  } finally {
    fs.unlinkSync(tmpFile);
  }
});
