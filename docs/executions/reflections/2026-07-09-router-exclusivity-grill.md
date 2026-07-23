# Session Reflection: router-exclusivity grill (#71)

**Date**: 2026-07-09
**Goal**: Resume `/wayfinder` work-mode, resolve one frontier ticket — #71 (which internal skills get `disable-model-invocation`).

## What Went Well

- **Verified the enabling mechanic before theorizing.** Grepped `workflow-finalize` and found "Load and execute `describe-pr/SKILL.md`" — proved locking a sub-step breaks nothing (parents load by path). This dissolved the budget-vs-integrity tension instead of guessing at it.
- **Held the HITL line.** One question at a time; never answered the user's side of the decision. Offered a reasoned opinion only when explicitly asked.
- **Complete accounting.** 85 skills → 39 open / 46 locked, every skill tagged, math closed before writing the resolution.
- **Full resolution ritual** in one pass: comment → close → map Decisions-so-far → decision-log mirror → handoff, all pushed.

## What Went Wrong / Friction

- Two of the three user turns were the user *pulling* out of me something I should have offered first (an opinion; the recovery story). Successful, but clumsy — the grill made the user do work the grill should do.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | "id like your opinion on the others" (after I posed a bare binary on the gray-zone skills) | On an expert-judgment call I asked *which do you want* instead of *here's my recommendation, react* | `grill-with-docs` |
| 2 | "what happens if the process fails... and I need to restart a section" | I proposed locking/gating without proactively covering recovery/escape hatches; user had to surface the risk | `grill-with-docs` |
| 3 | "so is the play that i will always start with the router" | User reconstructing the day-to-day feel I hadn't spelled out | `grill-with-docs` |

## Lessons

1. **Recommend, don't just ask, on expert-judgment questions.** Pure-preference questions ("humanizer open?") take a bare question. Judgment questions (where the human lacks the evidence to answer cold) should ship a reasoned default *with* the open question, so the human reacts instead of researches. All three corrections are the same shape: I withheld synthesis the user then had to request.
2. **When grilling a decision to restrict/gate/lock, lead with the recovery story.** "What breaks / how do I undo / how do I restart" is a predictable objection to any gating decision — surface it before the human does.

## Proposed Improvements

- [ ] `dotfiles/.claude/skills/grill-with-docs/SKILL.md` — add one rule: on expert-judgment questions (human lacks evidence to answer cold), present a reasoned recommendation *alongside* the open question; reserve bare questions for pure-preference calls. (priority: med)
- [ ] `dotfiles/.claude/skills/grill-with-docs/SKILL.md` — add: when the decision *restricts/gates/locks/removes* a capability, proactively cover the recovery/escape-hatch (what breaks, how to undo, how to restart) before asking the human to commit. (priority: med)

*Both target the narrowest owner (the canonical grill engine); `wayfinder` grilling tickets inherit them. No new skill warranted — this is wording, not a new pattern.*
