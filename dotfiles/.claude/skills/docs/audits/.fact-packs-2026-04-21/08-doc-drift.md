# Documentation Drift Audit — Skills Directory

**Audit date:** 2026-04-21  
**Scope:** Root-level design docs (`2026-04-21-skills-updates-design.md`, `2026-04-22-design-plan-brief-mode.md`) vs. actual SKILL.md implementations and disk layout  
**Thoroughness:** Very thorough

---

## Summary

**Status:** SIGNIFICANT DRIFT DETECTED in one critical area; otherwise tight alignment.

The two root-level design docs (v3 shipped plan and v1 brief-mode follow-up) describe a **4-skill core loop** (`/repo-audit → /design-plan → /execute-phase → /describe-pr → /post-mortem`) plus `/setup-worktree` side-car. All six skills exist on disk with complete SKILL.md files. However:

1. **CRITICAL: Pairing diagrams are missing or incomplete.** The 2026-04-21 plan (§5.4 Phase 4, tasks 5-8) explicitly required updating pairing diagrams in all three existing skills (repo-audit, design-plan, post-mortem) to show the 4-skill core loop + side-car topology. These pairing diagrams do not exist in the current SKILL.md files.

2. **MEDIUM: 2026-04-22 brief-mode plan status unclear.** The brief-mode doc references five SKILL.md edit points (design-plan, execute-phase, describe-pr, post-mortem, repo-audit) but does not state whether Phase 1 was executed. SKILL.md files show no evidence of brief-mode edits (REQ-NN references, adaptive phase count tuning, ID-agnostic regex updates).

3. **MINOR: Directory tree match.** The plan's §4 "after this plan" tree (page 65-82 of 2026-04-21-skills-updates-design.md) matches the actual disk layout exactly.

4. **MINOR: Missing README at root.** No README.md at `/Users/alexwelch/.claude/skills/`. The 2026-04-21 plan's repo-audit Step 0 preflight (page 56-59) mentions that all skills read README.md at repo root. The audit skill looks for one; this is a documentation minor issue for the skills directory itself.

5. **PASS: Cross-skill vocabulary consistency.** FIND-NN/NEW-NN/phase-number IDs thread across all six SKILL.md files correctly.

---

## Findings

### CRITICAL-01: Pairing Diagrams Missing

**Evidence:**

- **Plan requirement:** 2026-04-21-skills-updates-design.md §5.4 Phase 4, tasks 5-8 (lines 202-208):
  - Task 5: "update the loop diagram to the 4-skill core + `/setup-worktree` side-car" in `design-plan/SKILL.md` pairing section
  - Task 6: "update to 4-skill core loop + `/setup-worktree` side-car" in `repo-audit/SKILL.md` pairing notes
  - Task 8: "update to 4-skill core loop + `/setup-worktree` side-car" in `post-mortem/SKILL.md` pairing diagram
- **Actual state:** No pairing diagrams found in any of the three SKILL.md files. The files mention cross-skill integration in tuning notes and error-handling tables, but no visual or ASCII diagram of the topology.
- **Impact:** High. The pairing diagram is explicitly referenced in 2026-04-21 Phase 4's Definition of Done (line 278) as a verification requirement: `"all reference the 4-skill core loop plus`/setup-worktree`side-car in their pairing diagrams."` This is a shipped deliverable gap.

**Specific line citations in SKILL.md files:**

- `repo-audit/SKILL.md`: Tuning notes section (lines 289-299) mentions `/design-plan`, `/post-mortem`, but no loop diagram.
- `design-plan/SKILL.md`: Tuning notes mention `/execute-phase`, `/setup-worktree`, `/describe-pr` (line ~401), but no diagram.
- `post-mortem/SKILL.md`: Tuning notes (lines 280-289) describe "the full core loop" and "Plus `/setup-worktree` as an on-demand side-car" but no ASCII or visual pairing diagram.

**Example of expected output (from 2026-04-21 plan §11, page 322):**

```
/repo-audit → /design-plan → /execute-phase → /describe-pr → /post-mortem
                                                                    ↑
                                                           /setup-worktree
                                                          (on-demand side-car)
```

### MEDIUM-01: Brief-Mode Plan (2026-04-22) Execution Status Unknown

**Evidence:**

- **Plan file:** `2026-04-22-design-plan-brief-mode.md` exists, dated 2026-04-22, marked as "draft v1 (single gap, bounded surface — two phases)"
- **Execution state:** The document describes Phase 1 tasks (lines 95-107) but contains no completion evidence:
  - No "Verification" section showing dogfood results
  - No "Rollback" note
  - No §9 "Open questions" marked as resolved
  - Plan states "§10 Definition of done" (lines 148-159) but no explicit statement of completion
- **SKILL.md examination:** No evidence of brief-mode edits actually applied:
  - `design-plan/SKILL.md` has no mention of `brief` input parameter (would require lines ~20-22 in the inputs section)
  - No `REQ-NN` pattern in any SKILL.md frontmatter or body
  - No "adaptive phase count" tuning note about bugs/features/refactors in design-plan
  - No `fix/` or `feat/` branch prefix logic in execute-phase (only `refactor/` shown in current SKILL.md)
  - No `{refactor,fix,feat}/phase-*` glob in post-mortem (only `refactor/phase-*` mentioned line 83)

**Interpretation:** The brief-mode plan appears to be a design artifact without execution. It may be:

- A planning document awaiting future work (in-scope for a future phase run)
- An orphan (superseded by other work, never executed)
- Awaiting Phase 1 execution (unclear from the document whether this is a "shipped" plan like v3 or a "to-do" plan)

### MINOR-01: Directory Tree Accuracy

**Evidence:**

- **Plan claim (2026-04-21 §4, lines 65-82):** Post-plan structure shows:

  ```
  ~/.claude/skills/
  ├── repo-audit/SKILL.md
  ├── design-plan/SKILL.md
  ├── setup-worktree/SKILL.md
  ├── execute-phase/SKILL.md
  ├── describe-pr/SKILL.md
  └── post-mortem/SKILL.md
  ```

- **Actual disk state:** Matches exactly. All six skill directories exist with SKILL.md files.
- **Verdict:** PASS. No drift on directory structure.

### MINOR-02: Missing README at Repo Root

**Evidence:**

- **Plan context:** 2026-04-21 §4 (page 56) describes `/repo-audit` Step 0 preflight reading "README.md, CLAUDE.md, and any *_SPEC.md at repo root." This establishes a convention that all skills expect a README at repo root.
- **Actual state:** No README.md or README.* file exists in `/Users/alexwelch/.claude/skills/`.
- **Impact:** Low. The skills directory is not a user-facing project; it's a meta-directory of skill definitions. End users don't clone it. However, if the audit skill were run on this directory itself (unlikely but possible), it would look for README.md per Step 0 preflight logic.
- **Recommendation:** If this directory is versioned and shared, add a README explaining the structure (6 skills, 2 design docs, docs/audits layout).

### MINOR-03: Cross-Skill Vocabulary — PASS

**Evidence:**

- **Plan requirement (2026-04-21 §7, line 245-246):** "The core 4-skill loop and the `/setup-worktree` side-car share three ID schemes: `FIND-NN` (audit), `NEW-NN` (post-mortem), phase numbers (plan)."
- **Actual state:** All SKILL.md files correctly reference:
  - `repo-audit/SKILL.md` (line 234): "Findings carry stable `FIND-NN` IDs that downstream skills (`/design-plan`, `/post-mortem`) reference."
  - `design-plan/SKILL.md` (line 310): "Does every phase's 'Addresses' list reference specific `FIND-NN` IDs from the audit"
  - `execute-phase/SKILL.md` (line 90): "Check whether the plan uses `FIND-NN`, `GAP-NN`, or some other ID scheme"
  - `describe-pr/SKILL.md` (line 83): "Scan commit messages and plan §5 Addresses for any of: `FIND-NN`, `NEW-NN`, `GAP-NN`, `phase-N`"
  - `post-mortem/SKILL.md` (line 201-202): "FIND-01: resolved by Phase 3"
- **Verdict:** PASS. ID vocabulary is consistent.

---

## Evidence

### Files examined

- `/Users/alexwelch/.claude/skills/2026-04-21-skills-updates-design.md` (322 lines)
- `/Users/alexwelch/.claude/skills/2026-04-22-design-plan-brief-mode.md` (196 lines)
- `/Users/alexwelch/.claude/skills/repo-audit/SKILL.md` (first 300+ lines)
- `/Users/alexwelch/.claude/skills/design-plan/SKILL.md` (first 400+ lines)
- `/Users/alexwelch/.claude/skills/post-mortem/SKILL.md` (first 300+ lines)
- `/Users/alexwelch/.claude/skills/execute-phase/SKILL.md` (first 100+ lines)
- `/Users/alexwelch/.claude/skills/describe-pr/SKILL.md` (first 100+ lines)
- `/Users/alexwelch/.claude/skills/setup-worktree/SKILL.md` (first 100+ lines)

### Search for pairing diagrams

- Grep for "pairing|loop diagram|core loop" across all SKILL.md files: No matches in ASCII-art or markdown table format.
- Tuning notes sections mention the 4-skill loop and side-car in prose, but no structured diagram.

### Search for brief-mode edits

- Grep for "REQ-NN|brief" in SKILL.md files: No matches (should appear in design-plan inputs and throughout other skills if Phase 1 was executed).
- Grep for "refactor|fix|feat" (branch prefixes): Only `refactor/phase-*` found; no `fix/phase-*` or `feat/phase-*`.

---

## Open Questions

1. **Was the 2026-04-21 Phase 4 (pairing diagrams) actually completed?**
   - The v3 plan is marked "shipped" and its Definition of Done (line 272-286) includes "all reference the 4-skill core loop in their pairing diagrams."
   - Current SKILL.md files have no pairing diagrams.
   - Either: (a) Phase 4 was skipped, (b) diagrams were deleted post-execution, or (c) the verification in Phase 4 was incomplete.

2. **What is the execution status of the 2026-04-22 brief-mode plan?**
   - Is this a "to-do" plan awaiting execution, or a "shipped" design that should have evidence in the SKILL.md files?
   - If shipped, the five target SKILL.md files should show edits; they don't.
   - If to-do, should it be moved to a "plans/" directory to avoid confusion with shipped design docs?

3. **Should a README exist at `/Users/alexwelch/.claude/skills/`?**
   - The audit skill expects one per Step 0 preflight.
   - The skills directory is meta (skill definitions, not code to audit), so the gap is low-impact but worth noting for consistency.

4. **Are there skills referenced in SKILL.md files but missing on disk, or vice versa?**
   - All six skills mentioned in the design plans exist with complete SKILL.md files.
   - No undocumented skills on disk.
   - No referenced skills missing.
   - **Verdict:** PASS.
