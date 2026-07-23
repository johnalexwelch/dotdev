---
globs: "**/*.{py,ts,tsx,js,jsx}"
---

# Coding Standards

Derived from Anthropic and OpenAI engineering practices.

## Testing

- Write tests FIRST — verify they fail, then implement (TDD red-green-refactor).
- Parallel test execution (`-n auto` for pytest, concurrent for vitest).
- Treat warnings as errors in test suites.
- Expected failures that unexpectedly pass should be errors (`xfail_strict`).
- Gate tests that call real external APIs behind explicit markers.

## Type Safety

- Strict type checking is non-negotiable. No implicit `any` types.
- All function signatures must have full type annotations (params + return).
- Use `TYPE_CHECKING` guards to break circular imports.

## Error Handling

- Use typed exception hierarchies — one class per error category, not generic `Exception`.
- Errors should carry context (request IDs, status codes, original payloads) for debugging.
- Fail fast on configuration errors at startup.
- **Never use bare `except Exception`** — always catch the most specific exception types for the operation (e.g. `SQLAlchemyError` for DB, `httpx.HTTPError` for HTTP, `OSError` for I/O, `ValueError`/`TypeError` for parsing).
- Broad catches (`except Exception`) are acceptable ONLY in these cases, and should have a comment explaining why:
  - Observability/tracing — must not crash the app
  - Cache layers — graceful degradation on failure
  - Retry/resilience frameworks — catch-all by design
  - WebSocket/middleware boundaries — outermost error barriers
  - Transaction rollback handlers
  - Third-party library wrappers with no typed exception hierarchy (add comment citing the library)

## Accuracy & Citations

- Never fabricate file paths, line numbers, function names, symbols, or quoted text. Every citation must be verified to exist on the current branch (Read/Grep it) before writing it into a post-mortem, PR body, review comment, or commit message.
- Never claim a file was created/edited, a test passed, or a step completed without observed evidence — re-read the file or re-run the command and cite the actual output. "Done" is a verified fact, not an assumption.
- If a referenced location no longer exists (renamed, deleted, moved), say so explicitly rather than citing a stale or guessed location.

## Code Organization

- Keyword-only arguments (`*,`) for constructors and functions with 3+ optional params.
- Lazy load heavy resources with `cached_property` to minimize startup cost.
- Protocols/interfaces over deep inheritance hierarchies.
- Google-style docstrings when docstrings are needed.

## Async

- Async/await for all I/O. No callbacks, no blocking calls in async contexts.
- `asyncio.gather()` for parallel operations that can run concurrently.
- Async context managers for resource lifecycle (connections, streams).
