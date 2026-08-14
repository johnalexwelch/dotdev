/**
 * Pure secret redactor — no pi/package imports so it stays unit-testable.
 *
 * ponytail: masks (a) exact values of known secret env vars and (b) common
 * `secret-ish = value` / DB-URI-password shapes. Ceiling: it will NOT catch an
 * unknown high-entropy secret that isn't in the env and doesn't match a keyword
 * pattern. Upgrade path: add an entropy/gitleaks pass if you need that. The
 * broad "any long base64 blob" rule is deliberately omitted — it would nuke git
 * SHAs, IDs, and hashes in normal tool output.
 */

const MASK = "«REDACTED»";

// Env vars whose *values* must never appear in output. Extend via PI_SCRUB_VARS
// (comma-separated) without editing this file.
const DEFAULT_SECRET_VARS = [
  "REDSHIFT_PASS",
  "SENSITIVE_REDSHIFT_PASS",
  "AWS_SECRET_ACCESS_KEY",
  "AWS_SESSION_TOKEN",
  "GITHUB_TOKEN",
  "GH_TOKEN",
  "OPENAI_API_KEY",
  "ANTHROPIC_API_KEY",
];

function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export interface RedactorOptions {
  env?: NodeJS.ProcessEnv;
  /** Minimum literal length to bother masking (avoids masking trivial values). */
  minLiteralLength?: number;
}

export function makeRedactor(opts: RedactorOptions = {}): (text: string) => string {
  const env = opts.env ?? process.env;
  const minLen = opts.minLiteralLength ?? 6;

  const extra = (env.PI_SCRUB_VARS ?? "")
    .split(",")
    .map((v) => v.trim())
    .filter(Boolean);
  const varNames = [...new Set([...DEFAULT_SECRET_VARS, ...extra])];

  // Longest first so a value that contains a shorter one is masked whole.
  const literals = varNames
    .map((name) => env[name])
    .filter((v): v is string => typeof v === "string" && v.length >= minLen)
    .sort((a, b) => b.length - a.length);

  const literalRe = literals.length
    ? new RegExp(literals.map(escapeRegExp).join("|"), "g")
    : null;

  // key = value / key: value for secret-ish keys → keep key, mask value.
  // Identifier prefix allowed so DB_PASSWORD / github-token / X_API_KEY match.
  const assignRe =
    /\b([A-Za-z0-9_-]*(?:password|passwd|secret|token|api[_-]?key|access[_-]?key|private[_-]?key|client[_-]?secret|pwd|pass))(["']?\s*[:=]\s*["']?)([^\s"',;]+)/gi;

  // Values that are clearly not secrets — don't mask these (avoids turning
  // `client_secret=None`, `pass = 5`, short SQL codes into «REDACTED» noise).
  const isTrivialValue = (v: string) =>
    v.length < 8 || /^(none|null|nil|true|false|undefined|\d+)$/i.test(v);

  // DB connection URI: scheme://user:PASSWORD@host → mask only the password.
  const uriRe = /\b([a-z][a-z0-9+.-]*:\/\/[^:@/\s]+:)([^@/\s]+)(@)/gi;

  return (text: string): string => {
    if (!text) return text;
    let out = text;
    if (literalRe) out = out.replace(literalRe, MASK);
    out = out.replace(uriRe, (_m, pre, _pw, at) => `${pre}${MASK}${at}`);
    out = out.replace(assignRe, (m, key, sep, val) => (isTrivialValue(val) ? m : `${key}${sep}${MASK}`));
    return out;
  };
}

export const _MASK = MASK;
