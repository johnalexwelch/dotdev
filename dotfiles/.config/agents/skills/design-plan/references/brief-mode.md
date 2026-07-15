# Brief Mode Reference

Use brief-mode for bug, feature, or investigation-scale work from a free-form
brief. Brief-mode skips `/repo-audit` and anchors the plan on `REQ-NN` IDs or
ticket slugs.

## Input Resolution

Enter brief-mode when `brief` is set.

Resolve `brief` as:

1. If it starts with `@`, treat the rest as a file path and read it.
2. If it parses as a URL, fetch it. If the fetch fails, halt and ask the user to paste the brief contents inline.
3. Otherwise treat it as inline text.

Abort if both `audit_path` and `brief` are set; they are mutually exclusive.

If a URL fetch fails, prompt the user to paste the brief contents inline. Do
not silently fall back.

## Stable IDs

- Scan for ticket slugs such as `JIRA-123`, `ENG-789`, and `#456`.
- Keep ticket slugs verbatim in §5 Addresses.
- If no ticket slugs exist, auto-number distinct deliverables as `REQ-01`, `REQ-02`, ...
- Trivial bugs collapse into a single `REQ-01`.
- If the brief has no ticket slugs and no extractable deliverables, auto-number a single `REQ-01` for the whole scope and surface the assumption in §2.

## Frame Extraction

Parse the brief and extract:

- **What's being asked** — drop into §2 Problem verbatim with light formatting. Preserve the user's phrasing.
- **Distinct deliverables** — auto-number as `REQ-01`, `REQ-02`, ... if no ticket slugs are present. Each becomes a candidate for a phase's Addresses line.
- **Ticket references** — any `JIRA-123`-style or `#456`-style slugs. Keep verbatim; they go in §5 Addresses alongside or instead of `REQ-NN`.
- **Implicit scope hints** — words like "fix," "bug," "broken," and "regression" point to bug-scale work. Words like "add," "implement," and "support" point to feature-scale work. Feed these hints into the phase-count rules.

## Brief-Mode Drafting Rules

- §2 Problem preserves the user's language more than audit-mode does.
- §5 Addresses lines use `REQ-NN`, ticket slugs, or `n/a` for hygiene phases.
- For brief-mode bug fixes, the pilot rule collapses: the fix itself is the pilot.
- A trivial bug fix is one phase total: fix + verify.
- A small feature is 2-3 phases: pilot slice plus 1-2 follow-ups.
- Do not pad a bug-fix plan with ceremonial phases.
- In greenfield work, no §8 Delete list is required; rename §5 to "Build plan" if that is clearer. Pilot phase is still required unless explicitly waived.

## Brief-Mode Slug Examples

- Bug: `/design-plan brief="fix mobile scroll on /profile page"` produces a 1-phase plan with `REQ-01` in §5 Addresses and filename `<date>-fix-mobile-scroll-on-profile-page-design.md`.
- Small feature: `/design-plan brief="add dark-mode toggle to settings"` produces a 2-3 phase plan.
- Brief from a ticket: `/design-plan brief="@docs/tickets/JIRA-123.md"` reads the file, extracts `JIRA-123` as the anchor slug, and uses it as the §5 Addresses reference.
- Brief from a URL: `/design-plan brief="https://linear.app/.../issue/ENG-456"` fetches and extracts `ENG-456`.

## Brief-Mode Error Handling

| Failure | Behavior |
|---------|----------|
| Both `audit_path` and `brief` set | Abort. They're mutually exclusive. |
| `brief` is a file path (`@...`) and the file is missing | Abort with the path that was tried. |
| `brief` is a URL and fetch fails | Prompt the user to paste the brief contents inline. Do not silently fall back. |
| Brief has no ticket slugs and no extractable deliverables | Auto-number a single `REQ-01` for the entire scope; surface the assumption in §2. |
| Existing plan at `output_path` | Ask: overwrite, date-suffix, or abort. Default date-suffix. |

## Brief-Mode Examples

```text
User: /design-plan brief="fix mobile scroll on /profile page"
Claude: [creates a 1-phase bug plan]
        [uses REQ-01 in §5 Addresses]
        [writes docs/plans/<date>-fix-mobile-scroll-on-profile-page-design.md]
```

```text
User: /design-plan brief="add dark-mode toggle to settings"
Claude: [creates a 2-3 phase feature plan]
        [pilot slice first, then follow-up phases]
```
