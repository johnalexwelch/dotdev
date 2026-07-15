# Verification Gates

## Human Tasks

Write every `[human]` task to `## Pending human` in the outcome file in
original order and verbatim. Print the list to chat with:

```text
Phase <N> has <K> pending `[human]` task(s):
```

Never execute `[human]` tasks, including under `dry_run`.

If any `[human]` task exists, the phase is blocked:

- No commit.
- No auto-proceed.
- User resolves in chat or in a worktree.
- Suggest `/setup-worktree phase=<N>` when the user wants an isolated
  checkout of the halted phase branch.

## Verification Subagent

If there are no scope violations, failed `[auto]` tasks, or pending
`[human]` tasks, dispatch one read-only `general-purpose` subagent with
the phase's Verification text.

```markdown
Verify the following claim against the current working tree. Each
sentence is a falsifiable check: produce PASS/FAIL per claim with
evidence (file reads, command outputs, counts). Do not modify anything.

**Verification text (from plan section 5.<N>):**
<verbatim Verification paragraph>

Return a structured report: overall PASS/FAIL, per-claim breakdown,
and any claim you could not definitively verify (UNVERIFIED).
```

## Result Semantics

- **PASS:** proceed to commit.
- **FAIL:** do not commit. Halt, embed the verifier report in the
  outcome file, and quote the phase Rollback text to the user as
  reference.
- **UNVERIFIED:** treat as PASS only if every falsifiable claim passed
  and the unverified claims are clearly informational. Treat as FAIL if
  an unverified claim is load-bearing. When in doubt, halt and surface
  for user judgment.

## Commit Gate

Only after verification PASS:

- Stage files touched by `[auto]` clusters with `git add -A` scoped to
  the union of granted scopes.
- Never stage paths outside granted scopes.
- Commit using the phase commit schema from
  `references/branch-naming.md`.
- Record commit hash and full message in `## Commits`.

## Failure Behavior

| Failure | Behavior |
|---------|----------|
| Working tree dirty at preflight | Abort. User must commit or stash before starting. |
| `plan_path` empty and no `docs/plans/*.md` | Abort. Tell user to run `/design-plan` first or pass `plan_path`. |
| `plan_path` set but file missing | Abort with the path that was tried. |
| Phase N header not found in section 5 | Abort. List phase headers present. |
| Plan has any ID scheme | Echo verbatim into commit messages and outcome file. No scheme-specific validation. |
| Plan has no IDs in Addresses lines | Degraded. Proceed, warn in outcome file, and omit commit parenthetical. |
| Branch prefix heuristic misfires | User can override with `branch_prefix=fix`, `branch_prefix=refactor`, or `branch_prefix=feat` on the next invocation. |
| Existing outcome file and `resume == false` | Abort. User must delete it or pass `resume=true`. |
| Empty `Tasks` block | Fatal. Abort. |
| Phase branch already exists | Abort. Prior attempt exists; user renames or deletes it. |
| `[auto]` subagent fails a task | No later cluster dispatches. Outcome records failure. No commit. |
| Scope violation detected | Halt. `## Scope violations` populated. No commit. |
| `[human]` task present | Phase blocked. `## Pending human` populated. No commit. No auto-proceed. |
| Verification FAIL | No commit. Halt. Rollback text surfaced. |
| Verification UNVERIFIED load-bearing claim | Halt for user judgment. |
| `dry_run == true` | No branch, no commit, no mutation. Outcome still written with tasks marked `pending (dry_run)`. |
| Phase N+1 does not exist | Halt with success: plan complete. |
| Phase N+1 preflight fails mid-chain | Halt. Phase N commit stands; user fixes Phase N+1 and re-invokes with `phase=<N+1>`. |
| `resume == true` with no prior outcome file | Degrade to a fresh invocation with a note. |
