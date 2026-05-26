# UI Prototype

## When this is the right shape

The question is about **appearance or layout**, not behavior. Typical triggers:

- "What should this dashboard look like?"
- "Should we use a sidebar or a top nav for this?"
- "How should we lay out the settings page?"
- "What's the right density for this data table?"
- "Should this be a modal, a slide-over, or an inline expansion?"

If you can phrase the question as "which of these looks/feels right?" or "what's the right way to present this?", you want a UI prototype.

## Two sub-shapes

### Sub-shape A: Adjustment to an existing page (preferred)

Mount variants directly on the existing route using a `?variant=` search parameter. The user sees their real page with real surrounding context, just with the target area swapped between options.

Use this when:
- The page already exists
- You're exploring alternatives for a section, component, or layout within it
- Surrounding context matters for evaluating the options

### Sub-shape B: New throwaway route (last resort)

Create a dedicated `/prototype-thing-name` route that renders the variants in isolation.

Use this only when:
- The page doesn't exist yet
- The prototype needs a fundamentally different page shell
- Mounting on the existing route would require too much plumbing for a throwaway

Default to Sub-shape A. Only fall back to B if A is genuinely impractical.

## Process

### 1. State the question and pick N variants

Write the question in a comment at the top of the prototype file. Then decide how many variants to explore:

- **Default: 3 variants.** This is almost always enough to triangulate.
- **Cap: 5 variants.** More than 5 creates decision paralysis without adding clarity.
- **Minimum: 2 variants.** If there's only one option, you don't need a prototype.

Name each variant descriptively: `dense-table`, `card-grid`, `split-pane` — not `variant-1`, `variant-2`.

### 2. Generate radically different variants

Each variant should be **structurally different**, not a color swap or spacing tweak. Good variation axes:

- **Layout**: sidebar vs. top-bar vs. full-bleed vs. split-pane
- **Information density**: everything-visible vs. progressive-disclosure vs. summary-first
- **Interaction model**: inline-edit vs. modal vs. slide-over vs. dedicated-page
- **Component choice**: table vs. cards vs. list vs. timeline
- **Hierarchy**: flat vs. grouped vs. nested vs. tabbed

Bad variation (too similar):
- Variant A: blue header, 16px padding
- Variant B: blue header, 24px padding
- Variant C: indigo header, 16px padding

Good variation (structurally different):
- Variant A: dense data table with inline editing and column sorting
- Variant B: card grid with drag-to-reorder and quick-action overlays
- Variant C: split pane with master list on left, detail view on right

### 3. Wire together with the variant switcher

All variants consume the **same data**. Create one shared data fixture (hardcoded, realistic-looking) and pass it to each variant component. The only thing that changes between variants is how the data is rendered.

**Sub-shape A** (existing route):
- Read `?variant=` from the URL search params
- Default to `variant=1` when no param is present (so the page works normally without the param)
- Render the selected variant component in place of the existing component

**Sub-shape B** (new route):
- Create a single route component that switches on `?variant=`
- Each variant is a separate component file or a section within the prototype file

### 4. Build the floating switcher bar

Every UI prototype gets a floating variant switcher so the user can flip between options without touching the URL bar.

**Spec:**
- **Position**: fixed, bottom-center, ~16px from bottom edge
- **Shape**: pill-shaped, semi-transparent background with backdrop blur
- **Contents**: left arrow, variant label (e.g. "2 / 3: card-grid"), right arrow
- **Keyboard shortcuts**: number keys `1` through `N` jump directly to that variant. Left/right arrow keys cycle.
- **Z-index**: high enough to float above page content
- **Unobtrusive**: should not interfere with the page layout or scrolling

**Example layout:**
```
    ◀  2 / 3: card-grid  ▶
    [1] [2] [3]
```

Keep the switcher component self-contained. It should be deletable in one step when the prototype is cleaned up.

### 5. Hand it over

Tell the user:
- What the question is
- How to see it (URL with `?variant=1`, or how to navigate to the prototype route)
- How to switch variants (keyboard shortcuts 1-N, arrow keys, or click the switcher)
- What to pay attention to when comparing (the specific aspect the question is about)

Then stop. Let them look at it.

### 6. Capture the answer

When the user picks a direction, record it before deleting the prototype:
- What was the question?
- Which variant won and why?
- What specific elements from other variants are worth stealing?

Put it in a commit message, an ADR, a NOTES.md, or an issue comment.

## Anti-patterns

- **Don't make variants too similar.** If a colleague can't tell them apart in 3 seconds, the variants aren't different enough. Vary structure, not polish.
- **Don't fetch different data per variant.** Same data, different rendering. The question is about presentation, not data. Hardcode one realistic fixture and share it.
- **Don't skip the floating bar.** Without it, the user has to manually edit the URL to switch variants. That friction kills the comparison experience. Always build the switcher.
- **Don't over-style the prototype.** Use the project's existing design tokens and components. The goal is to compare structures, not to pixel-perfect each variant.
- **Don't build variant-specific state.** All variants should be stateless renderers of the same props. If a variant needs unique interactive state (like "is this accordion open"), that's fine — but don't diverge the data model.
