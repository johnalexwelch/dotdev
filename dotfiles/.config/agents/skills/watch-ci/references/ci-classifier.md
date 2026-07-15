# CI Classifier Reference

Load this reference in Step 2 of `/watch-ci`, whenever a failed check needs classification, and again when an auto-fix attempt fails and the next run must be re-classified.

## Classification Rules

Classify each failed check into exactly one bucket. Apply rules in order; first match wins.

| Class | Detection heuristic | Auto-fix? |
|-------|---------------------|-----------|
| `format` | Output mentions `prettier`, `black`, `gofmt`, `rustfmt`, `ruff format`, `dprint`, `clang-format`. Or job name contains `format`/`fmt`. | Yes. Re-run formatter, commit. |
| `lint` | Output mentions `eslint`, `tslint`, `flake8`, `pylint`, `golangci-lint`, `clippy`, `ruff check`. Or job name contains `lint`. Failures are line-and-rule-cited. | Yes. Apply linter suggested fixes, or dispatch a scoped subagent if the rule has no autofix. |
| `type` | Output from `tsc`, `mypy`, `pyright`, `flow`. Failures are `<file>:<line>: TS<code>: <msg>` or similar. | Yes. Dispatch a scoped subagent with the failure list and failing files. |
| `test-assertion` | Test output contains a unified diff between expected and actual at a single symbol, such as `expected: 42, got: 43`, or `assertEqual(a, b)` with clear delta. Single test, single assertion. | Yes. Dispatch a scoped subagent with the failing test file and assertion delta. |
| `test-logic` | Test failure is multi-line, indirect, or asserts on side effects such as timing, race conditions, or mock interactions. | No. Surface as `[human]`. |
| `build-infra` | Output mentions missing dependencies, network errors, runner-image issues, missing env vars, or secrets unavailable. | No. CI config and secrets are not auto-fix territory. |
| `security` | Job name or workflow name contains `security`, `sast`, `codeql`, `snyk`, `trivy`, `audit`. Or output cites a CVE or advisory. | Never. Always `[human]`, even for trivial-looking warnings. |
| `unknown` | Does not match any heuristic above. | No. Surface. |

## Maintenance Rules

- First-match-wins. Order matters: `format` is checked before `lint` because formatters often run as lint plugins.
- Heuristics target output first, not workflow names alone. Job names lie, so inspect the failure log first and fall back to job name only when the log is ambiguous.
- Astronomer's `.github/actions` directory is the heuristic-pattern source. When refining or adding rules, mirror the patterns Astronomer uses, such as `auto-format-on-fail`, lockfile-regeneration triggers, or flaky-test retry policy. Port the detection inline; do not depend on the action externally. Cite the source action by name in any new rule added to this table.
- Adding a class requires two yes answers: (1) Is the failure deterministic enough to auto-fix without human judgment? (2) Is the fix bounded so the subagent scope covers the failure without spilling into adjacent code? If either is no, surface to human.
- If the Astronomer reference directory is not present locally, skip the cross-reference; classifier still works from this table. Note in tuning notes that pattern-source guidance was unavailable.

## Signature Rules

Build a deterministic signature for each failed CI run:

```text
sig = sha1(sorted(
  [f"{job.name}:{first_failure_line_hash(job.log)}" for job in failed_jobs]
))
```

`first_failure_line_hash` is the first non-progress, non-timestamped line in the failed job log. Skip progress markers, timestamps, ANSI codes, `==>`, and `[INFO]` noise.

If `sig == prior_signature`, halt for no-progress. Do not dispatch another fix attempt.

## Error Handling Matrix

| Failure | Behavior |
|---------|----------|
| `gh auth status` fails | Abort with token-scope guidance. Token mutation is `[human]`. |
| Working tree dirty | Abort. Auto-fix commits need a clean baseline. |
| `pr_number == 0` and no PR for branch and no body file findable | Abort. User must pass `body_path=` or run `/describe-pr` first. |
| `pr_number == 0`, auto-create PR fails | Abort with the `gh pr create` error message verbatim. |
| CI poll exceeds 30-minute window with runs stuck queued/in-progress | Halt. Surface CI infra issue to human. |
| Failed job classifies as `test-logic`, `build-infra`, `security`, or `unknown` | Halt regardless of attempt count. Surface to human via PR comment. |
| Same failure signature in two consecutive attempts | No-progress halt. Surface to human. |
| `M > max_attempts` | Halt. Surface to human. |
| Auto-fix subagent reports failure | Treat as that attempt's failure class. Halt if classification is out-of-scope; otherwise the next attempt re-classifies. |
| `git push` rejected because force would be required or branch protection blocks | Halt as `[human]`. Do not force-push. |
| OMC `security-reviewer` agent fails or times out | Treat as `Changes requested`; do not hand back as clean. Surface to human. |
| Reviewer-comment gate finds unanswered comments | Invoke `receive-review` if actionable; otherwise halt with the unresolved comment list. |
| `dry_run == true` | Poll and classify only. Outcome file written with `dry_run`. No commits or comments. |
| `no_review == true` | Require explicit user waiver, or complete `WORKFLOW_REVIEW_GATE` with `review_profile`, `independent_review: true`, and `verdict: APPROVE` plus explicit user waiver for skipping `/watch-ci` self-review. Record the waiver/evidence in the outcome file. Existing PR comments still must be resolved before clean handoff. |
