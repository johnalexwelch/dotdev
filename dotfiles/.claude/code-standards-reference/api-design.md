---
globs: "**/api/**,**/routes/**,**/endpoints/**"
---

# API Design Standards

Derived from Anthropic and OpenAI API conventions.

## Error Responses

- Wrap errors in an `error` object — never return bare error fields:

  ```json
  {"error": {"type": "not_found_error", "message": "...", "code": "resource_missing"}, "request_id": "req_abc123"}
  ```

- One typed exception class per HTTP status code (`BadRequestError` = 400, `NotFoundError` = 404, etc.).
- Always include `request_id` in error responses.

## Pagination

- Cursor-based, not offset-based.
- Response envelope: `{"data": [...], "has_more": true, "first_id": "...", "last_id": "..."}`.
- Parameters: `after_id`, `before_id`, `limit`.

## Retries & Resilience

- Default 2 retries with exponential backoff (0.5s initial, 8s max) plus jitter.
- Retry on: 408, 409, 429, 5xx.
- Respect `retry-after` headers. Return them on 429 responses.
- Use idempotency keys for non-GET retries.

## Versioning

- Additive changes only within a version (new optional params, new response fields).
- Never remove, rename, or change types of existing fields without a version bump.

## Connections

- TCP keepalive on all HTTP clients.
- Connection pool limits (max 1000 connections, 100 keepalive).
