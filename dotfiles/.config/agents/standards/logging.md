---
globs: "**/*.{py,ts,tsx}"
---

# Logging & Observability Standards

Derived from Anthropic and OpenAI SDK practices.

## Logger Setup

- Named loggers per module: `logging.getLogger("app.module")`. Never use the root logger.
- Control log level via environment variable (e.g., `IRIS_LOG=debug`).
- Format: `[%(asctime)s - %(name)s:%(lineno)d - %(levelname)s] %(message)s`

## Log Levels

- **DEBUG**: HTTP request/response details, retry decisions, cache hits/misses.
- **INFO**: Service startup, configuration loaded, connections established.
- **WARNING**: Deprecated feature usage, approaching rate limits, degraded performance.
- **ERROR**: Request failures, unhandled exceptions, external service errors.
- **CRITICAL**: Service unable to start, database connection lost.

## What to Log

- Every outbound HTTP request (method, URL, status code, duration).
- Retry attempts with count and backoff duration.
- Rate limit events with retry-after values.

## What NOT to Log

- Request/response bodies (may contain user data).
- API keys, tokens, passwords, connection strings — even partially.
- Full SQL queries with parameter values (log the template, not the values).

## Request Tracing

- Generate a request ID for every incoming request.
- Return it in response headers.
- Include it in all log entries for that request.
- Pass it to downstream service calls.
