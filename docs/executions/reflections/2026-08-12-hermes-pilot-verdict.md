# Session Reflection: Hermes Pilot Verdict

**Date**: 2026-08-12
**Goal**: Enable agent messaging (Talk surface) — user wanted "process my inbox" with Rowan

## What Went Well

- Quickly identified the real blocker: hermes-pilot verdict was undone, blocking Talk surface
- Ran the rubric interactively with user scoring governance decisions (K2)
- Efficient governance call: "what's your threat model?" → trust-based isolation accepted
- Clean verdict recording (F78) and roadmap updates in one commit
- Handoff skill worked smoothly — both repo and mirror copies created correctly

## What Went Wrong / Friction

- User had to ask "what does our current path look like?" to understand the blocker chain — roadmap didn't make "blocked by X" obvious at a glance
- Shell comments (`#`) caused bash tool errors — had to strip them from commands
- Initial confusion: user wanted Talk, we spent time on Rowan's SOUL.md (legitimate fix) before realizing the deeper blocker

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|-------------------------|------------|-------------------|
| 1 | "inbox" = knowledge inbox, not email | Rowan's SOUL.md didn't disambiguate | `agents/rowan/SOUL.md` |
| 2 | "which do you recommend" (K2 decision) | Agent hesitated on governance call instead of recommending | General agent behavior |

## Lessons

1. **Silent blockers in roadmaps**: A capability can be "in flight" for months without progress if its blocker isn't run. The hermes-pilot rubric existed since July but was never executed — blocking three downstream capabilities.

2. **Governance decisions need recommendations**: When the user asks "which do you recommend?", give a clear recommendation with reasoning. Don't present options and wait — that's abdication, not respect for autonomy.

3. **Bash tool quirks**: The pi bash tool doesn't handle `#` comments well in some contexts. Use `echo "=== SECTION ==="` headers instead of inline comments.

## Proposed Improvements

- [ ] `docs/roadmap.md` — Add a "Blockers" column or visual indicator showing what's actually blocking each "Now" item (priority: med)
- [ ] `chorus` CLI — Add `chorus send <agent> "<msg>"` and `chorus inbox <agent>` for immediate protocol messaging (priority: high — this is what the user actually wanted)
- [ ] General agent behavior — When user asks for a recommendation on a governance/design decision, lead with the recommendation and reasoning, then offer alternatives (priority: low — conversational, not skill-encodable)

## Skill Extraction Candidates

None. The pilot rubric process is already documented in `docs/plans/2026-07-20-hermes-pilot-rubric.md`. The interactive scoring approach worked well but isn't a repeatable skill — it's just "run the rubric with the user."
