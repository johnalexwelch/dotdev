# HTML report — deltas from improve-codebase-architecture

Do not rebuild the report. Reuse the scaffold, tone, diagram patterns, and Top-recommendation section from `improve-codebase-architecture/HTML-REPORT.md` verbatim (Tailwind + Mermaid CDN, editorial style, before/after diagrams, effort×benefit 2×2 matrix). This file specifies **only** what deep-dive adds.

Written at rank time (Step 2), stamped with outcomes at finish (Step 5). One file per run: `<tmpdir>/deep-dive-<repo-slug>-<ts>.html`. Auto-open, print absolute path.

## Header delta

Title `Deep Dive Review — {{repo}} — {{date}}`. Add a run strip: mode (`approve`/`auto`), budget, finding counts per lens, and a legend chip per lens colour (below). Keep improve's schematic legend for the deepen diagrams.

## Lens tag (new badge)

Every card carries a lens chip in the badge row:

| Lens | Colour | Card centrepiece |
|---|---|---|
| deepen | indigo | before/after depth diagram (improve's patterns, unchanged) |
| cut | rose | line-count strip: before N lines → after M, with the ponytail tag (`delete`/`stdlib`/`native`/`yagni`/`shrink`) |
| debt | amber | severity × effort chip + the tool that flagged it (knip/jscpd/madge/CVE) or the AI-slop class |
| perf | emerald | before/after profiler numbers (metric + value) with the baseline-from-history sparkline note |

The deepen card is improve's card unchanged. cut/debt/perf reuse the same card skeleton (Title · badge row · Files · Problem · Solution · Wins · benefit/effort strip · Evidence line) — only the centrepiece diagram differs. Don't invent new prose fields.

## C3 chip (new, all cards)

In the benefit/effort strip add one mono chip: `C3 churn=<n> cx=<n> cov=<n%> · score=<n>`. This is the rank signal; keep it terse.

## Outcome row (new — added in Step 5 stamp)

After reviews, patch each card's badge row with an outcome chip and append a one-line outcome strip:

- `verdict` chip: `done` (emerald) · `rejected` (slate) · `deferred` (amber) · `needs_human` (rose)
- `consensus`: `N rounds ✓` or `needs_human: <role> — <reason>`
- `pr`: linked URL (done only)
- `revisit`: date/trigger (deferred only)

Cards written at rank time have no outcome row; the stamp adds it in place. A `rejected` card keeps its reason (this is the visual "looks bad but is fine" record).

## Sections

1. **Findings** — cards grouped by lens, ranked by C3 score within each.
2. **Top recommendation** — improve's section, unchanged (highest effort×benefit).
3. **Run outcome** (Step 5 only) — a compact table: finding · lens · verdict · pr, so the daily report reads at a glance as "what shipped / what parked / what died."

## Tone

deepen cards use improve's fixed glossary (module/interface/seam/…). cut/debt/perf cards use plain English + the ponytail tags and severity/effort language. Don't force architecture vocab onto a perf or CVE finding.
