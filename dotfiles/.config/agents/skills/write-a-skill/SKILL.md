---
name: write-a-skill
model: sonnet
reasoning: high
description: Create or revise agent skills - invocation choice, information hierarchy, granularity, descriptions, leading words - then check the draft against known failure modes (no-op, duplication, sediment, sprawl). Use when the user wants to create, write, build, or fix up a skill, or asks whether a skill's structure or description is any good.
---

## Contract

Consumes: skill requirements/description from user, or an existing skill to revise
Produces: SKILL.md file, optional `references/*.md` files and `scripts/`
Requires: none
Side effects: creates or edits skill directory and files
Human gates: skill draft review before finalizing

## Context

Typical workflows: skill authoring (standalone)
Pairs well with: skill-maintenance, domain-modeling (shared vocabulary conventions)

# Writing Skills

A skill exists to wrangle determinism out of a stochastic system. **Predictability** — the agent taking the same *process* every run, not producing the same output — is the root virtue every section below serves. A brainstorming skill should predictably diverge; its words vary, its behavior doesn't.

## Process

0. **Quality gate (new skills only)** — before authoring a *new* skill, require all three true, or it's documentation, a command, or a one-off, not a skill:
   - "Could someone Google this in 5 minutes?" → **No**
   - "Is it specific to this codebase, project, or workflow?" → **Yes**
   - "Did it take real debugging, design, or operational effort to discover?" → **Yes**
   Skip this gate when revising an existing skill.

1. **Gather requirements** — ask the user:
   - What task/domain does the skill cover, and is there an existing word or phrase (a **leading word**, see below) the agent should think with while running it?
   - Model-invoked or user-invoked (see Invocation)? If the answer is "it should fire on its own when relevant," it needs a description that earns its keep; if "I'll type its name," it doesn't.
   - What distinct **branches** (use cases) does it need to handle?
   - Does it need executable scripts, or reference material heavy enough to push into `references/`?

2. **Draft the skill**:
   - Write SKILL.md as **steps** (ordered actions, when the skill has any) and/or **reference** (definitions, rules, facts consulted on demand) — most skills mix both.
   - Give every step a **completion criterion** — the condition that tells the agent it's done. Make it checkable ("done" vs "not done" is unambiguous) and, where it matters, exhaustive ("every modified file accounted for," not "produce a change list"). A vague criterion invites **premature completion** — the agent declaring victory and moving on before the work is real.
   - Apply progressive disclosure while drafting, not after: put in SKILL.md what every branch needs; push what only some branches need into `references/*.md`.
   - Prune as you go — no filler, no restating what the model already does by default, no meaning duplicated across two spots.

3. **Review with user** — present the draft and run the Review checklist below, out loud if useful. For discipline-enforcing or behavior-shaping skills, verify the wording empirically before finalizing: see `references/testing.md`.

## Invocation: model-invoked vs. user-invoked

Every skill pays one of two costs. Decide which, before writing the description.

- **Model-invoked** — keeps a `description`, so the agent can fire it autonomously and other skills can reach it (you can still type its name too). It contributes permanent **context load**: the description sits in the window on every turn, competing with everything else for attention. Mechanics: omit `disable-model-invocation`; write an agent-facing description with real trigger phrasing.
- **User-invoked** — strips the description from the agent's reach: only a human typing its name can invoke it, and no other skill can call it either. Zero context load, but it spends **cognitive load** — *you* become the index that has to remember the skill exists. Mechanics: set `disable-model-invocation: true`; the description becomes human-facing (a one-line summary, no trigger list).

Pick model-invocation only when the agent genuinely needs to reach the skill on its own, or another skill needs to call it. If it only ever fires by hand, make it user-invoked and pay no context load.

When user-invoked skills multiply past what anyone can remember, that's the point to write a **router skill**: one user-invoked skill that names the others and when to reach for each (this repo's `workflow-router` is that pattern applied to workflows). A router can only point — it can't fire a user-invoked skill for the agent, since none of them carry a description.

## Writing the description

The description is the only thing the agent sees when deciding which skill to load, so it earns harder pruning than anything else in the file.

- **Single-quote the value.** Descriptions routinely contain `: `, `"quoted-term": `, and `—`; unquoted, YAML reads `word: x` inside them as a nested mapping and the frontmatter fails to parse. Always wrap the value in single quotes (double any literal `'`).
- **Front-load the leading word.** Whatever concept should trigger the skill, put it in the first few words — that's where the description does its invocation work.
- **One trigger per branch.** Listing synonyms for the same trigger ("build features using TDD ... asks for test-first development") is **duplication**, not two branches. Collapse restatements; keep only genuinely distinct triggers.
- **Cut identity that's already in the body.** The description states what the skill is and lists triggers — it doesn't need to re-explain the process.
- Max ~1024 chars, third person, first sentence states the capability, later sentences carry "Use when [specific triggers]."

Good: `Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when user mentions PDFs, forms, or document extraction.`
Bad: `Helps with documents.` — gives the agent no way to distinguish this from any other document skill.

## Granularity — one skill, one job

Granularity is how finely you divide skills, and every cut spends one of the two loads above, so only split when the cut earns it:

- **By invocation** — split off a new model-invoked skill when you have a distinct leading word that should trigger independently, or another skill needs to reach it on its own. You're buying a permanent, always-loaded description; make sure the independent reach is worth that.
- **By sequence** — split a run of steps when the steps still ahead (a step's **post-completion steps**) are visibly tempting the agent to rush the one in front of it. Hiding the later steps behind a real context boundary (a hand-off, a subagent dispatch) removes the pull; splitting an inline model-invoked call does not, because the later steps stay in context anyway.

The failure mode in the other direction is **sprawl**: one skill trying to be everything, so every branch pays for every other branch's content. If a skill needs a table of contents to navigate, it's probably several skills wearing one description.

## Information hierarchy & progressive disclosure

Rank content by how immediately the agent needs it:

1. **In-skill steps** — the ordered actions in SKILL.md. The primary tier when the skill has any.
2. **In-skill reference** — definitions, rules, facts kept in SKILL.md, consulted on demand. Often a legitimately flat peer-set (every rule of a review on one rung) — fine, not a smell.
3. **Disclosed reference** — pushed into a sibling file (`references/*.md`) and reached only when a **context pointer** in SKILL.md fires. This repo's convention: a `references/` subdirectory, one topic per file (see `design-plan/references/`, `okr-generator/references/okr-rubric.md`). Reserve a bare top-level file like a `GLOSSARY.md` for skills with no other companion files; once a skill has more than one disclosed file, put them all under `references/` for consistency.

**Progressive disclosure** is the move down this ladder: out of SKILL.md, into a linked file, so the top stays legible. The test for what to push down is **branching** — inline what every branch needs, disclose what only some branches reach. A pointer's *wording*, not its target, decides whether the agent actually follows it: if must-have material behind a pointer keeps getting missed, sharpen the wording before pulling the content back inline.

**Co-location** governs what sits beside what once it's placed: keep a concept's definition, rules, and caveats under one heading rather than scattered across the file, so reading one part brings its neighbors with it.

Add a script (under `scripts/`) instead of reference prose when the operation is deterministic (validation, formatting) or the same code would otherwise be regenerated every run — scripts save tokens and remove a class of errors that generated code can introduce.

## Leading words

A **leading word** is a compact concept already living in the model's pretraining — *lesson*, *fog of war*, *tracer bullets*, *tight loop* — that the agent thinks with while running the skill. Repeated through the text, it accumulates a distributed definition and anchors a whole region of behavior in very few tokens, because it recruits priors the model already holds instead of spelling out a definition from scratch.

It does double duty: in the body it anchors *execution* (the agent reaches for the same behavior every time the word shows up); in the description it anchors *invocation* (when the same word lives in your prompts, docs, and code, the agent links that language to the skill and fires it more reliably).

When drafting or revising, look for a phrase spelled out in full more than once and ask whether an existing pretrained word already means that. "Fast, deterministic, low-overhead" restated across three sentences collapses into *tight*. A coined word works too, but only if you define it clearly — it recruits no priors, so you pay in definition tokens what a pretrained word gives you free. Reach for an existing word first.

## Pruning

Keep each meaning in exactly one **single source of truth** — one authoritative place, so changing the behavior is a one-place edit. Two lines saying the same thing in different words is **duplication**: it costs maintenance (fix one, must fix both) and inflates that meaning's apparent importance past its real rank.

Check every remaining line for **relevance** — does it still bear on what the skill does, or has the behavior or context it describes moved on? Then run the **no-op test** sentence by sentence: does this sentence change the agent's behavior versus what it would do anyway? If not, delete the whole sentence — don't trim it down, remove it. Be aggressive; most prose that fails this test should go entirely.

## Match the form to the failure

Before writing a fix, classify the baseline failure — the form that cures one type measurably backfires on another:

| Baseline failure | Right form | Wrong form |
|---|---|---|
| Knows the rule, skips it under pressure | Prohibition + rationalization table + red flags (see `references/testing.md`) | Soft "prefer/consider" |
| Complies, but output is wrong-shaped (bloated, buried verdict, restates the input) | Positive **recipe**/contract: state what the output *is*, its parts in order | Prohibition ("don't restate") |
| Omits a required element from output it already produces | Structural: a REQUIRED slot in the template it fills | Prose reminder near the template |
| Behavior should depend on a condition | Conditional keyed to an **observable predicate** ("if the brief exists, reference it") | Unconditional rule + exemption clauses |

Prohibitions backfire on shaping problems: under a competing incentive the agent negotiates with "don't X" and emits *more* of it — a recipe leaves nothing to negotiate. No nuance clauses ("don't X unless…" reopens the negotiation); exemption clauses don't scope ("doesn't apply to code blocks" still suppresses code blocks) — restructure so the rule can't reach the exempt part. This generalizes **Negation** below; reach for prohibition only on genuine discipline failures.

## Failure modes — check the draft against these

- **No-op** — an instruction the model already follows by default ("be thorough" when it's already thorough-ish). Costs load, changes nothing. Fix: a stronger, more specific word, or delete it.
- **Duplication** — the same meaning stated in more than one place. Fix: pick the single source of truth, delete the rest.
- **Sediment** — stale layers that accumulated because adding felt safe and removing felt risky. The default fate of any skill without a pruning pass. Fix: re-read the whole file and ask, for each section, "would I write this today?"
- **Sprawl** — the skill is simply too long, even where every line is live and unique. Fix: push reference behind `references/` pointers; split by branch or sequence.
- **Premature completion** — the agent ends a step before it's genuinely done. Fix the completion criterion first (cheap, local); only split the sequence if the criterion is irreducibly fuzzy and you've actually observed the rush.
- **Negation** — steering by "don't do X" tends to name X and make it more available, not less ("don't think of an elephant"). Fix: state the positive target behavior instead. Keep a hard "don't" only for guardrails you truly can't phrase positively, and pair it with what to do instead.

Full definitions and cross-references: `references/glossary.md`.

## Skill structure

```
skill-name/
├── SKILL.md            # Main instructions (required)
├── references/          # Disclosed reference, one topic per file (if needed)
│   └── topic.md
└── scripts/             # Deterministic utility scripts (if needed)
    └── helper.js
```

## SKILL.md template

```md
---
name: skill-name
model: sonnet
description: 'Brief description of capability. Use when [specific triggers].'
# disable-model-invocation: true   # add only if this is user-invoked
---

# Skill Name

## Process

[Ordered steps, each ending on a checkable completion criterion]

## Reference

[Definitions, rules, or examples consulted on demand]

## Advanced

[Context pointer to disclosed reference: see references/topic.md]
```

## Review checklist

After drafting, verify:

- [ ] Invocation choice is deliberate: model-invoked only if the agent (or another skill) must reach it unprompted
- [ ] Description front-loads the leading word, and lists one trigger per branch (no duplicated triggers)
- [ ] Frontmatter parses: `python3 -c "import sys,yaml; yaml.safe_load(open(sys.argv[1]).read().split('---')[1])" SKILL.md` (single-quoted description)
- [ ] Tool-agnostic determination made (see docs/decision-log.md DL-0016): does this skill have a hard dependency on an MCP server or interactive-only tool with no fallback path? If yes, set `codex-compatible: false` in frontmatter and state the reason in a one-line comment or the skill's own body. If no (the common case), leave `codex-compatible` unset — the sync tooling defaults to inclusive, so an unset skill still syncs to Codex; don't set `codex-compatible: true` explicitly unless you have a specific reason to document it was checked.
- [ ] Every step has a checkable, and where relevant exhaustive, completion criterion
- [ ] Nothing in SKILL.md is a no-op — each line changes behavior versus the model's default
- [ ] No duplicated meaning between sections, or between SKILL.md and a `references/` file
- [ ] Content only some branches need lives in `references/`, one topic per file
- [ ] No time-sensitive info baked in as if permanent
- [ ] Concrete examples included, not just abstract rules
- [ ] `references/` pointers are one level deep and worded so the agent actually follows them
- [ ] Guidance form matches the failure type (see Match the form to the failure); for discipline/shaping skills, wording micro-tested against a no-guidance control (see `references/testing.md`)
