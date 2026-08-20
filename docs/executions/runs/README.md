# Per-run committed ledger snapshots

One file per workflow run: `<run_id>.yaml`, written and committed only by
`workflow-ledger/scripts/ledger.sh` — `init`, `set` (when it revokes a gate),
`stamp`, `unstamp`, `flush`, and `close`. These files are script-owned — a
guard hook blocks direct Edit/Write; never hand-edit them.

So a `chore(ledger): unstamp <gate>` or `chore(ledger): flush <run_id>` commit
touching one of these files is expected kernel output, not tampering:
`unstamp` publishes a gate revocation, and `flush` publishes a `steps`/metadata
correction that carries no gate semantics. Only `init`/`stamp`/`close` also
advance `last_seen_sha`.

Why per-run (2026-08-19 migration): the previous single shared snapshot,
`docs/executions/state.yaml`, was committed by every run, so any two
concurrent stamped PRs merge-conflicted on it (#167 twice, #174, #180, #181
within 24h), forcing keep-ours resolutions and full restamp ceremonies.
Per-run files make that conflict structurally impossible: each run commits
only its own file, and the kernel's freshness exemption covers exactly that
file.

`../state.yaml` remains as a frozen historical record of pre-migration runs.
It is never written or read by new runs and satisfies no gate.

**Mid-flight runs at the migration boundary**: a run inited by the
pre-migration kernel carries snapshot commits to the legacy path, which are
no longer freshness-exempt — every pre-upgrade stamp reads STALE (rendered as
"non-ledger commits exist after its stamp"). The run is not bricked: re-stamp
each gate and re-run `verify-local` under the current kernel; the first stamp
creates this run's file here. The legacy commit satisfies nothing.

**Reading historical run files**: `status: active` in a run file that is not
the branch's current run means the run was abandoned or superseded — a
successor run under a different run_id writes its own file and never rewrites
the old one (the one exception is `init --force` reusing the *same* run_id,
which overwrites that file with an `overrides[]` audit entry); the live
git-dir ledger is authoritative for what is actually active.

Files here accumulate as delivery history (one per run). Run filenames are
kernel-validated (`A-Za-z0-9._-`, flat — never nested); a nested yaml under
this directory is by definition hand-written and both the write-block guard
and the CI gate refuse it. The CI finalize gate
(`scripts/finalize-stamp-check.sh`) checks only the run files a PR actually
changed; `skill-system-audit` reads them for the D-006 scoreboard.
