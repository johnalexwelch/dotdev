---
name: skill-evaluator
model: sonnet
reasoning: high
description: 'Produce an evidence-backed verdict on whether a finished skill actually works, picking the method that fits the skill type — pressure battery, quantitative output evals, trigger-accuracy eval, or blind A/B. Use when asked to evaluate, benchmark, pressure-test, or A/B a skill, or to check whether a skill edit helped.'
codex-compatible: true
---

# Skill Evaluator

Judge a *built* skill against evidence, not vibes. The unit of measurement is the **delta**: what the agent does with the skill versus without it (or version B versus A). A run with no baseline proves nothing.

This is the on-a-finished-artifact counterpart to `write-a-skill/references/testing.md` (which verifies wording *while drafting*). Reach here to certify a skill after it exists, or to settle "did that edit help?".

## Contract

Consumes: a target skill (path), optional prior version for comparison, the model id powering the session
Produces: a verdict report — method, evidence, compliance/pass rate, delta vs baseline, recommendation
Requires: subagents (for parallel runs); `claude` CLI only for the heavy skill-creator tooling below
Side effects: writes run artifacts under a workspace dir; never edits the skill under test
Human gates: none (read-only judgment) — implementation stays with `write-a-skill`

## Context

Typical workflows: called by `workflow-skill` as an implementation gate; standalone when the user asks "is this skill any good?"
Pairs well with: write-a-skill (implements the fix), skill-backlog (queues what to evaluate)

## Method selector

Pick by skill type — forcing the wrong method wastes runs and misleads:

| Skill type | Method | Verdict metric |
|---|---|---|
| Discipline / behavior-shaping (rules the agent skips under pressure) | Pressure battery | Compliance rate under combined pressure |
| Output-deterministic (transform, extract, generate, fixed steps) | Quantitative evals | Assertion pass rate + token/time delta |
| Model-invoked with trigger doubt (fires too much / too little) | Trigger-accuracy eval | Correct-fire rate on should / should-not sets |
| Two versions to compare | Blind A/B | Independent-judge win rate + why |
| Subjective (writing, design, judgment) | Structured human review | Qualitative; **don't** fabricate metrics |

## Pressure battery (discipline skills)

Beyond the wording micro-test in `write-a-skill/references/testing.md` — this is the scaled version.

1. Write 3+ scenarios that combine pressures (time + sunk cost + authority + exhaustion).
2. Run each with and without the skill, fresh subagent per run, 5+ reps.
3. Score compliance by reading transcripts (not keyword counts — quoted counter-examples masquerade as hits).
4. New rationalization in the with-skill runs → hand it to `write-a-skill` to close, then re-run. Verdict is bulletproof when compliance holds across all pressures.

## Quantitative evals (output-deterministic skills)

1. 2-3 realistic task prompts → run each with-skill and baseline (no skill), same prompt, parallel subagents.
2. Grade outputs against named, objectively-checkable assertions (script the check when possible; reuse across iterations).
3. Report pass rate, tokens, duration as mean ± stddev with the delta. A skill that doesn't beat baseline on the delta isn't earning its load.

## Trigger-accuracy eval (model-invoked skills)

1. Build ~20 queries: 8-10 should-trigger (vary phrasing; include cases that don't name the skill) + 8-10 **near-miss** should-not (share keywords, need something else). Avoid obvious negatives — they test nothing.
2. Run each 3× at the session's real model; record trigger rate.
3. Substantive multi-step queries trigger skills; trivial one-step queries won't regardless of description — so weak triggers on simple prompts aren't a description defect.
4. Feed failures to `write-a-skill` as description edits, keyed to the near-misses that misfired.

## Blind A/B (version comparison)

Give both outputs to an independent judge subagent **without labels**, let it pick the better, then analyze why the winner won. Removes ordering and authorship bias. Use when the user asks "is the new version actually better?".

## Heavy tooling (Claude Code only)

The official `skill-creator` plugin ships the automated harness — eval-viewer HTML, `run_loop.py` description optimizer (60/40 train/test, picks best by held-out score), benchmark aggregation, `.skill` packaging. On Claude Code, prefer that harness for large eval sets; elsewhere run the portable subagent versions above. Point to it; don't reimplement it.

## Verdict report

```markdown
# Skill Verdict: <skill-name>
- Method: <pressure|quant|trigger|blind-ab|human-review>
- Baseline: <no-skill | prior version | n/a>
- Result: <compliance/pass rate ± stddev>  ·  Delta: <vs baseline>
- Evidence: <transcript quotes / assertion results / trigger table>
- Recommendation: ship | revise (specific gap) | reject | needs-more-evidence
```
