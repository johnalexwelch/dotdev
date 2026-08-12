# Session Reflection: 3MF Multi-Color Slicer Compatibility Failure
**Date**: 2026-08-11
**Goal**: Fix export_to_3mf() to produce valid multi-color 3MF for Bambu Studio

## What Went Well
- Eventually diagnosed root cause: Bambu Studio ignores per-triangle/per-object color attributes
- Created diagnosis artifact documenting the finding
- Tried multiple distinct approaches before concluding the format itself doesn't work

## What Went Wrong / Friction
- **5+ hours of implementation before ground-truth validation**: Built multiple export approaches (colorplate, per-triangle colors, separate objects, solid grid) before discovering Bambu Studio doesn't render any of them correctly
- **Proxy over ground-truth**: Tested mesh validity (watertight, degenerate triangles, correct structure) instead of validating in the actual target tool (Bambu Studio) early
- **No upfront research**: Dove into 3MF spec implementation without researching how working multi-color 3MFs (from Bambu/Prusa/commercial tools) are actually structured
- **Late skill adoption**: User had to remind about workflow-debug, tdd, workflow-router multiple times before structured debugging started
- **Ad-hoc iteration**: ~15+ implementation variants, each requiring user testing in Bambu Studio

## Corrections
| # | What the user corrected | Root cause | Owning skill/file |
|---|-------------------------|------------|-------------------|
| 1 | "You're not using the instructed skills" | Defaulted to ad-hoc debugging instead of structured workflow | workflow-router |
| 2 | "Did you follow workflow-debug?" | Started debugging without the skill ledger | workflow-debug |
| 3 | "Please restart properly" | Continued ad-hoc after being reminded | workflow-router |
| 4 | Multiple "still doesn't work" | Testing proxy (mesh validity) instead of ground-truth (slicer render) | (new pattern) |

## Lessons
1. **Research external tool compatibility FIRST**: When building output for a specific tool (Bambu Studio), research how that tool actually interprets the format before implementing. A 10-minute search for "how Bambu Studio handles multi-color 3MF" would have saved 5+ hours.

2. **Ground-truth early, not proxy validation**: "Mesh is watertight" doesn't mean "slicer will render colors correctly." Test the actual user experience (open in target tool) within the first iteration, not after perfecting technical metrics.

3. **Skill discipline under pressure**: When a bug is frustrating, the temptation is to ad-hoc iterate faster. The user had to correct this multiple times. The skills exist to prevent exactly this spiral.

## Proposed Improvements
- [ ] `workflow-debug` — Add step: "For format/tool-compatibility bugs, RESEARCH how the target tool interprets the format before implementing fixes" (priority: high)
- [ ] `workflow-build-one` — Add: "When building for external tool consumption, find a working reference output from that tool and reverse-engineer it first" (priority: high)
- [ ] `docs/agents/habits.md` — Add habit: "Ground-truth testing happens in first iteration, not after proxy metrics pass" (priority: med)

## Skill Extraction Candidates
- **Proposed skill**: `external-tool-compatibility` · **target**: `~/.claude/skills/external-tool-compatibility/SKILL.md` · **invocation**: model
  - **Trigger / leading word**: Building output for consumption by a specific external tool (slicer, IDE, browser, etc.)
  - **Inputs**: Target tool name, output format being generated
  - **Steps**:
    1. Research how target tool interprets the format (search docs, forums, GitHub issues)
    2. Find a known-working example output (download from community, export from tool itself)
    3. Examine working example structure before implementing
    4. Test in target tool within first implementation iteration
    5. When stuck, compare generated output byte-by-byte against working reference
  - **Success criteria**: Output renders/functions correctly in target tool on first user test
  - **Constraints / pitfalls**: Spec compliance ≠ tool compatibility; tools often implement subsets or extensions
  - **Verification evidence**: This session - 3MF spec was followed correctly but Bambu Studio doesn't support per-triangle colors
  - **Quality gate**: googleable=No · specific=Yes · real-effort=Yes
  - **Open questions**: Should this be part of workflow-build-one or standalone?
