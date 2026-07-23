# Session Reflection: Nora meal-plan recipe JSON generation
**Date**: 2026-07-19
**Goal**: Use `nora` to build a weekly dinner meal plan (taco Tuesday, one-pot pasta, salmon, fiber), then persist recipe JSON matching Nora's schema.

## What Went Well
- Checked ground truth before assuming the tool worked: read `.env` and found `ANTHROPIC_API_KEY` unset, and read `cli.py` to confirm `nora` is a fully interactive `asyncio`/streaming agent with `console.input()` prompts — correctly concluded it can't be driven headlessly from bash, instead of pretending to "run" it or faking success.
- Pivoted to a verifiable substitute: read the real `Recipe` pydantic model (`src/nora/models.py`) and an existing example recipe file to match `schema_version: 2` exactly, then wrote 4 recipe JSONs and validated all of them with `Recipe.model_validate(...)` before declaring done. This is the "leave one runnable check" habit applied correctly to a non-code artifact.
- Pulled real family context (`~/.nora/family.json`, `~/.nora/preferences.json`) — mild spice, Mon-Thu only, Emerson's packed-lunch quirks, IP make-ahead — and reflected it in the plan instead of generating generic recipes.

## What Went Wrong / Friction
- User interrupted with "why is this taking so long?" during the exploration phase. Root cause: spent ~4 sequential bash calls (grep argparse, sed ranges of `cli.py`, `_run` internals, `PlannerSession` flow) working out *how* the interactive CLI is structured *before* checking the one fact that made all of that moot — whether `ANTHROPIC_API_KEY` was even set. The blocking check (`.env` has no key → live agent flatly cannot run) should have been the *first* move, not something discovered after exploring call-flow internals.
- One `ls` command was aborted mid-flight (visible in transcript) right before the user's complaint — a symptom of the same over-exploration pattern, not a separate bug.

## Corrections
| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | "why is this taking so long?" | Explored interactive-CLI internals before checking the cheap, decisive blocker (API key present?) | No current skill owns "check cheapest disqualifying fact first when a tool-invocation task turns into exploration" — general agent habit, not nora-specific |

## Lessons
1. **Cheapest disqualifying check first**: When a task hinges on "can this tool actually run", check the fast/cheap gate (env var, credentials, network) before reading deep implementation to understand *how* it would run. Order of investigation matters as much as thoroughness — 4 exploratory reads before the one-line `.env` check wasted turns and visibly cost user patience.
2. **Schema-matching by validation, not eyeballing**: For any hand-authored artifact meant to be read by existing code, find that code's model/parser and run it against the draft before calling it done — cheaper and more trustworthy than manually cross-checking field names/types against an example file.

## Proposed Improvements
- [ ] No specific skill file to edit yet — the friction is a general "fail-fast on external tool viability" heuristic, not owned by any skill in the current inventory. Recommend surfacing as a `habits.md` note rather than a skill edit (per skill's own guidance to prefer `docs/agents/habits.md` for durable agent policy) — awaiting approval below.

## Skill Extraction Candidates
- **Proposed skill**: `nora-recipe-authoring` · **target**: new skill directory (project- or user-scope, TBD) · **invocation**: model (auto-fires when asked to add/edit Nora recipes without a live Claude session)
  - **Trigger / leading word**: "nora", "recipe", "meal plan" combined with Nora's `~/.nora/recipes/` store, especially when the live `nora` CLI can't run (no API key, non-interactive context)
  - **Inputs**: desired dishes/constraints, family profile (`~/.nora/family.json`), preferences (`~/.nora/preferences.json`), existing recipe examples in `~/.nora/recipes/`
  - **Steps**:
    1. Confirm whether live `nora` can run (`ANTHROPIC_API_KEY` set?) — if not, fall back to hand-authoring recipe JSON directly. ✅ done when this is decided before deep CLI exploration.
    2. Read `src/nora/models.py::Recipe` (and `Ingredient`, `NutritionInfo`) for the current schema/field set. ✅ done when field list is confirmed, not assumed from memory.
    3. Read one existing `~/.nora/recipes/*.json` file as a concrete shape reference.
    4. Pull family constraints from `family.json` + `preferences.json` (spice tolerance, days planned, allergies, per-child lunch quirks) and reflect them in ingredients/tags.
    5. Author recipe JSON(s) with a slug `id` matching the filename convention (`slugify_recipe_name` rules: ascii, lowercase, hyphens, spelled-out "and").
    6. Validate every generated file with `Recipe.model_validate(json.load(open(path)))` via `uv run python -c ...` before presenting as done.
  - **Success criteria**: all generated recipe JSON files load through `Recipe.model_validate` with zero errors; recipe reflects stated family constraints (spice/fiber/protein asks) explicitly in tags/ingredients.
  - **Constraints / pitfalls**: `Recipe.name` rejects `<`, `>`, and newlines (XML-injection guard) — keep names plain. `created_at`/`last_used_week` have defaults; don't hand-write `created_at` (model default_factory already produces UTC now — hardcoding it is redundant, not wrong). Nutrition numbers here are model estimates, not USDA-validated — flag that limitation to the user since real `nora` would cross-check via USDA API when configured.
  - **Verification evidence**: this session's `uv run python -c "... Recipe.model_validate(...)"` printed `OK <id> <name>` for all 4 files with zero validation errors.
  - **Quality gate**: googleable=No (schema is project-specific, undocumented in README) · specific=Yes (tied to Nora's exact pydantic model + file conventions) · real-effort=Yes (required reading `models.py`, an example file, and `preferences.json` to get right)
  - **Open questions**: Is this worth a standalone skill, or is it a thin enough procedure to fold into a broader "Nora offline-authoring" note in the project's own `AGENTS.md`/`CONTEXT.md` instead of the global skills library? Given it's fully specific to one repo (`nora`), a project-local doc (`docs/` in this repo) may be the better home than a global skill — flagging both options for user's call.
