# Corpus Optimization Audit — Evidence Base for Prune / Consolidate / Sharpen

**Date:** 2026-08-18 · **Status:** UNCOMMITTED DRAFT — Alex reviews before this enters the repo through a proper run
**Scope:** READ-ONLY audit. No mutations, no commits, no retirements executed.
**Inputs:** `~/.claude/logs/skill-invocations.log` · `_docs/decision-log.md` D-006 (+addenda) · `_docs/AUDIT_REPORT.md` · `docs/executions/skill-backlog.md` · six SKILL.mds (both deferred overlap groups) · `workflow-router/SKILL.md` + `references/golden-routes.yaml` · reflections corpus · frontmatter sweep of all 99 corpus skills
**Governing rule (2026-06-21 restore incident, AUDIT_REPORT.md:52-59):** never prune on absence-of-reference alone — require invocation history AND replacement coverage AND explicit approval per batch, with a rollback path.

---

## Headline numbers

- **99 skills** in the corpus (`dotfiles/.config/agents/skills/*/SKILL.md`, incl. the deprecated `brain-ops` and the new `workflow-ledger`).
- **Log span: ~29 days** (2026-07-20 11:49 → 2026-08-18 15:16). 100 entries: 86 usable, 14 blank.
- **21 corpus skills** appear in the log (~59 invocations); **14 non-corpus** skills (plugins/repo-local) account for the other ~27.
- **78 corpus skills have zero log entries — but the log is structurally blind to at least half of them**, and there are **four proven false-negatives** (skills with zero log entries and hard on-disk evidence of heavy use — see caveats).
- **Prune candidates surviving all three tests: exactly 1** (`brain-ops`).
- **Consolidation verdicts: 0 merges.** Both deferred overlap groups → sharpen-boundaries / leave. Product-planning trio → none redundant.
- **Extraction verdicts: build 2** (airflow-failure-rca, external-tool-compatibility), **build-cheap 1** (setup-mcp-server), **defer 2** (pivot-assessment, reconcile-git-remotes), **already-closed 1** (herdr-auto-naming).
- **Sharpen: 5 worst description offenders** identified against golden-routes adversarial cases + the Phase 1 (PR #161) fix patterns.
- **Batch plan: 7 one-PR batches** (3 mechanical, 4 grill-needed).

---

## 1. Usage table

### 1.1 What the log can and cannot see (read this before the table)

The log records Skill-tool invocations in interactive Claude Code sessions only. Three structural blind spots:

1. **Chain-internal path-loads do not log.** Orchestrators invoke sub-skills via "Load and run `<skill>/SKILL.md`" (e.g. `v1-workflow` Steps 1/5/6/7 load grill-with-docs, workflow-roadmap, to-prd, to-issues by path; `deep-dive-review` Step 4 chains eight skills). None of these produce log lines.
2. **AFK/Codex runs do not log.** The entire `run-backlog`/Codex mirror lane (`~/.codex/skills`) is invisible.
3. **~29 days only.** Seasonal/monthly skills (e.g. `okr-generator`, `incident-retro`) may legitimately show zero.

**Proven false-negatives (zero log entries, hard evidence of use):**

- `session-insight` — zero log entries, yet **20 reflections dated 2026-08-04 → 2026-08-17** exist in `docs/executions/reflections/` (its output artifact).
- `workflow-finalize` / `receive-review` / `cleanup-delivery` — zero log entries, yet PRs #97–#113 were delivered through them per `docs/executions/skill-backlog.md` (dispatch tables, 2026-07-24 and 2026-07-28 runs).
- `deep-dive-review` — zero log entries, yet its ledger `~/.deep-dive/iris.md` exists on disk.
- `triage`/`reconcile-issues` — zero log entries, yet the backlog records merged triage batches (SB-084/086 dispatch, PR #112).

**Conclusion the data forces:** zero-in-log is meaningful ONLY for user-facing-standalone skills whose natural invocation is a user typing a request in an interactive Claude session. For every other class it is noise.

### 1.2 Class definitions and log visibility

| Class | Definition (frontmatter/router evidence) | Log can see? |
|---|---|---|
| user-facing-standalone | Model-invocable, ambient in listing; user asks in chat | **Yes** |
| orchestrator | `layer: orchestrator` tag or chain-spine skill (workflow-*, execute-*, to-*, triage, v1-workflow) | Entry invocation only; internal steps invisible |
| chain-internal-library | `user-invocable: false` + `disable-model-invocation: true`: council-scaffolding, graph-first, omc-reference, review-scaffolding, workflow-ledger (5 skills) | **No — structurally blind** |
| catalog-tier | `disable-model-invocation: true` but user-invocable via `/name` (DL-0008); 43 skills carry the flag incl. the 5 libraries → **38 catalog-tier** | `/name` invocations only; path-loads invisible |

### 1.3 Per-skill counts (86 usable entries, prefixes stripped, 14 blanks excluded)

**Corpus skills (21 skills, ~59 invocations):**

| skill | count | last invoked | class |
|---|---|---|---|
| clarity-review | 10 | 2026-08-18 | user-facing-standalone |
| handoff | 9 | 2026-08-07 | user-facing-standalone (also chain-called) |
| humanizer | 8 | 2026-08-16 | user-facing-standalone |
| workflow-router | 5 | 2026-08-18 | orchestrator |
| decision-log | 4 | 2026-07-29 | library-like (visible; producer/consumer contract) |
| grill-with-docs | 4 | 2026-08-17 | judgment (user-facing + chain-called) |
| workflow-skill | 4 | 2026-07-24 | orchestrator |
| to-issues | 2 | 2026-07-31 | orchestrator |
| to-prd | 2 | 2026-07-31 | orchestrator |
| deep-research | 1 | 2026-07-29 | user-facing-standalone |
| design-plan | 1 | 2026-07-20 | user-facing-standalone |
| execute-prd | 1 | 2026-07-31 | orchestrator |
| mlops-engineer | 1 | 2026-08-05 | user-facing-standalone |
| prototype | 1 | 2026-07-29 | user-facing-standalone |
| skill-backlog | 1 | 2026-07-24 | orchestrator |
| skill-evaluator | 1 | 2026-07-30 | user-facing-standalone |
| sql-review | 1 | 2026-07-28 | catalog-tier (`/sql-review`) |
| wayfinder | 1 | 2026-07-29 | catalog-tier / judgment |
| workflow-build-one | 1 | 2026-07-28 | orchestrator |
| workflow-review | 1 | 2026-07-30 | orchestrator |
| write-a-skill | 1 | 2026-07-24 | user-facing-standalone (also chain-called by workflow-skill) |

**Non-corpus (plugins / repo-local / deleted — excluded from all corpus verdicts):** ceo-filter 8, dnd-rumor-table 3, artifact-design 2, morning-prep 2, write-to-obsidian 2, claude-api 1, datadog 1, dataviz 1, impeccable 1, meeting-prep 1, morning 1, sql-standards 1 (repo-local dbt), test-skill 1, toolshed 1.

**Blanks: 14 entries** carry a timestamp and no skill name (clustered 2026-07-21 and 2026-07-27). Cause indeterminable from the log alone — likely a logging-hook bug on some invocation shape. Worth a one-line fix ticket; they cap the confidence of every zero-count claim below.

### 1.4 Zero-logged corpus skills, by what the zero means

- **Structurally invisible (no conclusion possible):** all 5 chain-internal libraries; catalog-tier skills invoked by path (e.g. `decision-memo` from analysis-design, `humanizer-exec` from workflow-executive-doc, `herdr-launch` from setup-worktree, `stage-v1-concept` from grill-with-docs, `codebase-design` from ICA/tdd/domain-modeling); orchestrator-internal steps (`workflow-finalize`, `receive-review`, `cleanup-delivery`, `workflow-roadmap`, `v1-system-design`, `execute-phase`, `run-backlog`, `triage`, `reconcile-issues`, `workflow-debug`, `workflow-feature`, `workflow-autonomous-backlog`).
- **Visible-but-zero, no replacement exists (corrected rule ⇒ NOT prunable):** capture-idea, caveman, dbt-project-evaluator, find-skills, git-worktree-audit, herdr, okr-generator, product-launch-checklist, resolving-merge-conflicts, rowan, session-insight (false-negative — heavily used), skill-system-audit, slack-update, tdd, user-journey-qa, diagnose, improve-codebase-architecture, repo-audit, deep-dive-review (false-negative), workflow-executive-doc.
- **Visible-but-zero WITH a plausible replacement:** see §2.

---

## 2. Prune candidates

Only skills that pass ALL of: (a) log can structurally see them, (b) zero invocations, (c) plausible replacement coverage. Explicit approval per batch still required.

### 2.1 `brain-ops` — formal retirement candidate (HIGH confidence)

- **Evidence:** frontmatter reads `description: "DEPRECATED — use /rowan instead. This skill is retained for reference only."` (brain-ops/SKILL.md:4). PR #149 (2026-08-14) reversed the earlier rowan→brain-ops stubbing; AUDIT_REPORT.md:27 explicitly flags "decide direction (rowan vs brain-ops), then retire the loser." Direction is now decided on disk: rowan carries the live skill body, brain-ops carries the tombstone header.
- **Invocation history:** zero entries for `brain-ops` across the full 29-day span. (`rowan` is also zero-logged, but rowan is user-facing with live references — MEMORY.md project entry, chorus-repo routing split per skill-backlog 2026-08-18 harvest notes — and it is the successor, not the candidate.)
- **Replacement coverage:** `rowan/SKILL.md` (live), which brain-ops's own header names.
- **What would change the verdict:** any brain-ops invocation in a 60-day log window (D-006 Track D precondition); or Alex deciding the archived reference content in brain-ops's body (CLI command surface) is not yet duplicated in rowan — worth one grep before the delete PR.
- **Mechanics:** identical to the D-006 d14 retirement batch — delete dir, atomic catalog updates (router `## Catalog tier` "Knowledge/utility" list at workflow-router/SKILL.md:254 names `brain-ops` and even uses `/brain-ops` as its example; also skills-index, SKILL-MANIFEST, AUDIT_REPORT rows), lint, post-merge Codex mirror.

### 2.2 Flagged but NOT prune candidates (explicitly excluded)

- `stage-v1-concept`, `codebase-design`, `humanizer-exec`, `herdr-launch`, `decision-memo` — zero-logged but chain-internal (each referenced by ≥1 live orchestrator/skill: grill-with-docs, ICA/tdd/domain-modeling, workflow-executive-doc, setup-worktree flow, analysis-design respectively). The log structurally can't see them; corrected rule blocks any verdict.
- `implement` — catalog-tier, zero `/implement` in log, and overlaps workflow-build-one on its face; but `tdd/SKILL.md:130` and `spec-review/SKILL.md:19` reference its self-review step as a live chain component. Not prunable; it is a §5 sharpen candidate instead.
- `zoom-out` — zero-logged, router-only reference; but no replacement exists (SB-115 records pivot-assessment as "adjacent, not covering"). Fails test (c).
- `find-skills` / `humanizer` / `deep-research` **duplication note:** the session skill listing shows plugin variants (`meta-skills:find-skills`, `meta-skills:humanizer`, `meta-skills:deep-research`, `core:humanizer`) alongside corpus copies. Not a corpus prune (the duplicates live in plugins, and meta-skills:deep-research is a different capability — OpenAI API), but a dedup question for the plugin layer; humanizer's 8 invocations don't disambiguate which copy fired.

### 2.3 Honest bottom line

After the 2026-08-18 D-006 d14 retirement (6 stubs already deleted), the corpus has **no backlog of safely prunable skills beyond brain-ops**. The corrected audit rule, applied honestly against a log this blind, protects nearly everything — which is the rule working as designed, not a failure of the audit.

---

## 3. Consolidation dossiers

### 3(a) decision-log vs decision-memo vs design-plan

| | decision-log | decision-memo | design-plan |
|---|---|---|---|
| Artifact | append-only entries in `docs/decision-log.md` (Question/Decision/Alternatives/Tradeoffs) | Pyramid/SCQA executive memo for a named audience | phased execution plan `docs/plans/*-design.md` with FIND-NN/REQ-NN anchors, rollback, sync gates |
| Role | cross-cutting producer/consumer **library** for all grills/workflows | analytics-lane **synthesis step** (after analysis-design/analysis-council), catalog-tier | refactor/migration/governance **planning skill**, explicitly NOT the feature default (its own description routes product work away) |
| Log | 4 invocations | 0 (catalog-tier + chain-internal → blind) | 1 invocation |

**Actual overlap:** nominal, not real. The three produce disjoint artifacts for disjoint readers (future agents / executives / a fresh contributor). The AUDIT_REPORT.md:35 questions are already answered on disk: design-plan *consumes* decision-log (design-plan/SKILL.md reads `docs/decision-log.md`, treats entries as settled rationale, "reopen only when new evidence changes accepted tradeoffs"); decision-memo carries its own routing block (decision-memo/SKILL.md:23-27) disambiguating vs strategic-analysis-review / analysis-council / humanizer.

**Confusion evidence:** none found. Zero reflections mention `decision-memo`; no wrong-tool-pick reflections for this trio; the golden set has no failing case among them. The only genuine weakness is decision-log's *description* (a §5 offender — it leads with "grilling, design, PRD, planning," colliding with four sibling skills' leading words).

**Recommendation: leave (no merge); sharpen decision-log's description only.**

Grill questions for Alex:

- decision-log: *"Now that D-006 gives the ledger checked evidence fields, should decision-log stay prose-library or grow a `ledger.sh`-checked 'decision recorded' field on grill stamps?"* (SB-101 is the deferred kin.)
- decision-memo: *"Has decision-memo ever run outside the analysis-design/analysis-council chain — if not, should it drop to `user-invocable: false` chain-internal like council-scaffolding?"*
- design-plan: *"Does anything still arrive via the `brief` (non-audit) entry, or is repo-audit the only real feeder — and if so should the brief-mode input be cut?"*

### 3(b) repo-audit vs improve-codebase-architecture vs deep-dive-review

| | repo-audit | improve-codebase-architecture (ICA) | deep-dive-review |
|---|---|---|---|
| Question answered | "what IS the state of this repo" (descriptive; guardrail at repo-audit/SKILL.md:34 forbids SHOULD-BE) | "what could be deepened" (prescriptive; depth/seam/deletion-test vocabulary) | "run the daily 4-lens sweep and ship survivors" (scheduled AFK loop) |
| Output | FIND-NN report → feeds roadmap/to-prd/to-issues/design-plan | numbered deepening candidates + grill loop | ranked HTML dashboard + one PR per finding + convergence ledger |
| Relationship | input to planning | **is deep-dive-review's `deepen` lens** (deep-dive-review/SKILL.md:20,44 — "Reuses (does not reinvent)") | composes ICA + ponytail + pi-lens + diagnose + full delivery chain |

**Actual overlap:** hierarchical composition, not duplication. deep-dive-review is a scheduler/driver around ICA (and others); repo-audit sits on a different axis entirely (state vs opportunity).

**Confusion evidence:** the opposite — the seams held under test. `2026-07-29-deep-dive-review-certification.md:9`: "Trigger/routing eval: 32/32 correct across 8 should-fire + 8 keyword-sharing near-misses, 2 cold raters, perfect agreement. The two hardest seams held (proactive-perf vs regression→diagnose; daily-sweep vs single-shot→improve-codebase-architecture)." The routing pressure test (2026-07-29) passed S2 (repo-audit must not skip to execute-phase). The one soft edge is router row 191 ("research" → "repo-audit *or* ICA") — a dual-target row that leaves disambiguation to the model; the golden set covers only the repo-audit side ("Investigate how the auth middleware works" → repo-audit).

**Recommendation: leave (no merge); optional micro-sharpen of router row 191** (one clause: state-question → repo-audit, opportunity-question → ICA) + add one ICA-side golden case.

Grill questions for Alex:

- deep-dive-review: *"It has run exactly once by ledger evidence (`~/.deep-dive/iris.md`) — is the 'daily' loop actually scheduled anywhere, and if not, does it stay a skill or shrink to an ICA invocation mode?"*
- ICA: *"When deep-dive-review is the intended daily driver, should ICA's standalone triggers ('clean up tech debt' adjacency) narrow to deepening-only, ceding sweep language entirely?"*
- repo-audit: *"Its FIND-NN consumers are all planning skills — should repo-audit refuse (or warn on) invocations that don't name a downstream consumer, to stop audit-as-procrastination runs?"*

### 3(c) Quick verdict: product-planning trio (workflow-feature / workflow-roadmap / v1-workflow)

**None redundant.** They occupy three scales the router now sequences explicitly (rows 177-179, 184): v1-workflow is a gated pipeline that *calls* workflow-roadmap as its Step 5 (v1-workflow/SKILL.md:45,143) and resumes mid-pipeline; workflow-roadmap is also a standalone "what should we build next" entry and the roadmap-gate for to-prd/to-issues (router:361-364); workflow-feature is the small-scale sibling (grill → decision-log → to-prd spine, router:334) with a post-V1 handback rule (v1-workflow/SKILL.md:263). Case-39 flakiness in the Phase 1 eval was v1-workflow vs **v1-system-design** (the trap row, fixed in PR #161), not intra-trio. Residual observation, not a recommendation: workflow-feature and v1-workflow share the same spine and differ by two inserted steps — if D-006 #11's parameterized-orchestrator pattern (`workflow-deliver` with `kind:`) proves out, a future `kind: v1|feature` merge is conceivable. Wait for that evidence; don't front-run it.

---

## 4. Extraction-candidate verdicts (skill-backlog SB-097–127, write-a-skill Quality Gate 0)

Gate (write-a-skill/SKILL.md:27-31): not-googleable + specific-to-this-workflow + real-effort, else it's documentation/a command/a one-off. Recurrence per skill-backlog ranking discipline.

| candidate | SB row | verdict | one-line reasoning |
|---|---|---|---|
| **airflow-failure-rca** | SB-103 | **BUILD** | Gate recorded as passed in-row; overturned an 8-item retry-based audit (real stakes); evidence-first triage order is dojo-specific, not googleable — precondition: verify `error_detail` is the dojo listener extension vs generic Airflow at dispatch (open q stands). |
| **external-tool-compatibility** | SB-102 | **BUILD** | occ 2 (both 3MF sessions 08-11), gate recorded googleable=No/specific=Yes/real-effort=Yes; absorbs two workflow checkboxes so it *reduces* corpus sprawl; resolve standalone-vs-build-one-section at the dispatch grill. |
| **setup-mcp-server** | SB-116 | **BUILD (cheap, low rank)** | Gate passes only on the Pi-specificity claim (`~/.pi/agent/mcp.json`, lifecycle, restart note — genuinely not googleable as a unit); recurrence=1 is the weak leg — build small or wait for the 2nd MCP setup; backlog already ranks it "Lower". |
| **pivot-assessment** | SB-115 | **DEFER** | Gate passed but singleton, and the zoom-out overlap is explicitly unresolved ("adjacent, not covering") — the durable slice (SB-113 habits.md inherited-constraint line) ships anyway, which drains most of the value; revisit on 2nd paradigm-pivot. |
| **reconcile-git-remotes** | SB-107 | **DEFER** | Gate passed but D-006 d20's `forge.sh` may absorb the detection half and the force-push policy question is open — extracting before Phase 0 lands means rework; re-gate after forge.sh merges. |
| **herdr-auto-naming** | SB-123 | **CLOSED (no build)** | Already built in-session as pi extension `~/.pi/agent/extensions/herdr-task-naming.ts` — an extension, not a skill; only residual is the SB-120 doc note riding the next herdr edit. |

(SB-097/098/104/109/117 are `accepted`-consumed-by-D-006 — they land via the phase plan, not extraction; SB-125/126/127 are author-rejected non-proposals. No other SB-097–127 rows are skill-extractions.)

---

## 5. Sharpen list — 5 worst description offenders

Cross-referenced against golden-routes.yaml adversarial cases and the Phase 1 (PR #161) fix patterns — the wording classes that actually failed there: missing counter-rules on shared leading words, imperative-verb+skill-name losing to carve-outs, sibling pairs both claiming the same opening noun (sql-review vs dbt-project-evaluator was a live case-26 regression fixed by wording alone).

1. **decision-log** — `"Use when grilling, design, PRD, planning, or implementation workflows need to record or consume accepted decisions…"` Leads with "Use when" + five nouns that are the *leading words of five sibling skills* (grill-with-docs, design-plan, to-prd, workflow-feature, workflow-build-one); zero user trigger phrases; reads orchestrator-facing though it's the corpus's most chain-consumed library. Fix: capability-first sentence ("Records/consumes accepted decisions…"), then concrete triggers ("log this decision", "check the decision log").
2. **implement** — `"Use when the user says 'implement this', 'build this', 'write the code for'…"` Collides head-on with golden case 61 ("…implement it end to end" → workflow-build-one) and the execute-prd rows ("implement all children"); the Phase 1 fix made imperative-verb+skill-name beat carve-outs, which makes this description a standing misfire risk on the Codex side where the catalog lock doesn't protect. Fix: subordinate it explicitly ("chain step inside tdd/spec-review flows; for tracked-repo delivery use workflow-build-one").
3. **mlops-engineer** — `"Warehouse-native MLOps — batch ML pipelines, dbt-based metrics, immutable promotion contracts, no MLflow."` Capability fragment with no "Use when" and no trigger phrases at all — violates write-a-skill:66 directly. It *does* get real use (1 invocation + SB-110 landed `915ab21`), which makes the missing triggers pure downside. Fix: add the trigger sentence ("Use when designing/reviewing ML pipelines, model promotion, or training-serving skew in the warehouse").
4. **sql-review ↔ dbt-project-evaluator** (pair) — both open on reviewing/checking dbt artifacts; case 26 regressed mid-iteration in the Phase 1 eval and was fixed by sharpening *router* wording, but the two descriptions still share leading words ("Reviews a SQL query, view, or dbt model…" / "Checks a dbt project…evaluating changed dbt models…"). Fix: push the query-level vs project-structure split into the descriptions' first sentences so non-router surfaces (Codex, /name pickers) inherit the fix.
5. **v1-system-design ↔ v1-workflow** (pair) — case 39 was flaky ("Design the system architecture for this approved V1 brief" trap) and the router row now carries the do-NOT-route warning (router:177); v1-system-design's description carries a matching guard, but v1-workflow's description ("Use when starting a new V1 product from an idea") doesn't claim the *approved-brief resume* case that the trap actually exercises — the winning skill's description is silent on the winning trigger. Fix: one clause in v1-workflow's description ("also when a V1 brief is already approved — it resumes at the right stage").

(Watchlist, not top-5: `rowan` — invocation-pattern-only description; `deep-dive-review`'s "clean up tech debt"/"simplify"/"optimize" triggers vs ICA — currently held 32/32 under cert eval, so leave until a real misroute adds a golden case; `product-launch-checklist` — fine on inspection, flagged only because the listing renders its folded scalar oddly.)

---

## 6. Recommended batch plan (one PR each, workflow-skill + ledger for all)

Ordered so mechanical wins land first and every judgment change gets its grill. Every batch: golden-routes eval must stay ≥95% (Track B gate); Codex mirror post-merge; per the corrected audit rule, Batches 1 is approval-gated per-item.

| # | batch | contents | tag | gate evidence |
|---|---|---|---|---|
| 1 | **brain-ops formal retirement** | delete dir; atomic catalog updates (router:254 Knowledge/utility list + `/brain-ops` example, skills-index, SKILL-MANIFEST, AUDIT_REPORT row); lint; Codex mirror; pre-delete grep that rowan covers brain-ops's archived CLI surface | **grill-needed** (explicit approval per corrected rule; 60-day log grep attached: zero hits) | §2.1 |
| 2 | **Description sharpen, 5 offenders** | the §5 rewrites; +1 golden case per touched trigger seam (ICA research-side case; v1-workflow approved-brief case) — eval-set additions only, never edits to existing cases | mechanical (wording-only, eval-gated — same shape as PR #161) | §5 |
| 3 | **Router row 191 micro-sharpen** | state-vs-opportunity clause for repo-audit/ICA dual-target row | mechanical | §3(b) |
| 4 | **Decision-trio boundary grill** | the three §3(a) grill questions; likely outcome is decision-memo visibility flag + design-plan brief-mode verdict, no merges | **grill-needed** | §3(a) |
| 5 | **Audit-trio grill** | the three §3(b) questions, centered on "is deep-dive-review actually scheduled?" | **grill-needed** | §3(b) |
| 6 | **Extraction: airflow-failure-rca** | build via workflow-skill; dispatch-time check of `error_detail` generality | **grill-needed** (the open q is a real fork) | §4 |
| 7 | **Extraction: external-tool-compatibility** | build via workflow-skill; standalone-vs-build-one-section resolved at dispatch; absorbs the two workflow checkboxes (net corpus shrink) | **grill-needed** | §4 |

Deferred (record in skill-backlog, no PR): setup-mcp-server (build on 2nd recurrence or as a rider), pivot-assessment (revisit on recurrence; SB-113 ships regardless), reconcile-git-remotes (re-gate after forge.sh). Fix-it ticket, out of band: the **14 blank log lines** — one hook bug caps the confidence of every future usage audit; cheapest instrumentation win available.

---

## Indeterminable — stated honestly

- **True usage of the 43 model-invocation-locked skills and all chain-internal steps.** The log cannot answer; only per-skill artifacts (reflections, ledgers, PR trails) did, and only for four skills.
- **Which copy of duplicated plugin/corpus skills (humanizer, find-skills, deep-research) actually fires** — the log strips prefixes inconsistently and plugins log under bare names.
- **Cause of the 14 blank entries.**
- **Whether decision-memo, zoom-out, i-have-adhd, mock-data-generator, watch-ci, etc. have *any* usage** — no artifact trail found either way; zero-evidence ≠ zero-use, per the restore-incident rule.
- **AFK/Codex-side skill usage entirely.**
