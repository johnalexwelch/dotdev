# Skill Backlog
<!-- maintained by skill-backlog; do not hand-edit status fields -->
<!-- First harvest: 2026-07-17. Impl pass: 2026-07-17 (C1–C5 + process tighten). -->
<!-- 2026-07-24 harvest: +12 reflections (07-17-skill-call-dag → 07-24-pr-delivery). Ground-truth probe closed 12 prior-open rows as implemented (a later session did the work). 8 prior rows remain open. New clusters C19–C29. -->
<!-- 2026-07-24 dispatch: Top-5 (+SB-023 rider) approved & dispatched to workflow-skill → PRs #97/#98/#99 + keystone #100 — ALL MERGED to main 2026-07-24 (admin-override past pre-existing red lint floor); Codex mirror applied. See "Dispatched this run" section. -->
<!-- 2026-07-28 harvest: +12 reflections (07-24-skill-backlog-dispatch → 07-27-pergamon-*). Ground-truth closed 6 proposals as already-landed (workflow-skill:70, describe-pr:57-61, to-prd:25, handoff:66, habits.md cp/mv+proactive-gh, skill-backlog Step5/6 lifecycle). New failure-mode clusters C30–C40. Best-practice research (Anthropic/Google/MS) informs C39. User approved dispatch of C31/C32/C34/C36/C38; C30 + C39 held for grill-with-docs first. -->

## Clusters (MECE)

| cluster | theme (failure mode) | occ sessions | open items | rank signal |
|---------|----------------------|--------------|------------|-------------|
| C1 | Canonicality-over-compatibility | 1 | 0 | implemented 2026-07-17 |
| C2 | Cross-session agent habits (CLAUDE.md) | 1–2 | 0 | implemented 2026-07-17 |
| C3 | Worktree self-cwd safety | 1 | 0 | implemented 2026-07-17 |
| C4 | Finalize→cleanup hard coupling | 1 | 0 | implemented 2026-07-17 |
| C5 | Onboarding discoverability (SKILLS-MAP) | 1 | 0 | implemented 2026-07-17 |
| C6 | PR-body artifact backfill | 1 | 1 deferred | wait for recurrence |
| CZ | Closed / already landed / reject | — | — | — |
| CP | skill-backlog process tighten | 1 | 0 | implemented 2026-07-17 |
| C7 | `workflow-` prefix misuse + router mid-chain leaf dispatch | 1 | 0 | **implemented (ground-truth 2026-07-24): router rows + owning-orchestrator rule landed; rename done** |
| C8 | Git-env hygiene + runtime-breakage detection | 1 | 1 | SB-023 (GIT_* env habit) **implemented (#97)**; SB-024 (hard-report) still open |
| C9 | Durable-habits pointer scoped to one repo, not global | 2 | 0 | **KEYSTONE — SB-028 implemented & merged (#100); habits.md now globally reachable. SB-056 consolidation still open** |
| C10 | Subagent/taskflow structured-output reliability | 1 | 0 | implemented (ground-truth 2026-07-24): SB-027 file-write default landed |
| C11 | Grilling loop default answer shape | 1 | 1 | SB-030 still open |
| C12 | Silent multi-path file-lookup reads as stalled | 1 | 1 | SB-031 still open |
| C13 | design-plan / execute-phase lane-fit for small already-decided fixes | 1 | 0 | implemented (ground-truth 2026-07-24): SB-032 + SB-033 landed |
| C14 | Sync-gate policy single-owner | 1 | 1 | SB-034 open; SB-035 resolved (base-branch-policy.md is canonical owner) |
| C15 | State snapshot goes stale by terminal action | 2 | 1 | SB-037/038 landed; SB-039 (post-review-round mergeStateStatus recheck) still open |
| C16 | Prior-phase precedent treated as still-current policy | 1 | 1 | SB-040 still open |
| C17 | Stale local git ref trusted as edit-target ground truth | 1 | 0 | implemented (ground-truth 2026-07-24): SB-041 + SB-042 landed in git-guardrails |
| C18 | `gh` identity/auth vs resource-not-found confusion | 2 | 0 | SB-043 landed in receive-review; global-reach ask folds into C9/C24 |
| **C19** | **CI-parity gap — local gate ≠ exact CI command set** | **3** | **1 dispatchable** | **high — 3× (07-23 analyst, 07-23 review, 07-24 arch); only workflow-build-one slice dispatchable, ci-deploy-fix is iris-repo-local (note only)** |
| **C20** | **Proxy-vs-ground-truth on live PR/branch state before push** | **3** | **2** | **high — 3× (files 5/10/11) + folds prior SB-039/SB-044; owner workflow-finalize** |
| **C21** | **Non-interactive shell aliases (grep→rg/find→fd/cat→bat) break pipes** | **3** | **1** | **high, cheap — dotfiles fix already committed; residual is stale harness snapshot → defensive habits.md note** |
| **C22** | **Advisory-only skill gates vs mechanical enforcement** | **2** | **1 + 1 defer** | **high — WORKFLOW_STEPS self-check dispatchable; taskflow gate migration is structural (defer)** |
| **C23** | **Reviewer-response / finalize fan-out over ALL session PRs** | **2** | **1** | **high — repeated same-session correction (file 12 Lesson 3); owner workflow-finalize + receive-review** |
| **C24** | **gh auth-hygiene reachable globally (not just receive-review)** | **2** | **1** | **med — folds into C9 keystone (habits.md global reach)** |
| **C25** | **Worktree vanishes under merge-queue between plan and execute** | **2** | **1** | **med — owner cleanup-delivery; kin of C15** |
| **C26** | **herdr skill missing worktree + pane subcommand docs** | **2** | **1** | **med — herdr/SKILL.md** |
| **C27** | **handoff multi-line-command / sequential-dependency callouts** | **1** | **1** | **low — cheap handoff/SKILL.md callout** |
| **C28** | **improve-codebase-architecture: missing-tests vs judgment-call human gate** | **1** | **1** | **high leverage — caused a slice-9 human-gate reversal this session** |
| **C29** | **workflow-review model-floor active verification (not self-report)** | **1** | **1** | **high per author — specialist lanes ran below opus floor** |
| **C30** | **Human-gate taxonomy — reviewer-validation ≠ maintainer/operator/secret-custody gate** | **3** | **6 (1 net-new skill)** | **HIGHEST — GRILL #1 (2026-07-28). describe-pr piece already landed. Touches workflow-router/finalize/to-issues/handoff/prompt-builder + missing `process-needs-human-review`** |
| **C31** | **Clean-state exit contract + cleanup report split** | **4** | **7** | **high — cleanup-delivery already has Final Report §119 + re-verify §105; these are refinements + workflow-finalize clean-or-carried gate** |
| **C32** | **Stale local state.yaml/branch vs verified remote base (kin C15/C16/C20)** | **3** | **3** | **high — owner handoff; read base via `git show <base>:…`, live-queue refresh** |
| **C33** | **gh multi-account proactive assert + no-parallel-switch** | **4** | **1 residual** | **mostly LANDED (habits.md proactive bullet); residual = git-guardrails no-parallel-`gh auth switch`. triage/iris = repo-local out-of-pipeline** |
| **C34** | **Direct-execution bias (do-don't-instruct / delegate-only-when-stuck / re-check after user changes state / restate on pivot)** | **2** | **4** | **med-high — runbook-author + workflow-build-one + workflow-debug + habits.md** |
| **C35** | **Route/artifact heaviness for non-mutating asks** | **2** | **2** | **med — workflow-router: prompt-fix→direct; fresh-start conflict-check** |
| **C36** | **Verify tracker mutations / never suppress mutating cmd stderr** | **1** | **3** | **high leverage — silently no-op'd an entire batch; triage + habits.md** |
| **C37** | **PRD/prompt decomposition gates (vertical-slice + phase-boundary)** | **1–2** | **2** | **to-prd vertical-slice ALREADY LANDED (:25); residual = prompt-builder phase-boundary checklist + AFK split (AFK folds into C30)** |
| **C38** | **autonomous-backlog: existing-PRD fast path + post-merge dependent-issue loop** | **1** | **2** | **high per-author — workflow-autonomous-backlog** |
| **C39** | **Project-local OpenBao/Pergamon operator skills (4 extraction candidates)** | **4** | **4** | **GRILL #2 (2026-07-28) — consolidate into 1? dotfiles-global vs Pergamon-repo? Best-practice: consolidate narrow project skills as core+tag/repo-local** |
| **C40** | **runbook-author operator-UI field-by-field mode** | **2** | **1** | **med — group with C34 runbook-author edits** |
| **C41** | **grill-with-docs delegate mode (auto-accept → domain-specialist consensus loop; "defer" mid-grill escape)** | **1** | **1** | **HIGH — user-requested north-star feature; realizes 2a (AFK-unless-necessary) for grilling itself. D1–D5 locked 2026-07-28** |

## Dispatched this run (2026-07-28 — 10 cohesive PRs, grouped by actual target file)

All rows below are `accepted` pending merge (Step 6: flip to `implemented` only on merge). **Merge #105 FIRST** — G2/G3/G5 cite the taxonomy doc it creates (1-cycle dead link otherwise). Verified all 10 genuinely OPEN via `gh pr list` (G10 initially failed to open its PR — recovered as #106).

| PR | group | files | clusters | SB rows | notes |
|----|-------|-------|----------|---------|-------|
| **#105** | G1 (KEYSTONE) | `_docs/human-gate-taxonomy.md` (new) + to-issues, describe-pr, prompt-builder, setup-skills | C30 | 066/067/069 + doc | **merge first**; AFK-default governing principle |
| #106 | G10 | grill-with-docs (+references/delegate-mode.md) | C41 | 096 | grill delegate mode D1–D5; PR recovered after agent misreport |
| #104 | G6 | runbook-author, workflow-build-one, workflow-debug, habits.md | C34/C40/C36 | 080/081/082/083/085/089 | single repo (~/dotdev root) so habits.md rode the same PR |
| #107 | G5 | handoff | C30/C32 | 068/076/077/078 | cites taxonomy doc (#105) |
| #108 | G4 | cleanup-delivery | C31 | 072/073/074/075 | |
| #109 | G3 | workflow-finalize | C30/C31 | 065/071 | cites taxonomy doc (#105) |
| #110 | G2 | workflow-router | C30/C35 | 064/087 | cites taxonomy doc (#105) |
| #111 | G9 | git-guardrails | C33 | 079 | multi-account push slice; complements landed habits.md rotation |
| #112 | G7 | triage | C36 | 084/086 | |
| #113 | G8 | workflow-autonomous-backlog | C38 | 088 | |

**Caveats for the human merge:**
1. **Merge #105 before #107/#109/#110** (taxonomy-doc dependency). No hard conflicts — disjoint files.
2. **Pre-merge Codex mirror**: G2 (#110) and G9 (#111) agents ran the Codex mirror pre-merge (mirrored unreviewed content). Harmless — re-run `~/dotdev/dotfiles/.config/agents/skills/sync-codex-skills.sh --apply` from merged `main` after all merge to correct. Do NOT trust the pre-merge mirror.
3. **Codex mirror still pending** for all skill edits until merge; habits.md/describe-pr are docs (no mirror). Run the mirror once post-merge, then flip rows to `implemented` + close this section.
4. C39 (OpenBao/Pergamon skills) = **out-of-pipeline** (SB-095): build in the Pergamon repo, not dotfiles-global. Deferred to a Pergamon session.

## Ledger

<!-- 2026-07-28 dispatch: rows SB-064/065/066/067/068/069/071/072/073/074/075/076/077/078/079/080/081/082/083/084/085/086/087/088/089/096 are all `accepted` (PRs #104–#113 open, unmerged). Ground-truth probe next harvest against merged state. -->

| id | first_seen | occ | sources | owning skill/file | summary | priority | status | action | cluster | resolution |
|----|-----------|-----|---------|-------------------|---------|----------|--------|--------|---------|------------|
| SB-001 | 2026-07-09 | 1 | 2026-07-09-router-exclusivity-grill | grill-with-docs | Expert-judgment Qs: recommend alongside open question | med | implemented | — | CZ | already in grill-with-docs |
| SB-002 | 2026-07-09 | 1 | 2026-07-09-router-exclusivity-grill | grill-with-docs | Gating decisions: cover recovery/escape-hatch first | med | implemented | — | CZ | already in grill-with-docs |
| SB-003 | 2026-07-13 | 1 | 2026-07-13-wayfinder-74-shell-friction | (none) | Meta: "none require a skill edit" | low | rejected | reject | CZ | non-proposal |
| SB-004 | 2026-07-13 | 1 | 2026-07-13-wayfinder-74-shell-friction | (none) | Optional shell-usage guidance line | low | rejected | reject | CZ | personal reflex |
| SB-005 | 2026-07-16 | 1 | 2026-07-16-skill-path-and-fix-verification | session-insight | Stale Stow source path | high | implemented | — | CZ | already landed |
| SB-006 | 2026-07-16 | 1 | 2026-07-16-skill-path-and-fix-verification | session-insight | Handoff edge-context re-verify | med | implemented | — | CZ | already landed |
| SB-007 | 2026-07-16 | 1 | 2026-07-16-skill-path-and-fix-verification | setup-worktree | Audit `--show-toplevel` | low | implemented | — | CZ | already uses absolute-git-dir |
| SB-008 | 2026-07-16 | 1 | 2026-07-16-skill-path-and-fix-verification | handoff | Share absolute-git-dir idiom | low | implemented | — | CZ | already folded |
| SB-009 | 2026-07-16 | 1 | 2026-07-16-toon-usage-audit | cleanup-delivery | Verify removals against running system | high | implemented | — | CZ | already landed |
| SB-010 | 2026-07-17 | 1 | 2026-07-17-canonical-paths-workflow-connectivity | workflow-router | Canonicality-over-compatibility preflight | high | implemented | implement | C1 | Canonicality Gate added to workflow-router Preflight |
| SB-011 | 2026-07-17 | 1 | 2026-07-17-canonical-paths-workflow-connectivity | workflow-effectiveness-audit | Duplicate mirrors after symlink removal | high | implemented | fold | C1 | Folded into SB-012 |
| SB-012 | 2026-07-17 | 1 | 2026-07-17-canonical-paths-workflow-connectivity | cleanup-delivery | Symlink inventory + duplicate-path drift report | med | implemented | implement | C1 | Canonicalization section in cleanup-delivery |
| SB-013 | 2026-07-17 | 1 | 2026-07-17-canonical-paths-workflow-connectivity | session-insight | Post-migration semantic sanity | med | implemented | fold | C2 | Folded into SB-014 |
| SB-014 | 2026-07-17 | 1 | 2026-07-17-openwiki-onboarding-habits | docs/agents/habits.md | Agent Habits: wired-tools, mutating regen tools, semantic sanity | high | implemented | implement | C2 | Durable `docs/agents/habits.md`; AGENTS.md+CLAUDE.md point |
| SB-015 | 2026-07-17 | 1 | 2026-07-17-killswitch-finalize-cleanup-guard | cleanup-delivery | Self-cwd guard before worktree remove | high | implemented | implement | C3 | Step 5 + Safety Checks in cleanup-delivery |
| SB-016 | 2026-07-17 | 1 | 2026-07-17-killswitch-finalize-cleanup-guard | workflow-finalize | Require Load-and-run cleanup-delivery | med | implemented | implement | C4 | Completion section tightened |
| SB-017 | 2026-07-17 | 1 | 2026-07-17-killswitch-finalize-cleanup-guard | describe-pr / workflow-finalize | Backfill `.pr-bodies/` from gh when missing | low | deferred | defer | C6 | Wait for recurrence |
| SB-018 | 2026-07-17 | 1 | 2026-07-17-openwiki-onboarding-habits | dotfiles/.claude/SKILLS-MAP.md | Starting a new project → setup-skills | med | implemented | implement | C5 | Section added to SKILLS-MAP |
| SB-019 | 2026-07-17 | 1 | this-run process critique | skill-backlog | Process: ground-truth, failure-mode cluster, fold pass, dual-runtime landing | high | implemented | implement | CP | skill-backlog rewritten |
| SB-020 | 2026-07-17 | 1 | 2026-07-17-rename-workflow-effectiveness-audit | workflow-effectiveness-audit → skill-system-audit | Rename terminal governance audit off orchestrator prefix | high | implemented | implement | C7 | **Ground-truth 2026-07-24: `skill-system-audit/` exists on disk; `workflow-effectiveness-audit` gone** |
| SB-021 | 2026-07-17 | 1 | 2026-07-17-router-entry-vs-chain-audit | workflow-router | receive-review/prompt-builder routed as leaves; no ship/finalize row | high | implemented | implement | C7 | **Ground-truth 2026-07-24: router:173 routes "receive review"→workflow-finalize; :174 adds ship/finalize row** |
| SB-022 | 2026-07-17 | 1 | 2026-07-17-router-entry-vs-chain-audit | workflow-router | Durable rule: Routes-to names owning orchestrator | med | implemented | fold | C7 | **Ground-truth 2026-07-24: router:193 rule present verbatim** |
| SB-023 | 2026-07-17 | 1 | 2026-07-17-skill-pipeline-habits-openwiki | docs/agents/habits.md | Habit: unset GIT_DIR/GIT_INDEX_FILE/GIT_WORK_TREE/GIT_COMMON_DIR + verify toplevel/author before git write | high | implemented | implement | C8 | **Dispatched 2026-07-24 → PR #97 commit `f521305` (rode SB-047 habits.md edit)** |
| SB-024 | 2026-07-17 | 1 | 2026-07-17-skill-pipeline-habits-openwiki | workflow-skill (Step 4) | Claude-runtime breakage → hard report with fix hint (expected symlink target), not soft | med | new | implement | C8 | **Ground-truth 2026-07-24: still OPEN — workflow-skill:71 still soft "report it"** |
| SB-025 | 2026-07-17 | 1 | 2026-07-17-skill-pipeline-habits-openwiki | session-insight | Human gates wording: habits.md-first | med | implemented | — | CZ | already implemented |
| SB-026 | 2026-07-17 | 1 | 2026-07-17-skill-pipeline-habits-openwiki | skill-backlog | Implemented-marker convention | low | implemented | — | CZ | Step 6 states "prefer ground-truth" |
| SB-027 | 2026-07-17 | 1 | 2026-07-17-dispatch-hygiene-review-taskflow-output | workflow-review | Default lane dispatch to file-write + one-line confirm | high | implemented | implement | C10 | **Ground-truth 2026-07-24: workflow-review:89 file-write default present** |
| SB-028 | 2026-07-17 | 2 | 2026-07-17-dispatch-hygiene + 2026-07-19-path-guard-phase2 | `~/.claude/CLAUDE.md` (global) | **KEYSTONE**: global CLAUDE.md never points to docs/agents/habits.md → habit unreachable outside ~/dotdev | high | implemented | implement | C9 | **Dispatched 2026-07-24 → extracted to standalone PR #100 (`7ea63a4`, cherry-pick of `0d64cf4`) off origin/main; dup on #96 no-ops on rebase. Was ground-truth OPEN; global CLAUDE.md had no habits.md pointer** |
| SB-029 | 2026-07-17 | 1 | 2026-07-17-dispatch-hygiene | workflow-finalize | Missing-sub-skill fallback wording | low | implemented | fold | C9 | Folded into SB-028 |
| SB-030 | 2026-07-19 | 1 | 2026-07-19-path-guard-seam-grill-to-phase1 | grill-with-docs | Full-mode default should state alternatives + why + tradeoffs, not just "recommended answers" | med | new | implement | C11 | **Ground-truth 2026-07-24: still OPEN — grill-with-docs:59-65 says only "recommended answers"** |
| SB-031 | 2026-07-19 | 1 | 2026-07-19-path-guard-seam-grill-to-phase1 | improve-codebase-architecture | Interim status statement during multi-path silent file reads | low | new | implement | C12 | **Ground-truth 2026-07-24: still OPEN — no interim-status requirement in Step 1/3** |
| SB-032 | 2026-07-19 | 1 | 2026-07-19-path-guard-seam-grill-to-phase1 | design-plan | Name a lane for small already-decided governance/infra fix | med | implemented | implement | C13 | **Ground-truth 2026-07-24: design-plan:5,113 name governance/infra brief-mode lane** |
| SB-033 | 2026-07-19 | 1 | 2026-07-19-path-guard-seam-grill-to-phase1 | execute-phase | Size/ambiguity threshold exception to per-cluster subagent dispatch | med | implemented | implement | C13 | **Ground-truth 2026-07-24: execute-phase:184-190 small-cluster exception present** |
| SB-034 | 2026-07-19 | 1 | 2026-07-19-path-guard-seam-grill-to-phase1 | cleanup-delivery | Codify "isolate already-made edits into a compliant worktree" maneuver | low | new | implement | C14 | **Ground-truth 2026-07-24: still OPEN — cleanup-delivery only has the opposite self-cwd guard** |
| SB-035 | 2026-07-19 | 1 | 2026-07-19-path-guard-seam-grill-to-phase1 | setup-worktree/references/base-branch-policy.md | Single canonical owner for sync-gate policy | low | implemented | needs-decision | C14 | **Ground-truth 2026-07-24: base-branch-policy.md IS the canonical owner; execute-phase:230 + setup-worktree point to it** |
| SB-036 | 2026-07-19 | 2 | 2026-07-19-path-guard-phase2-merge-cleanup | `~/.claude/CLAUDE.md` (global) | 2nd occurrence of SB-028 failure mode (searched instead of reusing read context) | high | new | fold | C9 | Fold into SB-028 — 2nd-session evidence |
| SB-037 | 2026-07-19 | 1 | 2026-07-19-path-guard-phase2-merge-cleanup | cleanup-delivery (Step 5) | Re-verify state immediately before each destructive action under concurrency | med | implemented | implement | C15 | **Ground-truth 2026-07-24: cleanup-delivery:105 re-verify step present** |
| SB-038 | 2026-07-19 | 1 | 2026-07-19-path-guard-phase2-merge-cleanup | cleanup-delivery (Step 5) | `gh pr ready` draft preflight + multi-branch `-D` existence check | low | implemented | implement | C15 | **Ground-truth 2026-07-24: cleanup-delivery:117 draft preflight + :112 multi-branch check** |
| SB-039 | 2026-07-20 | 1 | 2026-07-20-path-guard-phase3 | workflow-finalize / workflow-review | Re-fetch base + re-check mergeStateStatus after a review round | med | implemented | fold | C20 | **Dispatched 2026-07-24 (folded into SB-046) → PR #99 commit `e0a2c7e`** |
| SB-040 | 2026-07-20 | 1 | 2026-07-20-path-guard-phase3 | docs/agents/habits.md (or execute-phase) | Git-history precedent goes stale as proxy for in-force policy | med | new | implement | C16 | **Ground-truth 2026-07-24: still OPEN — no such habit in habits.md/execute-phase** |
| SB-041 | 2026-07-20 | 1 | 2026-07-20-stale-worktree-mypy-chase | git-guardrails | Before follow-up fix, compare HEAD vs origin/<merge-target> | high | implemented | implement | C17 | **Ground-truth 2026-07-24: git-guardrails:48 checkpoint present** |
| SB-042 | 2026-07-20 | 1 | 2026-07-20-stale-worktree-mypy-chase | git-guardrails | Internally-inconsistent static-analysis → diff file vs upstream before tool internals | med | implemented | implement | C17 | **Ground-truth 2026-07-24: git-guardrails:49 heuristic present** |
| SB-043 | 2026-07-20 | 1 | 2026-07-20-stale-worktree-mypy-chase | receive-review (+ gh-shelling skills) | On `gh` resolve/not-found error run `gh auth status` first | med | implemented | implement | C18 | **Ground-truth 2026-07-24: receive-review:28 present (global-reach ask → SB-050/C24)** |
| SB-044 | 2026-07-17 | 1 | 2026-07-17-dispatch-hygiene (addendum) | workflow-finalize (merge-authority) | Finalize asserted merge-authority from CLAUDE.md summary without reading `.github/CODEOWNERS` | med | implemented | fold | C20 | Renumbered from stray dup; folded into SB-046 → PR #99 commit `e0a2c7e` (CODEOWNERS clause) |
| SB-045 | 2026-07-24 | 3 | 2026-07-23-analyst-arch-delivery-ci-parity, 2026-07-23-workflow-review-merged-state, 2026-07-24-arch-stack-merge-queue-finalize | workflow-build-one (pre-push gate) | Require full gate `ruff check src tests && ruff format src tests && mypy src && pytest` (incl tests dir) before push | high | implemented | implement | C19 | **Dispatched 2026-07-24 → PR #98 (draft) commit `ca9b88f`, landed in workflow-finalize Step 6 (where build-one's finalize gate lives). Codex mirror pending merge.** ci-deploy-fix (iris) still out of pipeline |
| SB-046 | 2026-07-24 | 3 | 2026-07-22-mdr-district-obt, 2026-07-23-workflow-review-merged-state, 2026-07-24-arch-stack-merge-queue-finalize | workflow-finalize | Ground-truth PR-state precheck before pushing a fix: `gh pr view <n> --json state,mergedAt,headRefOid`; if MERGED/CLOSED land fresh PR onto base (same-SHA re-push fires no `synchronize`) | high | implemented | implement | C20 | **Dispatched 2026-07-24 → PR #99 commit `e0a2c7e`.** Absorbs SB-039 + SB-044. Codex mirror pending merge |
| SB-047 | 2026-07-24 | 3 | 2026-07-22-multi-repo-git-worktree-branch-audit, 2026-07-23-shell-alias-posix-breakage, 2026-07-24-arch-stack-merge-queue-finalize | docs/agents/habits.md | Non-interactive shell hygiene: grep/find/cat may be aliased/functioned to rg/fd/bat and ignore piped stdin or differ on flags — use `command grep`/absolute paths or python3/native filtering | high | implemented | implement | C21 | **Dispatched 2026-07-24 → PR #97 commit `f521305`.** Dotfiles alias fix already committed & ground-truthed clean; residual is harness's stale snapshot (`function grep` at snapshot:1035) → defensive habit. Global reach gated on SB-028/#100 |
| SB-048 | 2026-07-24 | 2 | 2026-07-19-skill-compliance-no-mechanical-enforcement, 2026-07-21-pergamon-phase1-bootstrap-gotchas | workflow-finalize (+ habits.md) | Self-check: absence of the required WORKFLOW_STEPS ledger in the current response = self-detected halt; skill gates are advisory, silent non-display = halt | high | new | implement | C22 | Taskflow mechanical-gate migration (open q) split to SB-061/defer |
| SB-049 | 2026-07-24 | 2 | 2026-07-24-pr-delivery-reviewer-response, 2026-07-19-skill-compliance-no-mechanical-enforcement | workflow-finalize (+ receive-review cross-link) | Pre-finalize gate: enumerate every session PR (`gh pr list --author @me`), require all inline review threads replied+resolved; finalize is a fan-out over ALL session PRs, not just the last; reviewer-response non-skippable | high | implemented | implement | C23 | **Dispatched 2026-07-24 → PR #99 commit `e0a2c7e`** (+ receive-review cross-link; advisor fixed a per-PR deadlock pre-commit). file 12 = repeated same-session correction |
| SB-050 | 2026-07-24 | 2 | 2026-07-23-a10-example-model-removal, 2026-07-23-analyst-arch-delivery-ci-parity | docs/agents/habits.md | gh auth-hygiene reachable globally: "Could not resolve to a Repository" → treat as auth-account flip first, `gh auth status`/`gh auth switch` before manual fallback | med | implemented | fold | C24 | **Dispatched 2026-07-24 (folded into SB-047) → PR #97 commit `f521305`.** Global reach gated on SB-028/#100. Skill-level fix already landed (SB-043) |
| SB-051 | 2026-07-24 | 2 | 2026-07-24-arch-stack-merge-queue-finalize, 2026-07-24-pr-delivery-reviewer-response | cleanup-delivery | Worktrees may be auto-removed by merge queue between plan and execute: re-check `-d <path>` before cd/remove, prefer `git -C <primary>` for branch mutations | med | new | implement | C25 | Kin of C15 stale-snapshot family |
| SB-052 | 2026-07-24 | 2 | 2026-07-22-multi-repo-git-worktree-branch-audit, 2026-07-23-a10-example-model-removal | herdr/SKILL.md | Document `herdr worktree list/create/open/remove` (remove targets open workspace IDs only; use plain `git worktree remove` for orphaned) + `pane split`/`pane run` trigger note | med | new | implement | C26 | herdr SKILL.md path resolves canonically |
| SB-053 | 2026-07-24 | 1 | 2026-07-21-pergamon-phase1-bootstrap-gotchas | handoff/SKILL.md | Bolded callout: multi-line commands get flattened; `mkdir`+`cp`/`install` are sequentially dependent, never parallel calls | low | new | implement | C27 | — |
| SB-054 | 2026-07-24 | 1 | 2026-07-24-arch-stack-merge-queue-finalize | improve-codebase-architecture | Distinguish "missing-tests → write red→green, proceed" from "invariant-is-judgment-call → genuine human gate" before marking a slice human-gated | high | new | implement | C28 | Singleton but high leverage — caused a slice-9 human-gate reversal this session |
| SB-055 | 2026-07-24 | 1 | 2026-07-23-workflow-review-merged-state | workflow-review (reviewer-roster.md + SKILL.md) | Model-floor: specialist lanes may run below opus floor; use opus general `reviewer` + per-lane brief; capture `model_used` per lane, re-run below-floor | high | new | implement | C29 | Strengthen self-report backstop into active per-lane verification |
| SB-056 | 2026-07-24 | 4 | 2026-07-19-nora-meal-plan-recipe-json, 2026-07-22-mdr-district-obt, 2026-07-22-multi-repo-git-worktree-branch-audit, 2026-07-24-pr-delivery-reviewer-response | docs/agents/habits.md | Consolidated "verify affordances/ground-truth before acting" additions: fail-fast on external-tool viability (check env), confirm plan-vs-build mode on ambiguous asks, check tool-inventory before hand-rolling, scan loaded skills before "no tool", repeated identical correction ⇒ fix the process that turn | med | new | implement | C9 | Group as ONE edit to avoid habits.md sprawl; global reach gated on SB-028 |
| SB-057 | 2026-07-24 | 1 | 2026-07-22-multi-repo-git-worktree-branch-audit | git-worktree-audit (skill-extraction) | Multi-repo branch/worktree audit skill | med | implemented | — | CZ | **Ground-truth 2026-07-24: already built — `git-worktree-audit/SKILL.md` on disk** |
| SB-058 | 2026-07-24 | 1 | 2026-07-22-mdr-district-obt | legacy-model-parity-port (skill-extraction) | Port legacy reporting models into staging→intermediate→mart with row-for-row parity | med | deferred | defer | C-ext | Routing (new vs extend) open; repo-local dbt context — wait for recurrence |
| SB-059 | 2026-07-24 | 1 | 2026-07-19-nora-meal-plan-recipe-json | nora-recipe-authoring (skill-extraction) | Hand-author Nora recipe JSON when live CLI unavailable | low | deferred | defer | C-ext | Author-deferred; likely project-local doc, not global skill |
| SB-060 | 2026-07-24 | 1 | 2026-07-21-pergamon-phase1-bootstrap-gotchas | macos-remote-bootstrap-gotchas (skill-extraction) | macOS SSH-bootstrap gotchas checklist | low | deferred | defer | C-ext | Author-deferred until a 2nd macOS-bootstrap project appears |
| SB-061 | 2026-07-24 | 1 | 2026-07-19-skill-compliance-no-mechanical-enforcement | taskflow (gate phases) | Migrate load-bearing skill gates into mechanical `taskflow` `gate` phases | med | deferred | needs-evidence | C22 | Structural, not a drop-in; flagged not-drop-in by author — defer/needs-evidence |
| SB-062 | 2026-07-28 | 1 | 2026-07-24-skill-backlog-dispatch-merge | workflow-skill | Landing must cut worktree off `origin/main`, never commit in primary checkout | high | implemented | — | CZ | **Ground-truth 2026-07-28: workflow-skill:70 already mandates this** |
| SB-063 | 2026-07-28 | 1 | 2026-07-24-skill-backlog-dispatch-merge | skill-backlog | Step 6 post-merge lifecycle + Step 5 actual-target-file resolution | med | implemented | — | CZ | **Ground-truth 2026-07-28: both already in current SKILL.md** |
| SB-064 | 2026-07-28 | 3 | 2026-07-26-pergamon-afk-human-gates | workflow-router | Human-gate taxonomy preflight: classify maintainer-decision/operator-runtime/secret-custody/reviewer-validation; only first 3 block AFK | high | new | grill | C30 | GRILL #1 |
| SB-065 | 2026-07-28 | 1 | 2026-07-26-pergamon-afk-human-gates | workflow-finalize | Stale `needs-human-review` label not itself a merge blocker for static PR w/ approvals+standing authority; reconcile label post-merge | high | new | grill | C30 | GRILL #1 |
| SB-066 | 2026-07-28 | 1 | 2026-07-26-pergamon-afk-human-gates | process-needs-human-review (MISSING) | Narrow def to product/maintainer/operator gate; reviewer validation handled by workflow-review | high | new | grill | C30 | **Skill does not exist — net-new vs fold decision in grill** |
| SB-067 | 2026-07-28 | 1 | 2026-07-26-pergamon-afk-human-gates | to-issues | Split `Human review` into maintainer/operator gate vs reviewer validation | med | new | grill | C30 | GRILL #1 |
| SB-068 | 2026-07-28 | 1 | 2026-07-26-pergamon-afk-human-gates | handoff | Standing-permissions/corrected-policies section (preserve AFK merge authority, narrowed gates) | med | new | grill | C30 | GRILL #1 |
| SB-069 | 2026-07-28 | 2 | 2026-07-27-pergamon-phase7-setup-handoff, 2026-07-26-pergamon-afk-human-gates | prompt-builder | Split AFK output into execution_mode / human_review_gate / acceptance_gate | high | new | grill | C30 | GRILL #1 |
| SB-070 | 2026-07-28 | 1 | 2026-07-27-pergamon-phase6-backlog-cleanup | describe-pr | Human-review detection: `ready-for-human`/`Type: HITL` ≠ review-required | med | implemented | — | CZ | **Ground-truth 2026-07-28: describe-pr:57-61 already correct** |
| SB-071 | 2026-07-28 | 1 | 2026-07-27-cleanup-delivery-merged-worktrees | workflow-finalize | Clean-state exit contract gate: report worktree clean / primary untouched / artifacts committed-handed-preserved | high | new | implement | C31 | dispatch |
| SB-072 | 2026-07-28 | 1 | 2026-07-27-cleanup-delivery-merged-worktrees | cleanup-delivery | Fetch all relevant remotes + identify authoritative source remote/branch before cleanup (not just `origin --prune`) | high | new | implement | C31 | Evidence: `personal/main` authoritative while local `main` behind |
| SB-073 | 2026-07-28 | 1 | 2026-07-27-cleanup-delivery-merged-worktrees | cleanup-delivery | Handoff-only-branch bucket (clean pushed, no PR, handoff payload → explicit keep/PR/delete) | med | new | implement | C31 | dispatch |
| SB-074 | 2026-07-28 | 2 | 2026-07-27-cleanup-delivery-merged-worktrees, 2026-07-27-pergamon-phase6-backlog-cleanup | cleanup-delivery | Primary-checkout sync/dirty as standard report line + dirty-handoff/docs-drift class distinct from active-impl dirty | med | new | implement | C31 | dispatch |
| SB-075 | 2026-07-28 | 1 | 2026-07-27-pergamon-cleanup-router-split | cleanup-delivery | Cleanup plan ends w/ exact approval phrase + one-line "will not touch" list | med | new | implement | C31 | dispatch |
| SB-076 | 2026-07-28 | 2 | 2026-07-27-pergamon-phase6-backlog-cleanup, 2026-07-27-pergamon-openbao-handles | handoff | Before reading `state.yaml`, if branch behind verified base read base copy via `git show <base>:docs/executions/state.yaml` | med | new | implement | C32 | dispatch |
| SB-077 | 2026-07-28 | 1 | 2026-07-27-pergamon-phase7-setup-handoff | handoff | Live-queue-refresh: re-read open ready-for-agent issues + PR merge states, override stale state.yaml w/ explicit conflict note | med | new | implement | C32 | dispatch |
| SB-078 | 2026-07-28 | 1 | 2026-07-27-pergamon-sso-delivery | handoff | Repo-copy handoff dirties checkout unless committed/ignored/removed; if "clean primary" asked, ask commit vs mirror-only | high | new | implement | C32 | dispatch (handoff group) |
| SB-079 | 2026-07-28 | 2 | 2026-07-27-cleanup-delivery-merged-worktrees, 2026-07-27-pergamon-phase7-setup-handoff | git-guardrails | Don't parallelize `gh auth switch`; `GH_TOKEN=… git -c credential.helper=… push` pattern for multi-account (no token print) | low | new | implement | C33 | habits.md proactive already landed |
| SB-080 | 2026-07-28 | 1 | 2026-07-27-pergamon-openbao-secret-key | runbook-author | Direct-execution guard: list steps agent can safely do now + execute unless instructions-only requested | high | new | implement | C34 | dispatch (runbook-author group) |
| SB-081 | 2026-07-28 | 2 | 2026-07-27-pergamon-openbao-secret-key, 2026-07-27-pergamon-openbao-handles | workflow-build-one | Delegate only after exhausting safe local/remote progress; HITL secret triage require authority inventory + prove operator auth before planning value movement | med | new | implement | C34 | dispatch |
| SB-082 | 2026-07-28 | 1 | 2026-07-27-pergamon-openbao-secret-key | workflow-debug | User-changed-runtime-state rule: one authoritative live check before repeating prior blocker analysis | high | new | implement | C34 | dispatch |
| SB-083 | 2026-07-28 | 1 | 2026-07-27-pergamon-openbao-secret-key | docs/agents/habits.md | After a user pivot, discard queued closeout + restate active objective in one line before acting | med | new | implement | C34 | dispatch (habits.md group) |
| SB-084 | 2026-07-28 | 1 | 2026-07-27-triage-cve-batch-gh-auth-flip | triage | Verify every applied tracker mutation against authoritative state; never suppress mutating cmd stderr/exit | high | new | implement | C36 | dispatch |
| SB-085 | 2026-07-28 | 1 | 2026-07-27-triage-cve-batch-gh-auth-flip | docs/agents/habits.md | Never suppress a mutating command's stderr/exit; re-read state after mutation to confirm it applied | high | new | implement | C36 | fold w/ SB-083 into one habits.md edit |
| SB-086 | 2026-07-28 | 1 | 2026-07-27-triage-cve-batch-gh-auth-flip | triage | Nightly-scan CVE batch pattern (group by package, cross-check lockfile/image, split fixed/unexploitable/actionable, consolidate dupes) | med | new | implement | C36 | dispatch (triage group) |
| SB-087 | 2026-07-28 | 2 | 2026-07-27-pergamon-phase-prompt-routing, 2026-07-27-pergamon-cleanup-router-split | workflow-router | Non-mutating prompt/work-order fix → direct/prompt-builder route (not full route card); Step0 active-ledger + explicit "start fresh" unrelated → conflict-check only | med | new | implement | C35 | dispatch |
| SB-088 | 2026-07-28 | 1 | 2026-07-27-pergamon-phase6-backlog-cleanup | workflow-autonomous-backlog | Existing-PRD/issues fast path (skip discovery/grill/to-prd → prepare AFK queue) + post-merge dependent-issue loop | high | new | implement | C38 | dispatch |
| SB-089 | 2026-07-28 | 2 | 2026-07-27-pergamon-sso-delivery, 2026-07-27-pergamon-openbao-secret-key | runbook-author | Operator-UI field-by-field mode: provider-visible/container-visible/browser-tunnel URLs as separate entries | med | new | implement | C40 | fold w/ SB-080 into one runbook-author edit |
| SB-090 | 2026-07-28 | 1 | 2026-07-27-pergamon-phase7-setup-handoff | to-prd | Vertical-slice PRD gate | high | implemented | — | CZ | **Ground-truth 2026-07-28: to-prd:25 already requires vertical-slice decomposition** |
| SB-091 | 2026-07-28 | 1 | 2026-07-27-pergamon-phase7-setup-handoff | prompt-builder | Phase-boundary checklist for repo work-order prompts (roadmap, decision log, prior-phase review, numbering, adjacent boundaries) | med | new | defer | C37 | singleton; revisit w/ C30 prompt-builder edit |
| SB-092 | 2026-07-28 | 1 | 2026-07-27-pergamon-phase7-setup-handoff | setup-skills | After single-context layout, require root CONTEXT.md or draft for approval | med | new | defer | C-misc | singleton |
| SB-093 | 2026-07-28 | 1 | 2026-07-27-pergamon-sso-delivery | workflow-finalize | Close `state.yaml` before draft PR when no further source work expected | med | new | defer | C-misc | low; rerun review if later source change |
| SB-094 | 2026-07-28 | 1 | 2026-07-27-pergamon-sso-delivery | workflow-review | Synthesis checklist "convert accepted review findings into validation checks when feasible" before rerunning lanes | med | new | defer | C-misc | singleton |
| SB-095 | 2026-07-28 | 4 | 2026-07-27-openbao-ui-auth-diagnosis, 2026-07-27-pergamon-openbao-handles, 2026-07-27-pergamon-openbao-secret-key, 2026-07-27-pergamon-sso-delivery | new skill(s) OR Pergamon repo | Project-local OpenBao/Pergamon operator skills | high | deferred | out-of-pipeline | C39 | **GRILLED 2026-07-28: consolidate 3 Pergamon skills → 1 `pergamon-openbao-operator` IN PERGAMON REPO (not dotfiles-global); generic slices fold into runbook-author (C40) + workflow-build-one (C34); defer/promote-if-needed. Out-of-pipeline note.** |
| SB-096 | 2026-07-28 | 1 | user-request (2026-07-28 grill session) | grill-with-docs | Delegate mode: auto-accept recommendations → domain-specialist subagent review (D1: security→security-reviewer, arch→analyst, risk→risk-reviewer, product→critic, tie→plan-arbiter) → consensus loop (D2: specialist can override; cap 3 rounds; no-consensus→escalate that decision to human) → per-domain-batch review (D3) → "defer"=all-remaining / "defer this"=current (D4) → provenance tags human/auto+specialist-consensus/escalated-human (D5). Requires HITL-vs-delegate mode select at grill start. | high | new | implement | C41 | GRILL-resolved; dispatch this run |

## Out-of-pipeline (note only — workflow-skill cannot land these)

Repo-local skills that live in **other repos** (not `~/dotdev/dotfiles/.config/agents/skills/`), so they are outside this pipeline's canonical-source landing. Recorded for the owning repo's own retro, not dispatched here:

- **ci-deploy-fix** (iris repo) — "exact CI trio" parity rule + "diagnose from source, use `gh pr view --json statusCheckRollup/mergeStateStatus` not `gh pr checks`" (files 8, 11). *The generalizable slice is captured as SB-045 on workflow-build-one.*
- **reconcile-tables / sql-standards** (dbt repo) — lineage/`ref()` confirmation before comparison SQL; staging-conforms-names convention (file 5).
- **redshift** (repo-local) — `psql -f query.sql -o out.txt` when heredoc stdout swallowed (file 7).
- **pr-responder / git-guardrails** (repo-local variant) — gh 404 → `gh auth status`/`switch` (file 7). *Generalizable slice already landed as SB-043 in canonical receive-review.*

Non-skill / human-action items (not skill changes — flagged, not queued):

- **Enable `main` branch protection + CODEOWNERS review** (file 3, iris/classd repos) — repo governance, human action. Verified at the time: `main` had zero branch protection (`gh api` → 404).
- **Commit dotfiles alias fix** (file 9) — **already landed**: `aliases.zsh` has no `grep=`/`find=` alias or function (ground-truth 2026-07-24, working tree clean). Only `cat='bat'` remains.

## Open (still needing action)

- **C9 / SB-028 (KEYSTONE)** — global `~/.claude/CLAUDE.md` still doesn't point to `docs/agents/habits.md`; every habits.md addition (SB-023, SB-040, SB-047, SB-050, SB-056) only helps `~/dotdev` sessions until this lands. Now 2 sessions of evidence (SB-028 origin + SB-036 recurrence).
- **C19 / SB-045**, **C20 / SB-046 (+SB-039, SB-044)**, **C21 / SB-047**, **C22 / SB-048**, **C23 / SB-049** — the 3× and 2× cross-session clusters new this harvest; all dispatchable to canonical skills.
- **C24 / SB-050**, **C25 / SB-051**, **C26 / SB-052**, **C28 / SB-054**, **C29 / SB-055** — 2×/high-leverage, dispatchable.
- **Lower / cheap**: SB-023, SB-024 (C8), SB-030 (C11), SB-031 (C12), SB-034 (C14), SB-040 (C16), SB-053 (C27), SB-056 (C9 consolidation).
- **Deferred**: SB-017 (C6), SB-058/059/060 (extractions), SB-061 (taskflow gate migration).

## Dispatched this run (2026-07-24 — Top 5 approved, delegated to workflow-skill)

**All four MERGED to `main` 2026-07-24** (admin-override past a pre-existing repo-wide `pre-commit --all-files` lint floor that is red on `main` independent of this work — see note below). Codex mirror ran post-merge (`workflow-finalize` + `receive-review` verified identical in `~/.codex/skills`). Worktrees + branches cleaned up.

| id(s) | cluster | owner file | PR | commit | status | notes |
|-------|---------|-----------|----|--------|--------|-------|
| SB-028 (+SB-036) | C9 (KEYSTONE) | `dotfiles/.claude/CLAUDE.md` (global) | **#100** (own PR); dup on #96 | `7ea63a4` (cherry-pick of `0d64cf4`) | merged | ✅ **Extracted 2026-07-24** to standalone PR #100 off `origin/main` so it merges independently. Identical copy still on #96 → becomes a no-op when #96 rebases on main (no force-push needed). |
| SB-047 + SB-023 + SB-050 | C21 / C8 / C24 | `docs/agents/habits.md` | **#97** | `f521305` | merged | Clean own-PR off `origin/main` (6→8 bullets, no sprawl). Docs file → no Codex mirror. Agent dogfooded SB-050 (hit gh auth-flip live). |
| SB-045 | C19 | `workflow-finalize/SKILL.md` (Step 6 — where workflow-build-one's finalize gate actually lives) | **#98** (draft) | `ca9b88f` | merged | Advisor-reviewed: directory-scope clause limited to lint/format, not type-check. **Codex mirror pending merge.** |
| SB-046 (+SB-039, SB-044) + SB-049 | C20 / C23 | `workflow-finalize/SKILL.md` + `receive-review/SKILL.md` | **#99** | `e0a2c7e` | merged | Advisor caught a per-PR deadlock in the fan-out gate (one blocked PR would have gated all) — fixed pre-commit. **Codex mirror pending merge.** |

**Cross-PR hygiene flags for the human merge:**

1. **#98 and #99 both edit `workflow-finalize/SKILL.md`** (different sections: Step 6 verification gate vs Step 2/Completion PR-state+fan-out). Independent branches off `origin/main` → whichever merges second needs a rebase. No hard conflict expected.
2. ~~**#96 commingling**~~ — **resolved 2026-07-24**: SB-028 extracted to standalone PR #100 (`7ea63a4`) off `origin/main`; merges independently. The identical copy still on #96 no-ops when #96 rebases (no force-push). Keystone reachable as soon as #100 merges.
3. **Codex mirror** — `~/dotdev/dotfiles/.config/agents/skills/sync-codex-skills.sh --apply` must run from the primary checkout **after** #98 and #99 merge, to mirror the skill edits into `~/.codex/skills`. Deferred by design (running pre-merge would mirror unreviewed content).

## Not dispatched this run (still open / deferred)

- **Held from the ranked queue (deliberate):** SB-048 (C22 advisory-gate self-check — structural, deserves a standalone pass), SB-054 (C28 arch human-gate distinction — high-leverage but a singleton; do deliberately or on recurrence).
- **Lower-priority dispatchable (leave open):** SB-055 (C29 model-floor), SB-052 (C26 herdr docs), SB-051 (C25 worktree path-check), SB-024 (C8 hard-report), SB-030 (C11 grill shape), SB-056 (C9 habits consolidation — rides SB-028), SB-031/034/040/053.
- **Deferred (no action):** SB-017, SB-058, SB-059, SB-060, SB-061.

***DONE 2026-07-24:** #97/#98/#99/#100 merged to `main` (admin-override); SB-023/028/039/044/045/046/047/049/050 → `implemented`; Codex mirror applied for #98/#99 skill edits; worktrees/branches cleaned. #96 (user's arch PR) still carries a redundant copy of the keystone that no-ops when it rebases on `main`.*

***DONE 2026-07-28:** All 10 harvest PRs **merged** to `main` → the following SB rows are `implemented`: SB-064/065/066/067/068/069/071/072/073/074/075/076/077/078/079/080/081/082/083/084/085/086/087/088/089/096 (clusters C30–C41 minus deferred C39). Delivery: #114 greened the chronic CI Lint floor (FIND-29 — committed accumulated autofixes, excluded generated `openwiki/` from markdownlint, fixed shellcheck/MD025/MD046, regenerated stale `.secrets.baseline`) and was merged first; then #105 (taxonomy keystone) merged, then #104/#106/#107/#108/#109/#110/#111/#112/#113 (all CI-green; the 9 out-of-date-after-#105 merged via `--admin`, disjoint files). Codex mirror re-applied post-merge from merged `main` (apply=1, 91 skills + 9 docs) — supersedes the 2 pre-merge mirror runs. **Still open:** FIND-09 (a real OpenSSH private key in git history at `449613f:dotfiles/config/ollama/id_ed25519`, repo public) — needs a history rewrite (BFG/filter-repo) + key rotation, separate from lint. C39/SB-095 (OpenBao/Pergamon) remains out-of-pipeline (build in the Pergamon repo).*
