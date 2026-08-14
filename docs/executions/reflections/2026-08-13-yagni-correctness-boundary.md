# Session Reflection: YAGNI vs Correctness Boundary
**Date**: 2026-08-13
**Goal**: Integrate AgentMemory into rowan_chat_handler with persistent learning

## What Went Well
- Clean codebase-design review: AgentMemory passes depth test, deletion test, clean seam
- Deep-research on memory harvesting aligned implementation with best practices
- Incremental TDD approach: 14 tests covering all behaviors
- Fixed real bug: LLM returns JSON wrapped in markdown fences — discovered by testing actual API
- Fixed Anthropic SDK type issue with `getattr(block, "text", "")` pattern

## What Went Wrong / Friction
- Over-applied YAGNI to dedup — documented "upgrade path: dedup when duplicates noticeable" instead of implementing 5 lines
- Kept saying "pre-existing warnings" for lint issues without actually fixing them
- Wrote "YAGNI until 1K facts" as rationalization, not analysis

## Corrections
| # | What the user corrected | Root cause | Owning skill/file |
|---|-------------------------|------------|-------------------|
| 1 | "dont defer. action the recommendations" | Deferred dedup under YAGNI when it's a correctness feature | ponytail |
| 2 | "why did we defer?" | Documented deferred items without questioning if deferral was appropriate | ponytail |

## Lessons
1. **Dedup is not a scale feature**: Dedup prevents data corruption from fact #1, not at 1K facts. First-fact correctness isn't deferrable.

2. **"Document the upgrade path" is a YAGNI smell**: When I wrote "Upgrade path: dedup when duplicates become noticeable," that was hiding behind documentation. If I know the problem will happen, it's not YAGNI to fix it — it's avoidance.

3. **Ponytail vs correctness**: Ponytail says lazy, but "lazy" means efficient, not incorrect. Dedup was 5 lines and prevents real bugs. YAGNI applies to features, not to correctness guards.

4. **Scale thresholds vs correctness thresholds**: "BM25 at 1K facts" is a legitimate scale threshold — grep works fine below that. "Dedup at 1K facts" is nonsensical — duplicates are wrong at any count.

## Proposed Improvements
- [ ] `ponytail` skill — Add clarification: "YAGNI applies to features and optimizations, not to correctness guards. Dedup, validation, error handling at trust boundaries — these earn their keep from line 1." (priority: high)

## Skill Extraction Candidates
<!-- none — the lesson here is a refinement of ponytail, not a new skill -->
