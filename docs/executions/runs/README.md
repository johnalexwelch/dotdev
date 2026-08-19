# Per-run committed ledger snapshots

One file per workflow run: `<run_id>.yaml`, written and committed only by
`workflow-ledger/scripts/ledger.sh` (`init`/`stamp`/`close`). These files are
script-owned — a guard hook blocks direct Edit/Write; never hand-edit them.

Why per-run (2026-08-19 migration): the previous single shared snapshot,
`docs/executions/state.yaml`, was committed by every run, so any two
concurrent stamped PRs merge-conflicted on it (#167 twice, #174, #180, #181
within 24h), forcing keep-ours resolutions and full restamp ceremonies.
Per-run files make that conflict structurally impossible: each run commits
only its own file, and the kernel's freshness exemption covers exactly that
file.

`../state.yaml` remains as a frozen historical record of pre-migration runs.
It is never written or read by new runs and satisfies no gate.

Files here accumulate as delivery history (one per run). The CI finalize gate
(`scripts/finalize-stamp-check.sh`) checks only the run files a PR actually
changed; `skill-system-audit` reads them for the D-006 scoreboard.
