# workflow-ledger — Phase 0 kernel spec

Authority: D-006 (+ addendum) in `dotfiles/.config/agents/skills/_docs/decision-log.md`.
This spec is the test-author contract: every MUST below gets a red test before implementation exists.

## Deliverables

| Path | What |
|---|---|
| `dotfiles/.config/agents/skills/workflow-ledger/SKILL.md` | Library skill (`layer: kernel`, `user-invocable: false`, `disable-model-invocation: true`); absorbs `_docs/step-ledger.md` + `_docs/state-cockpit.md` + `_docs/human-gate-taxonomy.md` |
| `dotfiles/.config/agents/skills/workflow-ledger/scripts/ledger.sh` | The kernel CLI (below) |
| `dotfiles/.config/agents/skills/workflow-ledger/scripts/forge.sh` | Origin-detecting forge shim (gh vs Forgejo API) |
| `~/.claude/hooks/workflow-guard.sh` additions | 4 rules (below) |
| `test/test-ledger.sh`, `test/test-forge.sh`, `test/test-guard-rules.sh` | tmp-git-repo harness, same shape as `test/test-worktree-baseline.sh` |

Non-goals for Phase 0: HMAC signing, routing evals (Track B), any SKILL.md edits to chain skills (Phases 1–4), review-floor path-pattern tuning beyond defaults.

## State model (D-006 #19)

- **Live state**: `$(git rev-parse --git-dir)/ledger/state.yaml` — survives `reset --hard`/checkout; per-worktree automatically (worktree git-dirs are `.git/worktrees/<name>/`).
- **Committed snapshot**: `docs/executions/state.yaml`, written **only** by `stamp` (and `init`/`close`), then committed `chore(ledger): <action> <target>`. Reviewers/PRs read this; `check` reads live state.
- All writes schema-validated (python3 + yaml, as in `_docs/state-cockpit.md` self-check). A corrupt live file is exit 6, never silently rewritten.

### Schema

```yaml
run_id: <YYYY-MM-DD>-<slug>
workflow: <skill-name>
kind: feature|bug|phase|docs|skill      # bug inserts required diagnose/fix gates
budget: direct|one-reviewer|multi-lane|team
status: active|paused|done
next: <step-id or "">
updated: <ISO-8601>
steps:
  - {id: <step>, required: true|false, status: pending|active|completed|skipped|blocked|failed, evidence: ""}
tdd: {decision: ran|not_applicable, evidence: ""}   # optional until set
stamps:
  <gate>:                                # gate ∈ diagnose|fix|review|finalize
    head_sha: <sha>
    timestamp: <ISO-8601>
    gate_type: reviewer-validation|maintainer-decision|operator-runtime|secret-custody
    provenance: agent|human
    checked: {<field>: <result>, ...}    # written by script only
    attested: {<field>: <value>, ...}    # recorded verbatim from --attest
    override: {active: bool, reason: "", timestamp: ""}
overrides: []                            # audit trail of every --override
```

## CLI contract (exit codes are the API — tests assert them)

### `ledger.sh init <run_id> --workflow <w> --kind <k> --steps <csv> [--budget <b>]`

- Creates live state, all steps `pending`; `kind: bug` MUST auto-insert required `diagnose` and `fix` steps if absent from `--steps`.
- Writes + commits the snapshot. Exit 0. Existing `status: active` run → exit 7 (refuse; `--force` overwrites with an `overrides[]` audit entry).

### `ledger.sh set <step> <status> [--evidence "..."] [--reason "..."]`

Transition rules (each MUST have a red test):

- unknown step → exit 5
- required step to `skipped` → exit 3, no write
- `completed|skipped|blocked|failed` with empty evidence/reason → exit 4, no write
- valid transition → live-state write, `updated` bumped, exit 0
- schema-invalid resulting doc → exit 6, no write

### `ledger.sh stamp <gate> [--attest k=v ...] [--override --reason "..."] [--human] [--gate-type <t>]`

- Runs the gate's **checked** fields (table below). All pass → stamp written with current `head_sha`, snapshot committed, exit 0.
- Any checked field fails → exit 2, listing each failure; nothing written (except with `--override`).
- `--override` requires non-empty `--reason` (else exit 4); writes stamp with `override.active: true` + appends `overrides[]`; exit 0 with loud stderr warning.
- Gate types: `diagnose|fix|review` are `reviewer-validation` (agent-stampable). `finalize` fields flagged maintainer/operator/secret-custody require `--human` (else exit 8) — Phase 0 ships `finalize` as reviewer-validation by default; the enum + `--human` path must exist and be tested.

### `ledger.sh check <gate>`

- Exit 0 iff: stamp exists AND (all checked passed OR override active) AND fresh: every commit after `head_sha` touches ONLY the snapshot file, verified by `git diff-tree` contents — never by commit subject (R1 MF1 content-verified refinement of D-006 #4; the stamp's own snapshot commit is the only exempt shape).
- Any commit after stamp → exit 1 `STALE`; missing stamp → exit 1 `MISSING`; fresh override → exit 0 but prints `OVERRIDDEN: <reason>`. A **stale** override → exit 1 `OVERRIDE_STALE: … recorded reason: <reason>` — freshness applies to overridden stamps too; the distinct prefix tells the operator a previously-authorized bypass expired rather than never existed.

### `ledger.sh reconcile [--apply]`

- Compares live ledger vs git ground truth: branch exists, worktree alive, commits present beyond `next` (`git log <base>..HEAD` non-empty for steps claimed pending).
- Prints true frontier; `--apply` updates `next`. Exit 0 clean, exit 1 drift-detected (report printed).

### `ledger.sh preflight --skill <name>`

- Parses `Requires:` from `<skills-root>/<name>/SKILL.md` Contract; `which` each CLI tool. Exit 0 all present; exit 1 listing missing. Unknown skill → exit 5.

### `ledger.sh review-floor [--base <ref>]`

- Computes diff stats vs base: files changed, LOC. `>15 files || >500 LOC` → `full`. Path-pattern hits (default patterns: `auth|secret|migration|infra|\.github/workflows`; optional repo override file `docs/executions/review-patterns.txt`) → at least `standard`, security-flagged. Else `fast`.
- Prints one token: `fast|standard|full`, with a `+security` suffix when a path pattern hit (e.g. `standard+security`) — the flag rides the floor word so it is recorded, never silently dropped. Rank comparisons strip the suffix. Deterministic: same diff → same output (test asserts).
- `stamp review` derives required lanes from the chosen profile and adds `security` when the floor is security-flagged; the full floor token (including the flag) is recorded in the stamp's checked `review_floor`.

### `ledger.sh verify-local`

- Reads `docs/executions/ci-commands.yaml` (list of commands). Runs each, records pass/fail + head_sha into live state. All pass → exit 0; any fail → exit 1 with failing command echoed. Missing manifest → exit 9 (`NO_MANIFEST` — callers decide policy).

### `ledger.sh show` / `ledger.sh close`

- `show`: render steps + stamps table. `close`: set `status: done`, `next: ""`, commit snapshot.

## Gate checked/attested fields

| Gate | Checked (script computes) | Attested (`--attest`) |
|---|---|---|
| `diagnose` | `repro_cmd` runs NOW and exits **non-zero** (captured exit code + tail of output) | `root_cause`, `repro_cmd` string itself |
| `fix` | same stored `repro_cmd` runs NOW and exits **0**; regression test file exists (path from `--attest regression_test=<path>`) | rationale |
| `review` | worktree valid (`setup-worktree/scripts/worktree-baseline.sh verify` exit 0); chosen profile ≥ `review-floor` output; every required lane file exists and contains a `verdict:` line; per-lane `model:` line ≥ profile floor; digests (sha256, linecount, verdict, model) recorded | `verdict`, `review_profile`, `lanes`, `model_floor` |
| `finalize` | `check review` passes (fresh); `git status --porcelain` empty; `verify-local` recorded pass at HEAD; via `forge.sh`: CI green, PR state, review threads resolved (skipped with explicit `no_pr` note when no PR exists yet) | `post_mortem`, `describe_pr`, `pr_number` |

Lane files: `/tmp/<lane>-review.md`, required lanes derived from profile (`fast`: integrated; `standard`: logic,tests[,security,style]; `full`: security,logic,tests,style). Lane→file mapping passed via `--attest lanes=<csv>`.

## forge.sh contract

- `forge.sh detect` → `github|forgejo|none` from `git remote get-url origin`; `git config forge.type` (github|forgejo) wins when set, and ssh-style origins resolve their host through `ssh -G` HostName so ~/.ssh/config aliases (e.g. `git@github-personal:`) classify by destination (`FORGE_SSH_CONFIG` is the hermetic test seam).
- `forge.sh ci-status <pr>` / `pr-state <pr>` / `threads-resolved <pr>` → normalized one-word outputs (`green|red|pending`, `open|merged|closed|draft`, `yes|no`).
- GitHub via `gh` JSON; Forgejo via curl `$FORGE_URL/api/v1` with `$FORGE_TOKEN`.
- **Mock mode**: `FORGE_MOCK_DIR=<dir>` reads canned responses from files — all ledger/guard tests run offline through mock mode; zero network in tests.

## Hook rules (workflow-guard.sh additions)

1. **Merge gate** (PreToolUse Bash, exit 2): command matches merge shapes — `gh pr (merge|ready)`, `git-forge .*merge`, `tea pr merge`, `curl .*/pulls/.*/merge` — AND repo has `docs/executions/` AND `ledger.sh check finalize` ≠ 0 → block, print the check output. Override stamps pass (check exits 0) but the hook echoes the `OVERRIDDEN` line.
2. **state.yaml write block** (PreToolUse Edit|Write, exit 2): target path matches `docs/executions/state.yaml` or `.git/**/ledger/state.yaml` → block: "script-owned; use ledger.sh".
3. **stderr-suppression** (PreToolUse Bash, exit 2): mutating `git|gh|tea|git-forge` subcommand (push, commit, merge, pr create/edit/close, issue edit, api -X POST/PATCH/DELETE) combined with `2>/dev/null` or `&>/dev/null` → block.
4. **Entry enforcement — warn only in Phase 0** (PreToolUse Edit|Write, exit 0 + stderr): tracked-code file edit in a repo with `docs/executions/` and no live `status: active` run → warn "no active run — route via workflow-router or ledger.sh init". Escalation to exit 2 is a Phase 5 flip behind `LEDGER_ENTRY_ENFORCE=block`. Never fires on untracked files, non-opted-in repos, or `docs/executions/**` itself.

## Test requirements (red-first; tmp-git-repo harness per `test/test-worktree-baseline.sh`)

- Every exit code above has at least one asserting test (happy + refusal per subcommand).
- Freshness: stamp → commit → `check` exits 1 STALE. Override: stamp fails → `--override --reason` → `check` exits 0 + OVERRIDDEN.
- Durability: init → `git reset --hard` → live state intact (git-dir), snapshot regenerable.
- `kind: bug` template: `stamp fix` before `stamp diagnose` → exit 2 (diagnose gate unmet); full red→green repro flow passes.
- review: fabricated-lane detection (missing lane file → exit 2; file without `verdict:` line → exit 2; model below floor → exit 2); profile below floor → exit 2.
- forge: mock-mode tests for all three ops on both forge types; `detect` on three remote shapes.
- Hooks: run `workflow-guard.sh` with synthesized hook JSON on stdin; assert exit codes + messages for all 4 rules, including the entry-warn non-blocking behavior and the merge-gate pass-through when `check finalize` succeeds.
- Tests MUST NOT touch network, `$HOME` state, or the real skills root (use `SKILLS_ROOT` env override in `preflight`).

## Implementation constraints

- bash + python3(yaml) only — no new dependencies. `set -uo pipefail`. Shellcheck-clean (repo pre-commit).
- Two-lane build (D-006 #9): test-author commits tests red; implementer may not modify `test/**` (empty test-diff is a review checked field).
