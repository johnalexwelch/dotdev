# Session Reflection: 3MF Multi-Color Export Debugging

**Date**: 2026-08-11
**Goal**: Convert bookmark PNGs to multi-color 3MF files for Bambu Lab AMS printing

## What Went Well

- Successfully identified Bambu Studio requires `m:colorgroup` + separate objects (not per-triangle materials)
- Pixel-based approach worked correctly for multi-color output
- Quick iteration cycle with curl + Bambu Studio visual verification
- Created comprehensive handoff when problem exceeded session scope

## What Went Wrong / Friction

- **Abandoned working solution**: Pixel-based export worked but I kept "improving" to vector tracing, which broke everything
- **Library API misunderstanding**: Misread mapbox_earcut API twice (1D vs 2D arrays, ring_start vs ring_end indices)
- **Large untested changes**: Rewrote entire export_to_3mf() multiple times without incremental testing
- **Late research**: Should have fetched Bambu Studio source code earlier to understand expected 3MF format
- **No debugging output**: Added no logging to see actual vertices/triangles being generated

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|-------------------------|------------|-------------------|
| 1 | "its all spaghetti" - mesh geometry broken | Untested vector triangulation rewrite | No owning skill - domain-specific |
| 2 | "8 colors showing" when should be 4 | Color quantization not enforced in all paths | bookmarks/agent.py |
| 3 | "still pretty pixelated" after multiple attempts | Kept trying vector when pixel worked | Over-engineering instinct |

## Lessons

1. **Working > Perfect**: A working pixel-based solution at 0.1mm resolution would have been better than a broken vector solution. Ship the ugly thing that works.

2. **Test libraries in isolation**: Before integrating mapbox_earcut, should have run `python -c "import earcut; ..."` to understand the API. Wasted two iterations on wrong usage.

3. **Add debugging early**: When mesh geometry is wrong, add logging to print vertex counts, triangle counts, coordinate ranges BEFORE making more changes. Flying blind wastes cycles.

4. **Research external formats first**: Bambu Studio's 3MF expectations could have been found by fetching their source code earlier. Did this eventually but after several failed approaches.

5. **Incremental geometry changes**: Never rewrite an entire mesh-generation function. Change one thing (resolution, winding, coordinates) and verify visually before the next change.

## Proposed Improvements

- [ ] No skill changes needed - this was domain-specific 3D geometry debugging, not a workflow gap

## Skill Extraction Candidates

None - 3MF/mesh debugging is too domain-specific for a general skill. The pattern "test library APIs in isolation before integrating" is already covered by general debugging instincts.
