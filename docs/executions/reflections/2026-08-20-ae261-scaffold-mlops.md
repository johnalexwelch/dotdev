# Session Reflection: AE-261 Scaffold Generator & MLOps Workflow

**Date**: 2026-08-20
**Goal**: Implement AE-261 scaffold generator, convert crm_district_ml_score to new structure, verify training parity

## What Went Well

- **Handoff continuity**: Resumed cleanly from handoff file, all context recovered
- **Research-backed decisions**: Per-model venv + Cookiecutter DS structure — user approved immediately
- **Verification discipline**: Ran both old and new train.py, compared output line-by-line (cv_auc=0.753 exact match)
- **Tiered G2 gate worked as designed**: Blocked training when data was insufficient for tier, provided clear error
- **Linear MCP integration**: Updated AE-261 → Done smoothly (once correct tool params found)

## What Went Wrong / Friction

1. **Cookiecutter template lint false positives**: Started with Jinja2 templates, abandoned after lint chaos — wasted ~10min
2. **Scaffold overwrote production code**: `scaffold_model.py` wrote to existing model dir, nuking real train.py — user had to remind to restore from git
3. **API assumption**: Used `register_model(clf, family, tags={...})` — delphi_mlflow doesn't accept `tags` kwarg
4. **MLflow database split**: Training wrote to `models/crm_district_ml_score/mlflow.db`, but UI defaulted to repo-root `mlflow.db` — user saw wrong experiment
5. **Interactive CLI piping**: `mlflow agent setup` required 5 sequential prompts, each discovered by failure

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|-------------------------|------------|-------------------|
| 1 | "did you use old-train?" | Didn't clarify which mlflow.db contained the new run | workflow-deliver (verify step) |
| 2 | "standard" (tier change) | Initial tier=critical required 10K rows; only 1149 available | scaffold_model.py defaults |
| 3 | "also compare to existing output" | Started verifying only after user prompted | workflow-deliver (verify step) |

## Lessons

1. **Scaffold generators need --dry-run by default**: Overwriting production code without preview is dangerous. The scaffold script has `--dry-run` but it wasn't the default. Scaffold ops should be preview-first.

2. **MLflow tracking URI locality**: When a model has its own venv + pyproject.toml, MLflow defaults to a local `mlflow.db` in cwd. The repo-root db is separate. This split is intentional but needs documentation in the scaffold README.

3. **API surface verification before use**: `register_model(tags=...)` was assumed to exist. Should have checked delphi_mlflow's signature first, especially for internal packages.

4. **Interactive CLI automation**: When piping to interactive CLIs, collect all prompts upfront (inspect help/docs), don't iterate through failures.

## Proposed Improvements

- [ ] `scripts/scaffold_model.py` — Add `--dry-run` as default, require `--apply` to write (priority: high)
- [ ] `models/<family>/README.md` (template) — Document that MLflow tracking is local to the model directory by default (priority: med)
- [ ] `docs/ae-261-scaffold-generator-spec.md` — Update to reflect Python script impl (not cookiecutter template), document tier selection guidance (priority: med)

## Skill Extraction Candidates

- **Proposed skill**: `mlops-model-migration` · **target**: `~/.claude/skills/mlops-model-migration/` · **invocation**: model
  - **Trigger / leading word**: "migrate model to scaffold", "convert to new structure", "backfill model"
  - **Inputs**: existing model directory, target tier, target structure
  - **Steps**:
    1. Snapshot existing train.py business logic (queries, features, hyperparams)
    2. Generate scaffold structure with `--dry-run` preview
    3. Merge business logic into generated structure
    4. Run training, compare output metrics to baseline
    5. Commit with conventional commit message
  - **Success criteria**: Training output matches baseline metrics; G2/G4 gates pass
  - **Constraints / pitfalls**: Never overwrite without backup; always run comparison before declaring done
  - **Verification evidence**: cv_auc=0.753 matched exactly between old and new train.py
  - **Quality gate**: googleable=No · specific=Yes · real-effort=Yes
  - **Open questions**: Should scaffold preserve original train.py as train.py.bak?
