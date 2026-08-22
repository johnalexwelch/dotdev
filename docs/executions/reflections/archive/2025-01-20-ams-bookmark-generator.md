# Session Reflection: AMS Bookmark Generator V1

**Date**: 2025-01-20
**Goal**: Build Streamlit app to generate 4-color AMS-printable bookmark designs from book covers

## What Went Well

- **Taskflow PRD/issue review** — independent reviewer agents caught real bugs (style-variant rotation, stub exports) before execution
- **lib3mf over Blender** — research correctly identified lib3mf as the lighter path; avoided unnecessary Blender subprocess complexity
- **Graceful degradation** — caught OpenAI quota/model errors early and added friendly UI messages
- **E2E verification** — Playwright test confirmed full flow before declaring done
- **Handoff discipline** — created proper V2 handoff with ready-to-use prompts

## What Went Wrong / Friction

- **gpt-image-2 API churn** — 3 iterations: (1) model not found → switch from dall-e-3, (2) response_format rejected → remove param, (3) no URL → handle base64. Should have checked API docs/limits upfront.
- **lib3mf gotchas** — ctypes array requirement, SetObjectLevelProperty requirement for per-triangle materials. Discovered via test failures, not docs.
- **Aspect ratio mismatch** — generated 1024×1536 but bookmark is 57×190mm (~1:3.3 vs ~1:1.5). User had to ask "how will I know what it looks like?" before crop was added.
- **Reference images not sent** — described example bookmarks in text but didn't actually send them to gpt-image-2. User caught this.
- **Worktree merge confusion** — tried `git checkout main` in worktree where main was checked out elsewhere. Should have merged from the main worktree directly.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|-------------------------|------------|-------------------|
| 1 | "Use gpt-image-2 not gpt-image-1" | Assumed wrong default model | bookmarks/agent.py |
| 2 | "Images are too wide for bookmark shape" | No preview/crop of print area | bookmarks/app.py |
| 3 | "You're not actually sending reference images" | Described images in text, didn't encode/attach | bookmarks/agent.py |
| 4 | "Research the books, not just visual mapping" | Surface-level style extraction vs deep understanding | bookmarks/agent.py |

## Lessons

1. **API version drift**: OpenAI image models have incompatible param sets. gpt-image-2 rejects response_format, returns base64 not URL. Verify empirically before assuming.

2. **lib3mf material model**: Per-triangle colors require (a) BaseMaterialGroup with colors, (b) SetObjectLevelProperty to set default, (c) SetTriangleProperties per triangle. Missing any one → no colors in slicer.

3. **Print preview essential**: When generated aspect ratio ≠ print aspect ratio, show the crop area immediately. Users shouldn't have to ask.

4. **Worktree git operations**: Can't checkout a branch already checked out elsewhere. Merge from the worktree that has the target branch.

## Proposed Improvements

- [ ] `bookmarks/agent.py` — Add OpenAI model capability detection (supports response_format? returns URL or base64?) instead of hardcoded conditionals (priority: med)
- [ ] `docs/wayfinder/` — Document lib3mf material assignment recipe as a reusable snippet (priority: low)
- [ ] `bookmarks/app.py` — Show crop overlay on generated images by default, not after user asks (priority: high — already done this session)

## Skill Extraction Candidates

- **Proposed skill**: `lib3mf-multicolor-export` · **target**: `docs/wayfinder/` or standalone recipe · **invocation**: model
  - **Trigger**: "export multi-color 3MF", "AMS color printing", "per-triangle materials"
  - **Inputs**: PIL Image (quantized to N colors), output path, mesh dimensions
  - **Steps**:
    1. Quantize image to ≤4 colors with PIL.quantize()
    2. Extract palette indices and RGB values
    3. Create lib3mf model + BaseMaterialGroup
    4. Add materials with AddMaterial() for each color
    5. Build mesh grid (vertex array + triangle indices)
    6. Sample image at each cell center for material assignment
    7. Call SetObjectLevelProperty() with default material
    8. Call SetTriangleProperties() per triangle
    9. AddBuildItem() and WriteToFile()
  - **Success criteria**: 3MF opens in Bambu Studio with visible colors on top surface
  - **Constraints / pitfalls**: Must use ctypes arrays for Coordinates/Indices; SetObjectLevelProperty required or export fails silently
  - **Verification evidence**: test_export.py passes; visual confirmation in Bambu Studio
  - **Quality gate**: googleable=No · specific=Yes · real-effort=Yes
  - **Open questions**: How to handle images with >4 colors gracefully? Height-map extrusion as V2?
