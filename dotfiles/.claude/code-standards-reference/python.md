---
globs: "**/*.py"
---

# Python Standards

Derived from Anthropic and OpenAI SDK conventions.

## Tooling
- Ruff for linting + formatting (rules: `I, B, F401, E722, ARG, UP, C4`).
- Pyright strict mode as primary type checker. MyPy as secondary.
- Line length: 120 for libraries, 100 for applications.
- Import sorting: length-sort, combine-as-imports.

## Validation
- Pydantic for data models and settings validation.
- `__post_init__` validation on dataclasses for runtime type checks.
- Use sentinel values (`NotGiven`) over `None` when distinguishing "not provided" from "explicitly null" matters.

## Testing
- pytest with `asyncio_mode = "auto"` — no manual `@pytest.mark.asyncio` decorators.
- Session-scoped event loops for async test suites.
- Coverage exclusions: `TYPE_CHECKING` blocks, `@abstractmethod`, `NotImplementedError`, `logger.debug`.
- Flag `print()` / `pprint()` calls in lint — don't auto-fix them.

## Patterns
- Dataclass fields with `default_factory` for mutable defaults.
- `cached_property` for lazy-loaded resources.
- `ExceptionGroup` with strict semantics for concurrent error handling.
- Avoid async generators except inside `@asynccontextmanager`.
