import * as fs from 'node:fs';
import * as path from 'node:path';
import { parseIntentYAML } from './guards.js';

/**
 * Validator CLI tool for intent YAML configuration.
 *
 * Loads user's intent YAML files, runs guards, and reports errors with
 * file:line:col context and actionable remediation hints.
 */

export interface ValidationError {
  message: string;
  path?: string[];
  line?: number;
  column?: number;
}

export interface ValidationResult {
  valid: boolean;
  file_path: string;
  errors: ValidationError[];
}

/**
 * Validate an intent YAML file.
 * Checks schema, hard guards (for sanity), and reports all errors.
 *
 * @param file_path Path to intent YAML file
 * @returns Validation result with file path and errors
 */
export function validateIntentFile(file_path: string): ValidationResult {
  const errors: ValidationError[] = [];

  // Check file exists
  if (!fs.existsSync(file_path)) {
    errors.push({
      message: `File not found: ${file_path}`,
    });
    return { valid: false, file_path, errors };
  }

  // Read file
  let yaml: string;
  try {
    yaml = fs.readFileSync(file_path, 'utf-8');
  } catch (err) {
    errors.push({
      message: `Failed to read file: ${(err as Error).message}`,
    });
    return { valid: false, file_path, errors };
  }

  // Parse YAML
  try {
    const intent = parseIntentYAML(yaml);
    // If we get here, validation passed
    return { valid: true, file_path, errors: [] };
  } catch (err) {
    errors.push({
      message: (err as Error).message,
    });
    return { valid: false, file_path, errors };
  }
}

/**
 * Format a validation error for user display.
 * Includes file:line:col context and suggestions.
 *
 * @param file_path Path to file
 * @param error Validation error
 * @returns Formatted error string
 */
export function formatValidationError(file_path: string, error: ValidationError): string {
  const location = error.line ? `${file_path}:${error.line}:${error.column || 0}` : file_path;
  const path_str = error.path ? error.path.join('.') : '';

  let output = `${location}: error: ${error.message}`;
  if (path_str) {
    output += ` (${path_str})`;
  }

  return output;
}

/**
 * CLI entrypoint: validate intent YAML file and print results.
 * Exit code: 0 on valid, 1 on invalid.
 *
 * Usage: node validator.js <file_path>
 */
export function runValidatorCLI(args: string[]): number {
  if (args.length < 2) {
    console.error('Usage: validator <file_path>');
    console.error('Example: npm run validate-schema -- ~/.pi/intents/my-task.yaml');
    return 1;
  }

  const file_path = args[1];
  const result = validateIntentFile(file_path);

  if (result.valid) {
    console.log(`✓ Valid intent configuration: ${file_path}`);
    return 0;
  } else {
    console.error(`✗ Validation failed: ${file_path}`);
    for (const error of result.errors) {
      console.error(formatValidationError(result.file_path, error));
    }
    return 1;
  }
}

// CLI entry point (when run as a script)
if (import.meta.url === `file://${process.argv[1]}`) {
  const exitCode = runValidatorCLI(process.argv);
  process.exit(exitCode);
}
