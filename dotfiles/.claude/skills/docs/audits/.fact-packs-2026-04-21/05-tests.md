# Fact Pack 05: Tests

**Audit date:** 2026-04-21  
**Scope:** `/Users/alexwelch/.claude/skills/` (6 core-loop skills)  
**Question:** Do tests exist? Are claims in skill docs matched by execution evidence?

---

## Summary

**No formal test suite or test runner exists.** The skills directory contains no:
- Test files (`*_test.py`, `test_*.js`, `*_spec.*`)
- Test configuration (`pytest.ini`, `jest.config.js`, `Makefile`, `.github/workflows/test.yml`)
- Test runner commands (no `npm test`, `pytest`, `go test` analogues)

**However:** Five execution-proof artifacts exist in `docs/executions/.phase-runs/` that serve as **meta-tests** — they document that two of the six core-loop skills were actually invoked and produced observable results:
- Phase 0 (preflight): YAML parser verification on 6 SKILL.md files
- Phase 1 (pilot): `/execute-phase` invoked on a contrived plan; 2 `[auto]` tasks ran; output files verified to exist
- Phases 2–4: SKILL.md files expanded and edited; strict-YAML re-verified after each phase; cross-references checked via grep

**The 6 core-loop skills make mutually-consistent claims about test-status reporting** but are not themselves tested. They claim to *consume* test results from target repos (via `/repo-audit` "Run the test command," `/design-plan` baseline tests, `/post-mortem` test-status recording), but the skills have no self-tests.

**Gap:** Phase 5 dogfood (integration on a real repo) was blocked at preflight — target repo never selected. End-to-end execution on a real repo with real test output remains unverified.

---

## Findings

### Formal test infrastructure: Zero

| Artifact | Count | Status |
|----------|-------|--------|
| Test files (`*_test.*`, `test_*.py`, etc.) | 0 | Not found |
| Test runners/config (`Makefile`, `pytest.ini`, `package.json` scripts) | 0 | Not found |
| CI/CD test workflows (`.github/workflows/test.yml`, etc.) | 0 | Not found |
| Shell test harnesses (`.sh` scripts in project) | 0 | Not found |

**Command run:**
```bash
find /Users/alexwelch/.claude/skills -type f \( -name "*test*" -o -name "*spec*" -o -name "Makefile" -o -name "*.sh" \) 2>/dev/null | grep -v ".git"
```
**Result:** No matches.

---

### Core-loop skills: Test claims vs. reality

#### 1. `/repo-audit` (313 lines)

**Claim:** Fact-pack 05 ("tests") is one of 13 parallel audit work streams.

From SKILL.md frontmatter:
```
description: Map-reduce state-of-the-repo audit. Fans out 13 parallel Explore 
subagents to gather evidence across code, tests, docs, integrations, ops, 
CI/workflows, security, UX, and onboarding...
```

From body (Step 3, fact-pack 05):
```
| 05 | tests | Do tests actually run against current code? Run the test 
command and report the real count, coverage, and any claims in docs that 
don't match reality. |
```

**Reality:** `/repo-audit` itself is not tested. When invoked on a target repo (Phase 5 dogfood), it will *call* the test command and report results, but the skill has no self-test proving its test-reporting logic works.

**Verification status:** One-way claim (untested).

---

#### 2. `/design-plan` (452 lines)

**Claim:** A plan's verification section includes test status.

From body (Step 2, audit integration):
```
- Current test status: run the test command; note pass/fail.
```

From template example (§5.2, Phase 2 — Pilot):
```
**Verification:** Tests pass on current main; no uncommitted files.
```

**Reality:** `/design-plan` is not tested. When invoked, it reads audit results and recommends phases; the skill has no self-test proving it correctly interprets test-status claims from the audit.

**Verification status:** Template-only (untested).

---

#### 3. `/execute-phase` (527 lines)

**Claim:** Verification subagent evaluates test claims.

From body (Step 7, Verification subagent):
```
On UNVERIFIED load-bearing: halt for user call. Load-bearing includes: 
core-system tests must pass, security-related tests must pass, regression 
tests must pass, integrations with external systems must pass.
```

From Error Handling table:
```
| Test command fails | The tests fact-pack records the failure as a finding. 
Do not block the phase. |
```

**Reality:** `/execute-phase` has a verification subagent mechanism (described in its SKILL.md) but has only been tested on a contrived `/tmp/pilot-plan.md` with trivial tasks (`mkdir`, `printf`). The real test-verification logic has never run against a repo with actual test output.

**Verification status:** Designed but not exercised (Phases 1–2 pilot/production; Phase 5 blocked at preflight).

---

#### 4. `/describe-pr` (290 lines)

**Claim:** PR description includes phase status and test status from phase-run outcome files.

From body (Step 1.2):
```
Read `.phase-runs/` first. If docs/executions/.phase-runs/ exists, glob 
*-phase-*.md and read the outcome files whose **Plan:** header matches 
plan_path. These are richer signal than raw git log — they include 
commit-to-task mapping, pending-human items, scope-violation records, 
and NEW-NN candidates surfaced during execution.
```

From template (Step 3):
```
## Phases completed
- Phase 1: [status] | [commit] | [verification: pass/fail]
- Phase 2: [status] | [commit] | [verification: pass/fail]
```

**Reality:** `/describe-pr` reads phase-run outcome files but has never been invoked on a real PR. The test-status synthesis in the PR body is a design claim, not proven by execution.

**Verification status:** Template-only (untested).

---

#### 5. `/post-mortem` (288 lines)

**Claim:** Post-mortem reads test status from outcome files and raw `git log`.

From body (Step 1, added in Phase 4):
```
Read .phase-runs/ first. If docs/executions/.phase-runs/ exists, glob 
*-phase-*.md and read the outcome files...
```

From body (Step 4):
```
**Test status now.** Run the test command. Note pass/fail, and (if 
available) coverage percentage.
```

From body (Error Handling):
```
| Test command fails | Note in §Summary; do not block post-mortem. |
```

**Reality:** `/post-mortem` has never been invoked on a real repo. The test-status recording logic is untested.

**Verification status:** Designed but not exercised (Phase 5 blocked at preflight).

---

#### 6. `/setup-worktree` (234 lines)

**Claim:** Worktree setup can include a setup command (e.g., running tests after env copy).

From body (Step 3, Setup command):
```
If setup_command is provided, run it (e.g., npm install, bun run setup). 
The command inherits the worktree's environment and runs from the repo root.
```

From example (Step 5):
```
User: /setup-worktree branch=fix/flaky-test path=~/wt/myrepo/flaky 
setup_command="bun install"
```

**Reality:** `/setup-worktree` is untested. The setup-command mechanism exists in the skill design but has not been invoked on a real repo.

**Verification status:** Designed but not exercised (Phase 5 blocked at preflight).

---

### Phase-run outcome files: Execution proof

Six outcome files exist in `docs/executions/.phase-runs/`:

| File | Phases | Evidence | Test-relevant |
|------|--------|----------|---|
| `2026-04-21-phase-0.md` | 0 (preflight) | YAML parser check (structural + strict) on 6 SKILL.md files. Confirmed repo-audit, design-plan, post-mortem parse correctly. | No — this is a preflight check, not test execution. |
| `2026-04-21-pilot-phase-1.md` | 1 (pilot) | Two `[auto]` tasks executed; subagent wrote `/tmp/pilot-scratch/hello.txt` (7 bytes, content "canary"); verified by `wc -c`. | No — these are contrived tasks, not tests. |
| `2026-04-21-phase-1.md` | 1 (production port) | `/execute-phase` dispatched to general-purpose subagent; subagent reported both tasks `done`; outcome file written to `.phase-runs/`. No test output. | No — Phase 1 piloted the skill, not target-repo tests. |
| `2026-04-21-phase-2.md` | 2 (execute-phase production) | `execute-phase/SKILL.md` expanded (152 → 527 lines); strict-YAML verified; harness skill catalog confirmed load. | No — this is skill development verification, not test execution. |
| `2026-04-21-phase-3.md` | 3 (describe-pr + setup-worktree) | Two SKILL.md files created; strict-YAML verified; cross-references checked via grep. | No — skill development verification only. |
| `2026-04-21-phase-4.md` | 4 (tune design-plan) | 8 Edit calls across 3 files; strict-YAML re-verified for all 6 skills; grep confirmed cross-references. | No — tuning + documentation update only. |
| `2026-04-21-phase-5.md` | 5 (integration dogfood preflight) | Pre-phase tarball created; all 6 SKILL.md files confirmed loadable. **Halted at Task 1: target-repo selection.** | None — Phase 5 never executed. |

**Conclusion:** The phase-run artifacts document skill *development and validation* (YAML parsing, file I/O, tool dispatch), not test execution against the skills themselves or target-repo test consumption.

---

### Test-related grep findings

Scanning the 6 core-loop skills for test-related terminology:

```bash
grep -i "test" /Users/alexwelch/.claude/skills/{repo-audit,design-plan,
execute-phase,describe-pr,post-mortem,setup-worktree}/SKILL.md
```

**Results:**

- **repo-audit/SKILL.md:** "tests" mentioned in fact-pack 05 description (evidence audit stream).
- **design-plan/SKILL.md:** "test status," "baseline tests," "run baseline tests," "tests must stay green," "tests pass on current main" (audit input + planning constraint + verification claim).
- **execute-phase/SKILL.md:** "Test command fails" (Error Handling row); "core-system tests," "security-related tests," "regression tests," "integrations with external systems" (Verification subagent load-bearing claims).
- **describe-pr/SKILL.md:** "internal (tests, refactors, docs)" (commit classification example).
- **post-mortem/SKILL.md:** "Test status now" (Step 4 directive); "Test command fails" (Error Handling); "Tests added in one phase that reveal problems in another" (example finding).
- **setup-worktree/SKILL.md:** ".env.test" (env-file copy list); "fix/flaky-test" (example branch name).

**Interpretation:** All mentions are about *consuming* test output from a target repo, not *testing the skills themselves*. The skills are designed to observe, report on, and verify test status — but no mechanism tests the skills' own ability to do so.

---

## Evidence

### File counts and paths

**Core-loop skills directory structure:**
```
/Users/alexwelch/.claude/skills/
├── repo-audit/SKILL.md         (313 lines)
├── design-plan/SKILL.md        (452 lines)
├── execute-phase/SKILL.md      (527 lines)
├── describe-pr/SKILL.md        (290 lines)
├── post-mortem/SKILL.md        (288 lines)
├── setup-worktree/SKILL.md     (234 lines)
└── [4 other skills: ci-deploy-fix, omc-reference, slack-update, td-task-management, write-to-obsidian]
```

**Test artifacts search:**
```bash
find /Users/alexwelch/.claude/skills -type f \( -name "*test*" -o -name "*spec*" -o -name "Makefile" -o -name "*.sh" \) 2>/dev/null
```
**Result:** No matches (excluding `.git/`).

**Phase-run execution artifacts:**
```
/Users/alexwelch/.claude/skills/docs/executions/.phase-runs/
├── 2026-04-21-phase-0.md          (125 lines, preflight + YAML check)
├── 2026-04-21-pilot-phase-1.md    (76 lines, pilot task execution)
├── 2026-04-21-phase-1.md          (76 lines, production port)
├── 2026-04-21-phase-2.md          (129 lines, expand execute-phase)
├── 2026-04-21-phase-3.md          (120 lines, port describe-pr + setup-worktree)
├── 2026-04-21-phase-4.md          (118 lines, tune design-plan)
└── 2026-04-21-phase-5.md          (90 lines, integration dogfood preflight — HALTED)
```

**Tarball snapshots (indicating phased development):**
```
/Users/alexwelch/.claude/skills.pre-2026-04-21.tgz
/Users/alexwelch/.claude/skills.pre-phase-1.tgz
/Users/alexwelch/.claude/skills.pre-phase-2.tgz
/Users/alexwelch/.claude/skills.pre-phase-3.tgz
/Users/alexwelch/.claude/skills.pre-phase-4.tgz
/Users/alexwelch/.claude/skills.pre-phase-5.tgz
```

### Verification claims from phase-run files

**Phase 0 (preflight):**
```
✓ Three existing SKILL.md files have structurally-valid frontmatter (open/close --- markers, readable name field).
✓ Three Desktop source files read, parse strictly, and cataloged.
Verification result: PASS (structural). Strict-YAML verification deferred to Phase 4 per NEW-03.

[Strict-YAML verification run (evidence)]
OK  name=repo-audit         structural=ok  strict-ok
OK  name=design-plan        structural=ok  strict-fail(ParserError)  [FIXED in Phase 4]
OK  name=post-mortem        structural=ok  strict-fail(ParserError)  [FIXED in Phase 4]
```

**Phase 1 (pilot):**
```
- [x] /tmp/pilot-plan.md exists with a well-formed §5.1 block.
- [x] Running the skill produced an outcome file with the three-section shape specified.
- [x] The [auto] tasks produced their claimed side-effects — /tmp/pilot-scratch/hello.txt exists.
- [x] The [human] task was not executed.
- [ ] dry_run=true invocation produces the same outcome file shape without side-effects. [DEFERRED to Phase 2 Task 3 re-verification]

Verification result: PASS with one deferred check (dry_run path unexercised).
```

**Phase 2 (execute-phase production):**
```
- [x] execute-phase/SKILL.md expanded from 152 lines to 527 lines.
- [x] Strict-YAML parses.
- [x] All 6 inputs defined.
- [x] All 11 procedure steps present.
- [ ] Deferred from Phase 1: dry_run=true path exercise. Phase 2 did not re-test the pilot dry_run.

Verification result: PASS pending human review and the one deferred dry_run exercise.
```

**Phase 4 (tune design-plan, cross-skill docs):**
```
[Strict-YAML parse (all 6 skills)]
repo-audit         lines=314  strict-YAML OK
design-plan        lines=453  strict-YAML OK    [was 420 before Phase 4 edits + NEW-03 fix]
post-mortem        lines=289  strict-YAML OK    [was 273 before Phase 4 edits + NEW-03 fix]
execute-phase      lines=527  strict-YAML OK
describe-pr        lines=290  strict-YAML OK
setup-worktree     lines=234  strict-YAML OK

Verification result: PASS.
```

---

## Open questions

### 1. **Why is Phase 5 dogfood blocked?**

Phase 5 (Integration dogfood) reached preflight but halted at Task 1: "Pick a small, real target repo with low-stakes pending changes."

From `2026-04-21-phase-5.md`:
```
The dogfood needs a real repo — /execute-phase creates branches and commits, 
so the target must be a working git repo where:
- You're comfortable letting the chain create refactor/phase-<N>-<slug> branches.
- Tests are reasonable to run (the audit's test-status check is part of the flow).
- There's real work worth planning (not a stale fixture).
- Stakes are low enough that a verification fail or scope violation is educational, not production-breaking.

[Task 1 is [human]: pick the repo]

Chain halts here. Cannot advance without a concrete target repo.
```

**Implication:** The 6 core-loop skills have never been exercised on a real repo with real test output. The test-status reporting logic (in `/repo-audit` fact-pack 05, `/post-mortem` Step 4, `/execute-phase` verification) is designed but not proven to work.

### 2. **What counts as "tests exist"?**

The audit asks: "Do tests exist?"

**For the skills themselves:** No — there are no unit tests, integration tests, or meta-tests that verify the skills function correctly.

**For the claims the skills make:** The phase-run outcome files (Phases 0–4) are the closest thing to tests — they verify YAML parsing, file I/O, and basic skill dispatch. But these are not true unit tests; they're execution logs that happen to document success/failure.

**For the target repos the skills audit/plan/execute on:** The skills are *designed* to run test commands and record results, but Phase 5 dogfood never reached a real repo, so no evidence of that execution exists.

### 3. **What is the delta between "skills claim to work" and "skills have been exercised end-to-end on a real repo"?**

**Claims (from SKILL.md and docs):**
- 6 skills form a closed loop: audit → plan → execute → describe PR → post-mortem.
- Each skill reads outputs from prior skills and produces machine-consumable outputs for downstream skills.
- The flow includes test-status observation and reporting at multiple checkpoints.
- Verification subagents can halt a phase if test verification fails.

**Exercised end-to-end:**
- Phase 1 (pilot): `/execute-phase` invoked on a contrived plan with trivial tasks; produced an outcome file; subagent executed two `mkdir`/`printf` commands successfully.
- Phases 2–4: Five additional skills designed and implemented; SKILL.md files created/edited; YAML parsing verified.
- Phase 5: Never reached a real repo. Target-repo selection is still pending.

**Gap:** The skills have been *developed and partially validated* (YAML parse, file I/O, basic dispatch) but have never executed on a real, complex repo with real test output, real commits, real PRs, or real verification failures.

### 4. **Are the deferred checks blocking critical paths?**

From Phase 1 and 2 follow-ups:

| Deferred | Status | Impact |
|----------|--------|--------|
| `dry_run=true` path exercise (NEW-06) | Untested | `/execute-phase` has a dry_run flag in its inputs, but it has never been invoked with `dry_run=true`. The logic is code-review-correct but never executed. |
| `/setup-worktree` on a real repo (Phase 3 Task 14, live-verification deferred) | Untested | `/setup-worktree` has never been invoked on a real repo to verify worktree creation + env-file copy. |
| `/describe-pr` on a real PR (Phase 3 Task 14, live-verification deferred) | Untested | `/describe-pr` has never been invoked on a real PR to verify PR body output. |
| `/post-mortem` on a real plan (Phase 5 Task 8, pending) | Untested | `/post-mortem` has never been invoked. |
| Cluster-grouping heuristic (NEW-07) | Designed but untested | `/execute-phase` Step 2 groups tasks into parallel clusters using an informal heuristic. Whether it parallelizes or serially executes a real plan is unknown. |

All five deferred checks would be naturally exercised by Phase 5 dogfood, which is why Phase 5 was planned. Phase 5 is blocked at target-repo selection.

### 5. **What does "skills claim to work" mean operationally?**

Each SKILL.md file makes claims like:
- "This step dispatches a subagent to run `[auto]` tasks."
- "This step verifies test status against the plan's Verification text."
- "This step reads `.phase-runs/` outcome files and falls back to `git log`."

**Evidence level:**
- **Designed:** All claims exist as prose and pseudocode in the SKILL.md body.
- **Partially validated:** YAML parsing, file creation, basic subagent dispatch (Phase 1 pilot).
- **Not exercised:** Test-status reporting (all 6 skills), PR-body composition (`/describe-pr`), post-execution analysis (`/post-mortem`), worktree setup (`/setup-worktree`), dry-run mode (`/execute-phase`), cluster grouping heuristic (`/execute-phase`).

### 6. **What would it take to close these gaps?**

**Minimal dogfood scenario (Phase 5, if unblocked):**
1. Select a small real repo (e.g., a personal CLI, plugin, or scratch project).
2. Run `/repo-audit` on it — this will exercise fact-pack 05 (test-status observation) and generate evidence that test commands can be run.
3. Run `/design-plan` on the audit — this will confirm that test-status claims from the audit are readable and incorporated into planning.
4. Run `/execute-phase phase=1` with `auto_proceed=true` — this will exercise branch creation, task dispatch, verification subagent, commits, and outcome-file writing.
5. If a PR exists or is created, run `/describe-pr` on it — this will exercise phase-run reading and PR-body composition.
6. Run `/post-mortem` with `scope=partial` — this will exercise test-status re-verification and finding synthesis.

Each step would surface real evidence (pass/fail) for the deferred checks. Phase 5 preflight confirms dependencies are available (git, python3+yaml, gh CLI); only target-repo selection is needed to proceed.

---

## Conclusion

**No tests exist for the skills themselves.** The skills are designed to be test-aware (observing, reporting, and verifying test status in target repos) but are not themselves tested.

**The phase-run outcome files are the closest thing to execution proof,** but they document skill *development and internal validation* (YAML parsing, file I/O, basic dispatch), not operational behavior on a real repo.

**Critical gap:** Phase 5 integration dogfood (the planned end-to-end exercise on a real repo) was blocked at preflight when target-repo selection became a pending-human task. Without Phase 5 execution, claims about test-status reporting, PR-body generation, post-mortem analysis, and dry-run behavior remain **designed but unproven**.

**Recommendation:** Unblock Phase 5 by selecting a target repo and running the full cycle. This will exercise all 6 skills against real test output, real commits, and real verification scenarios — closing the gap between design claims and operational evidence.

