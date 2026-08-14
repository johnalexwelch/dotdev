# Session Reflection: LiteLLM Pergamon Deployment

**Date**: 2026-08-10
**Goal**: Deploy LiteLLM proxy on Pergamon and fix configuration issues

## What Went Well

- **Live verification over proxy**: Queried Anthropic `/v1/models` API directly to find real model names instead of trusting the config file's assumed names
- **Iterative debugging**: Methodically traced env var loading failure (mounted as file → not loaded → switch to env_file directive)
- **Two-remote awareness**: Recognized `origin` (Forgejo) vs `github` (GitHub) and pulled from the correct remote after PR merge confusion

## What Went Wrong / Friction

- **Model names in config were fictional**: `claude-sonnet-4-20250514` and `claude-3-5-haiku-20241022` don't exist. The original implementation (PR #742) shipped with untested model names. Required live Anthropic API call to discover real names: `claude-sonnet-4-5-20250929`, `claude-haiku-4-5-20251001`.
- **Docker env file mount vs load**: Mounting `provider-keys.env` as `/app/.env` doesn't auto-load it as environment variables. LiteLLM (or Docker) doesn't parse mounted .env files — need `env_file:` directive in docker-compose.
- **Health endpoint auth change**: After setting `LITELLM_MASTER_KEY`, health check started returning 401. Expected behavior but initially confused the debugging.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|-------------------------|------------|-------------------|
| — | No explicit corrections | — | — |

## Lessons

1. **Model names are volatile**: Anthropic model names change (e.g., `claude-sonnet-4-5-20250929`). Never hardcode assumed names — verify against `/v1/models` before shipping.

2. **Docker env_file ≠ volume mount**: A volume-mounted `.env` file is just a file on disk. To inject as env vars, use `env_file:` directive or `environment:` block. This is a common Docker pitfall.

3. **LiteLLM health requires auth when master_key is set**: The `/health` endpoint returns 401 without the `Authorization: Bearer <key>` header once a master key is configured. Document this in runbooks.

## Proposed Improvements

- [ ] `infra/litellm/README.md` — Add "Verify model names" section with `curl /v1/models` command before deployment (priority: med)
- [ ] `docs/runbooks/litellm-migration.md` — Document that health endpoint requires auth when master_key is set (priority: low)
- [ ] `infra/litellm/scripts/verify-models.sh` — Script to verify configured model names against live Anthropic API before container start (priority: low)

## Better Way Found

- **Query live API for model names**: Instead of trusting documentation or config examples, `curl https://api.anthropic.com/v1/models` returns the authoritative list. This should be a standard pre-deployment check for any LLM proxy config.
