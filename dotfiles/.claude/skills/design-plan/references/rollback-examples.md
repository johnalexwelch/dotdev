# Rollback Examples

Use these examples to make each phase's Rollback field concrete.

## Rollback Standard

Every phase needs a specific recovery path, not generic "rollback if needed"
language. Name the exact commit, flag, toggle, backup, old code path, or
reversion mechanism whenever possible.

For production systems with live users, verify the rollback path before the
phase starts.

## Common Rollback Patterns

| Situation | Good rollback |
|-----------|---------------|
| Small code change | Revert the phase commit; rerun baseline tests. |
| Pilot/canary | Revert the canary commit; main returns to pre-pilot state. |
| Feature behind flag | Disable `<flag-name>`; keep new code dark until fixed. |
| Replacing old code path | Re-enable the old code path via `<toggle/config>`; leave replacement disabled. |
| Data migration | Restore from `<backup-name>` or run the documented down migration; verify row counts/checksums. |
| File deletion | Revert the deletion commit; replacement remains untouched or disabled. |
| External integration | Switch traffic back to `<old-provider>` using `<config/env var>`. |
| Generated artifacts | Regenerate from the previous source version or revert generated files. |
| Docs-only change | Revert docs commit; no runtime impact. |

## Examples

```markdown
**Rollback:** Revert `phase-1-canary` commit; no schema or config changes were introduced.
```

```markdown
**Rollback:** Disable `new_checkout_flow` in LaunchDarkly and route users back
to the existing checkout path. Keep the new code deployed but dark while tests
are fixed.
```

```markdown
**Rollback:** Restore `users` and `orders` from the pre-migration snapshot
`2026-04-20-before-phase-3`; verify row counts match the snapshot manifest.
```

```markdown
**Rollback:** Revert the deletion commit for `scripts/legacy-sync.sh`; Phase 2's
replacement remains in place but is not invoked until re-verified.
```

```markdown
**Rollback:** Re-enable `OLD_AUTH_PROVIDER_URL` in deployment config and redeploy.
Run the login smoke test against the restored provider.
```

```markdown
**Rollback:** Revert generated artifacts and rerun the previous generator
version pinned in `package-lock.json`.
```

## Anti-Examples

Avoid:

- `Rollback: revert if needed.`
- `Rollback: none.`
- `Rollback: fix forward.`
- `Rollback: restore old behavior.`

Only use `Rollback: n/a` for true hygiene phases where no state changes happen,
such as baseline preflight.
