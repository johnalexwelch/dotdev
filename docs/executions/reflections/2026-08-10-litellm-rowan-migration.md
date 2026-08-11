# Session Reflection: LiteLLM Rowan Migration

**Date**: 2026-08-10
**Goal**: Resume handoff, merge LiteLLM config PR, configure Rowan for proxy routing

## What Went Well

- Handoff recovery was smooth — clear "Start here" directive worked
- Testing LiteLLM Anthropic endpoint with curl before Python SDK — faster debugging
- Discovered LiteLLM accepts Anthropic format at `/v1/messages` — no SDK port needed
- Kept code change minimal (env var, 3 lines)

## What Went Wrong / Friction

1. **Remote confusion**: `origin` → Forgejo, `github` → GitHub. Synced to wrong remote initially, had to diagnose divergence (328 vs 55 commits).
2. **Hostname not resolvable**: Handoff said `http://pergamon:4000` but `pergamon` not in /etc/hosts on this machine. Had to SSH to get IP.
3. **Virtual key silent failure**: Virtual key returned "No connected db" error. Handoff mentioned virtual keys were "audit-only" but didn't flag they'd fail at runtime.
4. **Runbook/SDK mismatch**: `docs/runbooks/litellm-migration.md` documents `OPENAI_API_BASE` pattern, but Rowan uses Anthropic SDK which needs `ANTHROPIC_BASE_URL`.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|-------------------------|------------|-------------------|
| — | None | — | — |

## Lessons

1. **Always include IP alongside hostname in handoffs**: LAN hostnames depend on /etc/hosts or DNS config that may not exist on the resuming machine.
2. **Test auth modes before documenting**: The "audit-only virtual keys" framing masked that they'd error at runtime without database mode.
3. **Runbooks should document SDK-specific patterns**: OpenAI-compat vs Anthropic-native need different env vars.

## Proposed Improvements

- [ ] `docs/runbooks/litellm-migration.md` — Add Anthropic SDK section: `ANTHROPIC_BASE_URL` + note that `/v1/messages` works (priority: med)
- [ ] Handoff template convention — Always include IP when referencing LAN hostname (priority: low)
- [ ] `infra/litellm/README.md` — Clarify virtual keys require database mode to enforce, not just audit (priority: med)
