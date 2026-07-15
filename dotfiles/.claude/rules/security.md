---
globs: "**/*.{py,ts,tsx,js,jsx}"
---

# Security Standards

Derived from Anthropic and OpenAI engineering practices.

## Secrets
- Environment variables for all secrets. Never hardcode, never use config files for keys.
- Redact sensitive headers (`authorization`, `api-key`) before logging.
- Never log API keys, tokens, passwords, database connection strings, or user PII.

## Input Validation
- Validate all external input at API boundaries with Pydantic (Python) or Zod (TypeScript).
- Parameterized queries only — never string interpolation for SQL.
- Set explicit request size limits on every endpoint.

## Dependencies
- Run `pip-audit` (Python) and `npm audit` (TypeScript) in CI.
- Flag `print()`/`pprint()` calls in lint — they can leak secrets to stdout.

## Error Responses
- Never expose stack traces, internal paths, or system details in error responses.
- Return structured error objects, not raw exception messages.

## Auth
- Rate limiting middleware on all public endpoints. Return `429` with `retry-after` headers.
- Fail fast on missing or invalid auth — don't process the request first.
