# pr-review — Comment Format

GitHub-specific markdown rules for review comments. Most of these exist to avoid the comment looking broken when pasted into the review thread UI.

## Suggestion blocks (primary format for mechanical fixes)

When a finding is a single-line mechanical change (rename, suffix fix, casing), use a suggestion block. GitHub renders it as a one-click "Commit suggestion" button — the author applies the fix without translating prose into a code change.

Format:

````markdown
<explanation sentence. Rule citation or failure mode. One line.>

```suggestion
<full replacement text for the anchored line(s), including indentation>
```

<optional: note about related sites that need the same change>
````

Rules:

- The comment must anchor to the **exact line(s)** being replaced. For a multi-line suggestion, set `start_line` + `line` in the JSON payload; the suggestion block must contain exactly that many replacement lines.
- The suggestion fence contents are the **complete replacement** for those line(s). Include indentation. No diff markers, no original text.
- One suggestion block per comment. Disjoint edits = separate comments.
- Explanation goes outside the fence, above or below.
- When the finding is not mechanically applicable (e.g. "add a schema yml description", "rename spans multiple CTEs"), write a regular comment with no suggestion fence.

Building the JSON payload: see `posting.md` for the full comment JSON schema and the `event` field gotcha (omit it for pending/draft; `"COMMENT"` submits immediately).

## Per-comment structure

Each comment in the output file follows this shape:

````
### <short, lowercase-ish heading>

```markdown
<body — one or two paragraphs of reasoning>

<optional code block showing the fix>

<one supporting link>
```
````

The outer ` ```` ` (4 backticks) lets the inner ` ``` ` code fence render correctly when the user pastes the body into GitHub's comment box. Without it, the inner fence terminates the outer one and the rest of the comment renders as plain text.

When the inner body itself contains nested code blocks (e.g. a yaml block that shows a sql block), use 5 backticks for the outermost fence.

## Anchoring (mandatory)

Every comment heading MUST include the target line number or range in parentheses. No exceptions. The reviewer pasting comments into GitHub needs to know exactly which line to anchor each comment to; an unanchored comment forces them to re-read the diff and find the right line themselves.

Format the file heading and each comment heading like this:

```
## File: `dags/dbt/snapshots/production_school_one_to_ones.sql`

### snapshot strategy (lines 4–12)

...

### naming convention (line 1)

...
```

Rules:

- Single line: `(line X)`
- Range on one file: `(lines X–Y)` using en-dash (–), not hyphen, so GitHub doesn't render it as negation
- Multiple non-adjacent locations in the same file: `(lines X, Y, Z)` or `(lines X–Y and A–B)`
- Cross-file reference inside one comment: `(monthly.sql line X, agg.sql lines Y–Z)`
- Comment that applies to the whole file (e.g. "docstring is too thin"): `(line 1)` is the convention. Do not write "(whole file)".
- Comment that applies to a pattern repeated across many lines (e.g. "every `where:` clause in this yml"): use the most representative line range plus a parenthetical scope note: `(lines 12–40 and 200–240, every test config block)`.

When citing line numbers inside the comment body itself (e.g. "see line 67 where this is gated"), use bare `line N` references so they remain readable when pasted. The heading line numbers are for anchoring; the body line numbers are for cross-references.

If a comment applies identically to multiple files, write it once on the primary file with full line number, and note `Same on <other_file> (line X)` at the bottom. Do not duplicate the full body.

### Verifying line numbers before writing

Line numbers must match the PR head, not the agent's local checkout of main. Pull files from the PR head and grep for the relevant code:

```bash
git fetch origin pull/<N>/head:pr-<N>
git show pr-<N>:<path> > /tmp/<basename>
grep -n '<distinctive snippet>' /tmp/<basename>
```

Double-check every line number against the file before writing the comment heading. A wrong line number is worse than no line number because the reviewer pastes it at the wrong anchor and confuses the author.

## Heading conventions

Comment headings should be:

- Lowercase or sentence case, not title case (humanizer pattern #17)
- Short: 2–6 words
- Descriptive of the issue, not the file (e.g. "snapshot strategy", not "snapshot.sql comment 1")

## Code blocks inside comments

Use language-tagged fences (` ```sql `, ` ```yaml `, ` ```python `) so GitHub applies syntax highlighting in the review thread.

For partial code (e.g. "change this one config key"), show enough surrounding context that the change is unambiguous, but no more. Three to seven lines of context is usually enough.

## Links

One supporting link per comment. Options in priority order:

1. **Exemplar PR or file** in the same repo: shows the pattern in real code
2. **dbt or framework docs**: explains the background
3. **Internal skill or standards doc**: cites the rule

Inline the link where it supports the point. No `References:` footer.

## What goes in the top-level summary

The top-level PR summary is its own block at the bottom of the output file:

```markdown
## Top-level PR summary

`​`​`​`markdown
<summary body>
`​`​`​`
```

Summary structure:

```
<One-sentence framing: what the PR does well, before the asks>

Fix before merge:
- <bullet>: <brief rationale>

Can batch:
- <bullet>: <brief rationale>

<One closing line citing the standard or exemplar PR, plus key docs links>
```

Keep it skimmable in 30 seconds. Detail belongs in the per-file comments.

## Voice rules

### First-person plural

Write as if we collectively own the codebase. Use "we" for the team and "this" for the code, not third-person abstractions.

| Bad | Good |
|---|---|
| "The author should pick one casing." | "We pick one casing and apply it everywhere." |
| "Anyone editing this later will introduce drift." | "The next edit will introduce drift." |
| "Downstream consumers shouldn't have to re-derive the grain." | "We shouldn't have to re-derive grain from the test config." |
| "The reviewer recommends extracting a helper." | "Extract a helper." |
| "The next person will copy this blindly." | "The next copy of this pattern will inherit the bug." |

Second person ("you") is also fine when addressing the PR author directly, but default to "we" for codebase-level claims.

### No hedging

State the recommendation. Don't perform deference around it.

| Hedge | Direct |
|---|---|
| "Worth confirming X." | "Confirm X." |
| "Worth a look at X." | "X is wrong because Y." |
| "Worth adding X." | "Add X." |
| "Worth pulling into a helper." | "Pull this into a helper." |
| "Worth opening an issue." | "Open a follow-up for X." |
| "OK to defer." | "Defer to a follow-up." or drop |
| "Could be a CTE." | "Lift to a CTE." |
| "Might want to consider X." | "Do X." |
| "Probably fine to leave." | "Leave as-is." or drop |
| "It seems like X." | "X." |

Factual status statements are not hedges and are fine: "Not blocking." / "OK to merge as-is." / "Confirmed by the test plan." These describe the comment's weight, not the reviewer's confidence.

## Avoid in any comment

- Bolded inline numbered headers (`**1. Strategy.** ... **2. Naming.** ...`). Split into separate comments instead.
- `**Summary:**` or `**Recommendation:**` headers inside a single comment
- Em dashes (—)
- Emojis (🔴🟡✅) as severity markers
- `References:` footer collecting multiple links
- Closing lines like "Let me know if you have questions" or "Happy to discuss"
- Hedging phrases (see table above)
- Third-person abstractions when "we" or "this" says the same thing
- Hedging stacks: "It could potentially possibly be argued..." Pick zero hedges.

## Acceptable, even though they pattern-match AI tells

- "Same DAG-level feedback as the redshift sibling."
- One `X, Y, and Z` rule-of-three when the three items are real engineering concepts ("config, source, tests")
- "Not blocking" as a severity tag

These read as senior IC voice in PR review context, not as AI template output.
