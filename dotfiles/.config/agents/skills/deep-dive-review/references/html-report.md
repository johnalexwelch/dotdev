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

## Tradeoffs block (required on every actionable card and every `needs_human` branch)

A recommendation the reader can't argue with isn't informed consent. Every card that proposes doing something — and every branch of a `needs_human` decision — renders a two-column **Pros / Cons** grid so the human sees both sides before choosing:

- **Pros** (emerald) — what the change buys, in concrete terms (lines deleted, bug class removed, observability gained). Reuse the Wins bullets; don't duplicate them elsewhere.
- **Cons** (rose) — the honest downside: coupling introduced, risk taken, behavior changed, work created, flexibility lost. **Never leave Cons empty** — if a change truly has no downside, say why in one line; a blank Cons column reads as a sales pitch, not an analysis.

For `needs_human`, each branch of the decision gets its own Pros/Cons (e.g. *freeze schema* vs *keep loose* each list both sides), so the choice is a genuine comparison, not a nudge toward the tool's preference. Keep each bullet ≤8 words.

## Decision-detail disclosure (any demoted, deferred, rejected, or high-stakes card)

Pros/cons give the shape of a decision; sometimes the human needs the *reasoning* behind a verdict — especially when the tool is telling them **not** to do something, or **not yet**. On **every** demoted, `deferred`, or `rejected` finding — and any `needs_human` where the call is non-obvious — add a collapsible **`<details>`** block (native HTML, no JS) titled “Why — the full reasoning” that answers, in plain language: **would it strengthen the project? would it simplify (remove complexity vs relocate it)? would it make things more manageable? what's the cost of inaction (flat vs rising)? and when would it become worth doing (the trigger)?** Keep it approachable — short paragraphs, an analogy is fine — and honest about both sides. Collapsed by default so the card stays skimmable; the reader expands only when they want the argument, not just the verdict.

## C3 chip (new, all cards)

In the benefit/effort strip add one mono chip: `C3 churn=<n> cx=<n> cov=<n%> · score=<n>`. This is the rank signal; keep it terse.

## Outcome row (new — added in Step 5 stamp)

After reviews, patch each card's badge row with an outcome chip and append a one-line outcome strip:

- `verdict` chip: `done` (emerald) · `rejected` (slate) · `deferred` (amber) · `needs_human` (rose)
- `consensus`: `N rounds ✓` or `needs_human: <role> — <reason>`
- `pr`: linked URL (done only)
- `revisit`: date/trigger (deferred only)

Cards written at rank time have no outcome row; the stamp adds it in place. A `rejected` card keeps its reason (this is the visual "looks bad but is fine" record).

## Unblock block (required on every `needs_human` card)

A `needs_human` verdict is a parked decision, not a dead end — so the card **must** tell the human exactly how to clear it. Render a rose-tinted `Unblock` box at the bottom of every `needs_human` card with three parts:

- **Decision** — the single question only a human can answer, in one line.
- **How to unblock** — numbered, concrete steps: the exact reply, command, file+line to open, or approval needed. No vague "review this"; give the literal action (e.g. “reply `20`”, “open `docs/api/endpoints.md:94`”, “reply `approve`”).
- **Then I will** — what the tool does automatically once unblocked (apply + pin test + PR), and what verdict it takes if the human declines (usually `deferred` with a `revisit` trigger, or `rejected`).

Every branch of the decision must resolve to a next state — never leave a path that just re-parks. This box mirrors the ledger's `unblock:` field (pipeline.md) so the HTML and the ledger say the same thing.

## Sections

1. **Findings** — cards grouped by lens, ranked by C3 score within each.
2. **Top recommendation** — improve's section, unchanged (highest effort×benefit).
3. **Run outcome** (Step 5 only) — a compact table: finding · lens · verdict · pr, so the daily report reads at a glance as "what shipped / what parked / what died."

## Tone

deepen cards use improve's fixed glossary (module/interface/seam/…). cut/debt/perf cards use plain English + the ponytail tags and severity/effort language. Don't force architecture vocab onto a perf or CVE finding.
