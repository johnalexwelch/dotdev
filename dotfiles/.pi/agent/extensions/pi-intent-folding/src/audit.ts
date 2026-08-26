/**
 * Audit CLI: Verify intent usage and compliance post-session
 *
 * Checks:
 * 1. Was an intent loaded?
 * 2. Were guards checked?
 * 3. Did any violations occur?
 * 4. Were folds executed when expected?
 *
 * Exit codes:
 * 0 = compliant
 * 1 = no intent (when required)
 * 2 = guard violations
 * 3 = malformed telemetry
 */

import fs from 'fs';
import path from 'path';

interface TelemetryEvent {
  timestamp: string;
  event: string;
  [key: string]: unknown;
}

interface AuditResult {
  compliant: boolean;
  exitCode: number;
  summary: string;
  details: {
    intent_loaded: boolean;
    intent_id?: string;
    guard_checks: number;
    guard_violations: number;
    folds_executed: number;
    events_total: number;
  };
  violations: string[];
}

export function auditSession(sessionId: string, requireIntent = false): AuditResult {
  const sessionDir = path.join(process.env.HOME || '', '.pi', 'sessions', sessionId);
  const telemetryPath = path.join(sessionDir, 'intent-events.jsonl');

  // Check if telemetry exists
  if (!fs.existsSync(telemetryPath)) {
    if (requireIntent) {
      return {
        compliant: false,
        exitCode: 1,
        summary: '❌ No intent telemetry found (required)',
        details: {
          intent_loaded: false,
          guard_checks: 0,
          guard_violations: 0,
          folds_executed: 0,
          events_total: 0,
        },
        violations: ['No intent loaded (intent required for this session type)'],
      };
    }

    return {
      compliant: true,
      exitCode: 0,
      summary: '✅ No intent used (not required)',
      details: {
        intent_loaded: false,
        guard_checks: 0,
        guard_violations: 0,
        folds_executed: 0,
        events_total: 0,
      },
      violations: [],
    };
  }

  // Parse telemetry
  const content = fs.readFileSync(telemetryPath, 'utf-8');
  const lines = content.trim().split('\n');
  const events: TelemetryEvent[] = [];

  for (const line of lines) {
    try {
      events.push(JSON.parse(line));
    } catch (error) {
      return {
        compliant: false,
        exitCode: 3,
        summary: '❌ Malformed telemetry (parse error)',
        details: {
          intent_loaded: false,
          guard_checks: 0,
          guard_violations: 0,
          folds_executed: 0,
          events_total: lines.length,
        },
        violations: ['Telemetry JSONL parse error'],
      };
    }
  }

  // Analyze events
  const intentLoaded = events.some((e) => e.event === 'intent_loaded');
  const intentLoadFailed = events.some((e) => e.event === 'intent_load_failed');
  const guardChecks = events.filter((e) => e.event === 'guard_check').length;
  const guardViolations = events.filter((e) => e.event === 'guard_violation').length;
  const foldsExecuted = events.filter((e) => e.event === 'fold_executed').length;

  const intentLoadedEvent = events.find((e) => e.event === 'intent_loaded');
  const intentId = intentLoadedEvent?.intent_id as string | undefined;

  const violations: string[] = [];

  if (intentLoadFailed) {
    violations.push('Intent load failed');
  }

  if (guardViolations > 0) {
    violations.push(`${guardViolations} guard violation(s) occurred`);
  }

  const compliant = violations.length === 0 && (intentLoaded || !requireIntent);
  const exitCode = compliant ? 0 : guardViolations > 0 ? 2 : 1;

  const summary = compliant
    ? `✅ Session compliant (intent: ${intentId || 'none'}, ${foldsExecuted} fold(s))`
    : `❌ Session non-compliant: ${violations.join(', ')}`;

  return {
    compliant,
    exitCode,
    summary,
    details: {
      intent_loaded: intentLoaded,
      intent_id: intentId,
      guard_checks: guardChecks,
      guard_violations: guardViolations,
      folds_executed: foldsExecuted,
      events_total: events.length,
    },
    violations,
  };
}

export function runAuditCLI(): void {
  const args = process.argv.slice(2);

  if (args.length === 0 || args.includes('--help')) {
    console.log(`
Usage: npm run audit -- <session-id> [--require-intent]

Verify intent usage and compliance for a Pi session.

Options:
  --require-intent   Fail if no intent was loaded

Exit codes:
  0   Compliant
  1   No intent (when required)
  2   Guard violations
  3   Malformed telemetry

Examples:
  npm run audit -- abc123
  npm run audit -- abc123 --require-intent
`);
    process.exit(0);
  }

  const sessionId = args[0];
  const requireIntent = args.includes('--require-intent');

  const result = auditSession(sessionId, requireIntent);

  console.log(result.summary);
  console.log('');
  console.log('Details:');
  console.log(`  Intent loaded: ${result.details.intent_loaded ? '✅' : '❌'}`);
  if (result.details.intent_id) {
    console.log(`  Intent ID: ${result.details.intent_id}`);
  }
  console.log(`  Guard checks: ${result.details.guard_checks}`);
  console.log(`  Guard violations: ${result.details.guard_violations}`);
  console.log(`  Folds executed: ${result.details.folds_executed}`);
  console.log(`  Total events: ${result.details.events_total}`);

  if (result.violations.length > 0) {
    console.log('');
    console.log('Violations:');
    for (const violation of result.violations) {
      console.log(`  - ${violation}`);
    }
  }

  process.exit(result.exitCode);
}
