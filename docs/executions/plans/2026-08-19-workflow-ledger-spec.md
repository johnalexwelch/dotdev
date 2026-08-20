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
- **Committed snapshot (per-run, 2026-08-19 addendum)**: `docs/executions/runs/<run_id>.yaml`, written **only** by `init`, `set` (when it revokes a gate), `stamp`, `unstamp`, `flush`, and `close`, then committed `chore(ledger): <action> <target>`. Only the gate actions (`init`/`stamp`/`close`) also advance `last_seen_sha`; `set`-revocation, `unstamp`, and `flush` publish without adopting HEAD, so a no-gate publish cannot launder drift out of `reconcile`. Reviewers/PRs read this; `check` reads live state. One file per run: two concurrent runs never commit a shared path, so the cross-PR merge-conflict class on the old single snapshot (#167 twice, #174, #180, #181 within 24h — each forcing a keep-ours resolution plus a full restamp ceremony) is structurally impossible. The `run_id` doubles as the tracked filename and a git pathspec, so `init` allowlists it (`A-Za-z0-9._-`, non-empty, no leading dot, no `..` → exit 6 otherwise).
- **Legacy record**: `docs/executions/state.yaml` (the pre-addendum shared snapshot) is frozen history — never written, read, or trusted by new runs, and it satisfies no gate. A tracked pointer replacement was weighed and rejected: any tracked file rewritten by every `init` re-creates the exact cross-PR conflict this addendum removes; locally the live state already carries `run_id`, and in CI the PR diff names the run file.
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
route: <classification>|<selected-flow>|confirmed   # optional (Phase 5b): route evidence from workflow-router's confirmed ROUTE_CARD; malformed → exit 6
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

Exit 10 (added by the R1/R2 batch, item #2) is environment breakage — no python3 with PyYAML, a misconfigured `LEDGER_PYTHON`, not inside a git repo, git HEAD/snapshot-commit failures — distinct from gate-unmet exit 1 so the merge-gate hook warn-permits it (with 6 and 9) instead of blocking as if the gate were unmet.

### `ledger.sh init <run_id> --workflow <w> --kind <k> --steps <csv> [--budget <b>] [--route "<classification>|<selected-flow>|confirmed"]`

- Creates live state, all steps `pending`; `kind: bug` MUST auto-insert required `diagnose` and `fix` steps if absent from `--steps`.
- Writes + commits the snapshot. Exit 0. Existing `status: active` run → exit 7 (refuse; `--force` overwrites with an `overrides[]` audit entry).
- **Route evidence (Phase 5b).** `--route` records the top-level `route:` field. Absent → init succeeds but MUST print `WARNING: no route evidence — invoke workflow-router`; `LEDGER_REQUIRE_ROUTE=block` escalates absence to exit 11, no write (same warn-then-flip pattern as `LEDGER_ENTRY_ENFORCE`). Malformed route (not three pipe-separated segments ending in literal `confirmed`) → exit 6, no write — enforced at init and by schema validation on every load.

### `ledger.sh set <step> <status> [--evidence "..."] [--reason "..."]`

Transition rules (each MUST have a red test):

- unknown step → exit 5
- required step to `skipped` → exit 3, no write
- `completed|skipped|blocked|failed` with empty evidence/reason → exit 4, no write
- valid transition → live-state write, `updated` bumped, exit 0
- schema-invalid resulting doc → exit 6, no write
- **gate revocation side effect (review round 1):** `set diagnose|fix|review|finalize <anything-but-completed>` on a step whose gate is stamped ALSO revokes that stamp — `stamps[<gate>]` deleted, an `overrides[]` entry appended with `action: unstamp-via-set`, and the snapshot committed `chore(ledger): unstamp <gate>`. A gate stamp may only stand while its same-named step is `completed`. Atomic in the safe direction: if the publish fails, the whole durable tuple is restored and the stamp stands (exit 10) — see `unstamp` below.

### `ledger.sh stamp <gate> [--attest k=v ...] [--override --reason "..."] [--human] [--gate-type <t>]`

- Runs the gate's **checked** fields (table below). All pass → stamp written with current `head_sha`, snapshot committed, exit 0.
- Any checked field fails → exit 2, listing each failure; nothing written (except with `--override`).
- `--override` requires non-empty `--reason` (else exit 4); writes stamp with `override.active: true` + appends `overrides[]`; exit 0 with loud stderr warning.
- Gate types: `diagnose|fix|review` are `reviewer-validation` (agent-stampable). `finalize` fields flagged maintainer/operator/secret-custody require `--human` (else exit 8) — Phase 0 ships `finalize` as reviewer-validation by default; the enum + `--human` path must exist and be tested.

### `ledger.sh check <gate>`

- Exit 0 iff: stamp exists AND (all checked passed OR override active) AND fresh: every commit after `head_sha` touches ONLY the run's **own** snapshot file (`docs/executions/runs/<run_id>.yaml`), verified by `git diff-tree` contents — never by commit subject (R1 MF1 content-verified refinement of D-006 #4; the stamp's own snapshot commit is the only exempt shape). A commit touching a *different* run's file, or the legacy shared `state.yaml`, is NOT exempt and reads STALE.
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
| `finalize` | `check review` passes (fresh); `git status --porcelain` empty; `verify-local` recorded pass at HEAD; committed snapshot's durable content matches live state (`snapshot_current` — closes the snapshot-only-commit rewrite hole); via `forge.sh`: CI green, PR state, review threads resolved (skipped with explicit `no_pr` note when no PR exists yet) | `post_mortem`, `describe_pr`, `pr_number` |

Lane files: `/tmp/<lane>-review.md`, required lanes derived from profile (`fast`: integrated; `standard`: logic,tests[,security,style]; `full`: security,logic,tests,style). Lane→file mapping passed via `--attest lanes=<csv>`.

## forge.sh contract

- `forge.sh detect` → `github|forgejo|none` from `git remote get-url origin`; `git config forge.type` (github|forgejo) wins when set, and ssh-style origins resolve their host through `ssh -G` HostName so ~/.ssh/config aliases (e.g. `git@github-personal:`) classify by destination (`FORGE_SSH_CONFIG` is the hermetic test seam).
- `forge.sh ci-status <pr>` / `pr-state <pr>` / `threads-resolved <pr>` → normalized one-word outputs (`green|red|pending`, `open|merged|closed|draft`, `yes|no`).
- GitHub via `gh` JSON; Forgejo via curl `$FORGE_URL/api/v1` with `$FORGE_TOKEN`.
- **Mock mode**: `FORGE_MOCK_DIR=<dir>` reads canned responses from files — all ledger/guard tests run offline through mock mode; zero network in tests.

## Hook rules (workflow-guard.sh additions)

1. **Merge gate** (PreToolUse Bash, exit 2): command matches merge shapes — `gh pr (merge|ready)`, `git-forge .*merge`, `tea pr merge`, `curl .*/pulls/.*/merge` — AND repo has `docs/executions/` AND `ledger.sh check finalize` ≠ 0 → block, print the check output. Override stamps pass (check exits 0) but the hook echoes the `OVERRIDDEN` line.
2. **Ledger state write block** (PreToolUse Edit|Write, exit 2): target path matches any of the three ledger state families — any `.yaml`/`.yml` under `docs/executions/runs/` at any depth and any basename shape, dotfiles included (the kernel only authors flat, allowlist-named files, so anything else there is by definition hand-written), the legacy `docs/executions/state.yaml` (frozen historical record), or the git-dir live state `.git/**/ledger/state.yaml` — → block: "script-owned; use ledger.sh". The block set must never be narrower than the path set the CI finalize gate can be asked to read (2026-08-19 per-run addendum, review round).
3. **stderr-suppression** (PreToolUse Bash, exit 2): a mutating `git|gh|tea|git-forge` subcommand (push, commit, merge, pr create/edit/close, issue edit, api -X POST/PATCH/DELETE) with stderr suppression **attached to the same command segment** → block. Recognized spellings: `2>/dev/null`, `2>>/dev/null`, `&>/dev/null` (spaces and quoted paths tolerated), `2>&-`, and `>/dev/null … 2>&1`; a bare `2>&1` is not suppression (the caller still sees the stream). Compound commands are split on `&&`, `||`, `;`, `|` (quoted separators masked, line continuations unfolded) and each segment is judged on its own — a suppressed test/lint segment chained before a push passes (batch #1). Compound-redirection shapes (`{ …; } 2>/dev/null`, subshells, loops, conditionals) fall back to whole-command semantics, fail closed. The fallback **arms** when a construct's own trailing redirect list is suppression — any redirect spelling counts (`2>`, `&>`, or a bare `>` feeding the `>/dev/null … 2>&1` idiom), but a construct redirecting to a real file never arms it, even when unrelated suppression appears elsewhere in the command. `}`/`)` count as terminators anywhere (command substitutions and paren-free arithmetic are masked out first); `done`/`fi` only when separator-preceded, so the same words as bare arguments do not trip the fallback. Once armed the fallback *is* whole-command, so a mutation outside the redirected construct blocks too: deliberate, since a group redirect cannot be attributed to one segment lexically. A bare `exec` token alongside suppression is a second carrier (shell-level redirection); suppression must be present for it to arm.

**Visibility boundary — an accepted fail-open regression, declared deliberately.** Rule 3 is a lexical tripwire, not a sandbox. Stated as a principle rather than a list of mechanisms, because an open set written as a closed list is the documentation-layer version of the carrier model's mistake:

> Rule 3 sees a mutation only when its **text appears in the same segment as the suppression** — quoted or not, as a command or as an argument. Anything that keeps the text out of that segment is **out of scope and fails open**: name binding, expansion from a variable, a here-document, a file read at runtime.

The mechanism is not what decides it: `eval "$CMD" 2>/dev/null` fails open while `eval "git push …" 2>/dev/null` blocks — same mechanism, opposite outcome, separated only by text presence. The rule also surfaces the over-block direction: a mere *mention* of a mutating command in a suppressed segment blocks, so `echo "git push origin main" 2>/dev/null` is refused.

`origin/main` blocked several of these under whole-command semantics, so this is a **regression**, not a never-covered gap; it is named as one because this branch's rule is that a fail-open regression gets fixed. The exception is taken because the class is unreachable lexically, not because it is cheap.

Unreachable because the suppressed segment is **not distinguishable by segmentation**: `./deploy.sh 2>/dev/null` (must block) and `bash test.sh 2>/dev/null && git push origin main` (must permit, batch #1) are both a suppressed, non-mutating-looking segment. Whether the suppressed command is bound to a mutation lives outside the command text — in a file, or a previously-defined alias — so no predicate over this text can see it. Narrower shapes *are* separable: a function defined and invoked in the same command can be caught by a scoped carrier (verified by the style lane), but that is one more carrier with the usual batch-#1 cost and it leaves the general class open. Closing this properly needs a tokenizer that tracks redirection scope. The load-bearing controls are the stamps and freshness rules, which do not depend on rule 3.
4. **Entry enforcement — warn only in Phase 0** (PreToolUse Edit|Write, exit 0 + stderr): tracked-code file edit in a repo with `docs/executions/` and no live `status: active` run → warn "no active run — route via workflow-router or ledger.sh init". Escalation to exit 2 is a Phase 5 flip behind `LEDGER_ENTRY_ENFORCE=block`. Never fires on untracked files, non-opted-in repos, or `docs/executions/**` itself.

### `ledger.sh unstamp <gate> --reason "..."` (review round 1 addendum)

Explicit gate revocation. The `set`-coupled path above is the implicit one; both share `op_unstamp` and both commit `chore(ledger): unstamp <gate>`.

- unknown gate → exit 5. Empty/missing `--reason` → exit 4. No live state → exit 1. No stamp for that gate → exit 1, message names the gate (`no '<gate>' stamp to revoke`).
- Success → `stamps[<gate>]` deleted, an `overrides[]` entry appended, snapshot published, exit 0.
- The `overrides[]` entry is `{gate, action, reason, timestamp, head_sha, revoked_head_sha, gate_type, revoked_checked}`. `head_sha` is the revocation-time HEAD; `revoked_head_sha`, `gate_type`, and `revoked_checked` preserve the revoked stamp's own identity and `checked` digests (including the `lane_*_sha256` bindings between a review stamp and its lane files), so a revoke → re-stamp cycle is diffable. Revocation supersedes a stamp; it never erases it.
- **Atomicity (MUST have a red test).** The publish is all-or-nothing over the durable tuple. On any publish failure: live state, the working-tree snapshot file, and the index are restored verbatim, so live state, `check-snapshot`, and the committed blob all still agree the stamp stands; exit 10, and the message states the revocation did not apply and must be re-run. The rollback is a whole-file restore, not per-key: `overrides` is itself in the durable tuple, so a `stamps`-only rollback would leave live and committed divergent and `flush` would then refuse the operator's recovery path.
- Revocation is not terminal — the gate is re-earnable by stamping again — and it confers nothing: every consumer of an absent stamp fails closed, so `unstamp` can only remove authority.
- Advisory: `unstamp` does not touch the same-named step, so it warns on stderr (exit still 0) when that step is still `completed`, naming `ledger.sh set <gate> pending`.

### `ledger.sh flush` (review round 1 addendum)

Publishes `steps` and metadata to the committed snapshot with **no gate semantics**, so a corrected `set --evidence` string can ship without passing a gate (hand-editing the script-owned snapshot is hook-blocked).

- No arguments (any argument → exit 1 usage). No live state → exit 1. Nothing to publish → exit 0, no commit.
- Commits `chore(ledger): flush <run_id>` touching only that run's file, and does **not** advance `last_seen_sha` — so it cannot launder drift out of `reconcile`, and it cannot create, refresh, or stale a stamp.
- **Refuses a closed run** (`status: done`) → exit 1: a settled audit record is not reopened by a no-gate publish.
- **Refuses a divergent durable tuple** → exit 6, naming the divergent key, publishing nothing. `flush` compares live `DURABLE_KEYS` against the **committed blob** (`HEAD:<snapshot>`), not the working-tree file, because `flush` requires no clean tree and a hand-written worktree file must not be able to agree its way past the check.
- Refuse, do not repair: preserving the record's stamps while writing only `steps`/meta would make `snapshot_match` pass while live and committed genuinely disagree, masking exactly what the tamper detector exists to see. The only ways the divergence arises are a hand-edited live state or a kernel bug, and publishing either makes it canonical — `cmd_flush`'s old write-all-of-live-state behavior flipped `check-snapshot` from MISSING to OK on an injected stamp and silenced `snapshot_current` in `stamp finalize` altogether.

### `ledger.sh check-snapshot <gate> [--file <path>]` (per-run addendum)

- CI-mode verdict against a committed per-run snapshot. Resolution order: explicit `--file` (the CI script passes candidates from the PR diff) → the live run's file when live state exists → exactly one `docs/executions/runs/*.yaml` (zero → exit 1 `MISSING`; several → exit 1 `AMBIGUOUS`, asking for `--file`).
- `--file` is shape-validated like a kernel-authored run file: in-repo (absolute paths canonicalized physically — macOS `/var` vs `/private/var`), flat under `runs/`, `.ya?ml` extension; anything else → exit 1 `INVALID`. An existing-but-untracked run file is also `INVALID` — "committed snapshot" is the contract.
- `run_id` is allowlisted (`A-Za-z0-9._-`, no leading dot, no `..`, non-empty) because it doubles as a tracked filename and a git pathspec; violations → exit 6. `init` refuses reusing a `run_id` whose committed run file already exists (exit 7; `--force` overwrites with an `overrides[]` audit entry).
- `scripts/finalize-stamp-check.sh` discovers candidates as the FLAT `docs/executions/runs/*.yaml` files changed vs the PR base (existing at HEAD; nested paths are never candidates) and passes iff at least one carries a fresh finalize stamp — a superseded force-re-init sibling may legitimately be stale. Zero candidates on a non-exempt diff is a FAIL, with deleted-at-HEAD run files counted in the diagnosis. When the base diff is uncomputable, the fallback enumerates the flat run files present at HEAD through the same loop (fail-closed, resolvable). Kernel exit 10 keeps its warn-permit posture through the candidate loop; schema-invalid candidates (exit 6) are annotated loudly even when a sibling passes.

## Test requirements (red-first; tmp-git-repo harness per `test/test-worktree-baseline.sh`)

- Every exit code above has at least one asserting test (happy + refusal per subcommand).
- Freshness: stamp → commit → `check` exits 1 STALE. Override: stamp fails → `--override --reason` → `check` exits 0 + OVERRIDDEN.
- Durability: init → `git reset --hard` → live state intact (git-dir), snapshot regenerable.
- `kind: bug` template: `stamp fix` before `stamp diagnose` → exit 2 (diagnose gate unmet); full red→green repro flow passes.
- review: fabricated-lane detection (missing lane file → exit 2; file without `verdict:` line → exit 2; model below floor → exit 2); profile below floor → exit 2.
- forge: mock-mode tests for all three ops on both forge types; `detect` on three remote shapes.
- Hooks: run `workflow-guard.sh` with synthesized hook JSON on stdin; assert exit codes + messages for all 4 rules, including the entry-warn non-blocking behavior and the merge-gate pass-through when `check finalize` succeeds.
- Tests MUST NOT touch network, `$HOME` state, or the real skills root (use `SKILLS_ROOT` env override in `preflight`).
- Per-run snapshots (2026-08-19 addendum): init writes only `runs/<run_id>.yaml` (commit touches exactly that path; legacy `state.yaml` untouched, byte-identical when pre-existing); a commit touching a different run's file is STALE; two concurrent runs in two worktrees merge into the same base with no conflict; `check-snapshot --file` / single-file / multi-file resolution each asserted; `finalize-stamp-check.sh` candidate discovery (fresh candidate passes, stale sibling tolerated, zero candidates fails, legacy-shape `state.yaml` satisfies nothing); guard rule 2 blocks `docs/executions/runs/*.y(a)ml`; `worktree-baseline.sh cut` absolutizes a relative `--path`.

## R1/R2 should-fix batch (PR #160 review follow-ups)

Key for the `batch #N` anchors in code comments (kernel scripts, hook, tests). Each item landed red-first on `fix/kernel-shouldfix-batch`.

- **batch #1 — rule-3 segment scoping**: stderr suppression blocks only when attached to the mutating command segment (see Hook rules, rule 3); `gh pr merge-queue status` and other `-`-suffixed tokens are whole-token matched.
- **batch #2 — distinct env-error exit**: environment breakage is exit 10 (see the CLI-contract note above); an explicitly-set unusable `LEDGER_PYTHON` is a config error, never a silent fallback.
- **batch #3 — lane freshness binding**: `init` records `initialized_epoch`; `stamp review` refuses a required lane file whose mtime predates it (non-numeric mtimes fail closed; pre-field runs skip the check).
- **batch #4 — repro_tail redaction + snapshot cap**: checked stamp values pass through secret-shape redaction; the committed snapshot carries at most 64 chars of `repro_tail` plus a truncation marker (full redacted tail lives only in git-dir live state). Attested values stay verbatim — the fix gate re-executes `repro_cmd`.
- **batch #5 — FORGE_TOKEN hygiene**: forge.sh refuses empty-token Forgejo calls and passes the token via a curl config on stdin (`-K -`), never argv.
- **batch #6 — reconcile ground truth**: `init` records branch/worktree; `reconcile` drifts on branch change/deletion, worktree move, and commits while the next step is still pending; `--apply` adopts.
- **batch #7 — security-flagged floors**: `review-floor` appends `+security` on path-pattern hits; `stamp review` requires a security lane when flagged and records the full floor token (see review-floor section).
- **batch #8 — mock sanitization + snapshot_current**: forge mock filenames flatten `/` to `_`; finalize's stamp and `check finalize` both compare the committed snapshot's durable content (run identity, stamps, overrides) against live state — a snapshot-only commit is freshness-exempt, so this closes the out-of-band rewrite hole.

## Implementation constraints

- bash + python3(yaml) only — no new dependencies. `set -uo pipefail`. Shellcheck-clean (repo pre-commit).
- Two-lane build (D-006 #9): test-author commits tests red; implementer may not modify `test/**` (empty test-diff is a review checked field).
