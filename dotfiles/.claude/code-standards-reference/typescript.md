---
globs: "**/*.{ts,tsx}"
---

# TypeScript Standards

Derived from Anthropic and OpenAI SDK conventions.

## Type Safety
- Strict mode enabled (`strict: true` in tsconfig).
- No `any` types — use `unknown` and narrow with type guards.
- Zod for runtime validation of external data (API responses, user input).

## Error Handling
- Typed error classes per error category, not string messages.
- Errors carry context: status codes, request IDs, original response data.

## Testing
- Vitest with React Testing Library for component tests.
- Inline snapshot testing for response validation.

## Patterns
- Streaming via event handlers (`.on('event', handler)`) with async iterators.
- Multiple tsconfig files for different build targets (build, dist, test).
- Prettier for formatting, ESLint for logic rules — don't overlap their responsibilities.
