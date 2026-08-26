/**
 * Pre-flight enforcement: Require intent for specific task patterns
 *
 * Blocks session start if:
 * 1. Task matches a requiring-intent pattern
 * 2. No --intent flag provided
 *
 * Exit codes:
 * 0 = check passed (intent provided or not required)
 * 1 = intent required but missing
 */

export interface TaskPattern {
  pattern: RegExp;
  reason: string;
  examples: string[];
}

// Task patterns that require intent folding
export const INTENT_REQUIRED_PATTERNS: TaskPattern[] = [
  {
    pattern: /\b(research|survey|investigate|deep.?dive)\b/i,
    reason: "Research tasks typically grow large and benefit from folding",
    examples: [
      "deep research on X",
      "investigate issue Y",
      "survey existing solutions",
    ],
  },
  {
    pattern: /\b(multi.?file|across.?\d+.?files|refactor.?auth|migrate)\b/i,
    reason: "Multi-file work generates high context volume",
    examples: [
      "refactor auth across 15 files",
      "multi-file migration",
      "update all controllers",
    ],
  },
  {
    pattern: /\b(comprehensive|exhaustive|complete.?audit|full.?analysis)\b/i,
    reason: "Comprehensive tasks require cost/context guards",
    examples: [
      "comprehensive security audit",
      "exhaustive performance analysis",
    ],
  },
  {
    pattern: /\$([\d.]+)\s*(usd|dollars?)\s*budget/i,
    reason: "Explicit budget mention requires cost tracking",
    examples: ["$5 budget for this task", "cap at $10 USD"],
  },
];

export interface PreflightResult {
  passed: boolean;
  exitCode: number;
  summary: string;
  matched_patterns: TaskPattern[];
  recommendation?: string;
}

export function checkPreflight(
  taskDescription: string,
  intentProvided: boolean,
): PreflightResult {
  const matchedPatterns: TaskPattern[] = [];

  for (const pattern of INTENT_REQUIRED_PATTERNS) {
    if (pattern.pattern.test(taskDescription)) {
      matchedPatterns.push(pattern);
    }
  }

  if (matchedPatterns.length === 0) {
    // No patterns matched — intent optional
    return {
      passed: true,
      exitCode: 0,
      summary: "✅ Intent optional for this task type",
      matched_patterns: [],
    };
  }

  if (intentProvided) {
    // Intent required and provided
    return {
      passed: true,
      exitCode: 0,
      summary: "✅ Intent provided (required)",
      matched_patterns: matchedPatterns,
    };
  }

  // Intent required but missing
  const reasons = matchedPatterns.map((p) => p.reason).join("; ");
  return {
    passed: false,
    exitCode: 1,
    summary: `❌ Intent required but missing: ${reasons}`,
    matched_patterns: matchedPatterns,
    recommendation:
      "Create an intent YAML with fold triggers and guards, then use: pi --intent path/to/intent.yaml",
  };
}

export function runPreflightCLI(): void {
  const args = process.argv.slice(2);

  if (args.length === 0 || args.includes("--help")) {
    process.stdout.write(`
Usage: npm run preflight -- "<task-description>" [--intent-provided]

Check if a task requires intent folding.

Options:
  --intent-provided   Indicate that --intent flag was provided

Exit codes:
  0   Check passed
  1   Intent required but missing

Examples:
  npm run preflight -- "research agent architectures"
  npm run preflight -- "fix typo in README" --intent-provided
  npm run preflight -- "comprehensive security audit"

Required patterns:
${INTENT_REQUIRED_PATTERNS.map((p) => `  - ${p.reason}`).join("\n")}
`);
    process.exit(0);
  }

  const taskDescription = args[0];
  const intentProvided = args.includes("--intent-provided");

  const result = checkPreflight(taskDescription, intentProvided);

  process.stdout.write(result.summary + "\n");

  if (result.matched_patterns.length > 0) {
    process.stdout.write("\nMatched patterns:\n");
    for (const pattern of result.matched_patterns) {
      process.stdout.write(`  - ${pattern.reason}\n`);
      process.stdout.write(`    Examples: ${pattern.examples.join(", ")}\n`);
    }
  }

  if (result.recommendation) {
    process.stdout.write(`\n${result.recommendation}\n`);
  }

  process.exit(result.exitCode);
}
