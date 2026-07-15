# State Cockpit — `docs/executions/state.yaml`

Single machine-readable record of the active workflow run. Lets any agent
resume exactly where a prior session stopped without replaying the transcript.
Referenced by `workflow-router` (writer/resumer), `handoff` (reader), and
`workflow-finalize` (closer). Do not duplicate this schema into skills — link here.

## Scope

- **One active run per repo.** New confirmed route overwrites the file.
  <!-- ponytail: single-run only. Add a `runs/` archive dir + per-worktree files
       when parallel worktrees actually collide, not before. -->
- **Project repos only.** Path is `docs/executions/state.yaml` (sibling of
  `docs/executions/handoffs/`). If there is no project repo / ephemeral session,
  skip the cockpit entirely — it is an optimization, never a gate.

## Schema

```yaml
run_id: <YYYY-MM-DD>-<slug>      # stable id for this run
workflow: <skill-name>           # target workflow the router dispatched
budget: direct|one-reviewer|multi-lane|team
status: active|paused|done       # done = clean closure (finalize sets this)
next: <skill-name or step-id>    # what to call on resume
updated: <ISO-8601>              # bump on every write
steps:                           # the router's WORKFLOW_STEPS ledger, persisted
  - {id: <step>, status: pending|active|done|skipped|blocked|failed, note: ""}
notes: ""                        # free text, terse
```

## Protocol

1. **Resume check (router, step 0).** If the file exists with `status: active|paused`,
   show the `steps` ledger and ask: `Resume "<run_id>" at <next>? (or start fresh)`.
   On resume, treat `done` steps as satisfied — skip re-classification and re-preflight
   for them; jump to `next`. On "start fresh", overwrite the file.
2. **Write (router).** After route confirmation, write the file with the ledger,
   `status: active`, and `next` = first dispatch target. Update `next` + `updated`
   at each dispatch.
3. **Stamp (workflow skills, optional).** A workflow may set its own step
   `status`/`next` as it progresses. Not required — piggyback this onto a workflow
   skill the next time it is edited.
4. **Read (handoff).** Use this file as the primary source for "where we are" and
   "next steps". Fall back to conversation context only when the file is absent.
5. **Close (finalize).** On clean completion set `status: done` and `next: ""`.
   Leave the file in place as a record; the next confirmed route overwrites it.

## Cost note

This buys resumability and one skipped high-reasoning re-classification per resume,
not structural token savings. Never inject `state.yaml` into a cached prompt prefix
(it mutates every step and would bust prompt caching) — read it via tool on demand.

## Self-check

Run after any manual edit to confirm the file is valid and single-run:

```bash
f=docs/executions/state.yaml
[ -f "$f" ] || { echo "no active run"; exit 0; }
python3 -c "import yaml,sys; d=yaml.safe_load(open('$f')); \
assert d.get('status') in {'active','paused','done'}, 'bad status'; \
assert isinstance(d.get('steps'),list), 'steps must be a list'; \
print('state.yaml OK:', d['run_id'], '->', d.get('next') or '(done)')"
```
