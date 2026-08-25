# Skill-Writing Glossary

Companion to `write-a-skill/SKILL.md`. Full definitions for the vocabulary the main file uses in passing. **Bold terms** within a definition are themselves defined here — find them by heading. Adapted from the upstream reference at [mattpocock/skills](https://github.com/mattpocock/skills), `writing-great-skills`.

Grouped by axis: **Invocation** (how a skill is reached), **Information Hierarchy** (how its content is arranged), **Steering** (how the agent's runtime behavior is shaped), and **Pruning** (how it's kept lean). Failure modes live beside the lever that cures them.

## Predictability

The degree to which a skill makes the agent behave the same *way* on every run — the same process, not the same output (a brainstorming skill should predictably diverge; its tokens vary, its behavior doesn't). The root virtue every other term serves.

## Invocation

### Model-Invoked

A skill that keeps its **description**, so the agent can see it and fire it autonomously — a human can still type its name too, so model-invocation always *includes* user reach. Pays a permanent **context load** on every turn in exchange for that discoverability, and is reachable by other skills for the same reason. Pick this only when the agent must reach the skill on its own.

### User-Invoked

A skill with its **description** stripped — invisible to the agent, reachable only by a human typing its name. Trades agent-discoverability for zero **context load**. Because it has no description, no other skill can fire it either.

### Description

The skill's machine-readable trigger — the one **context pointer** a model-invoked skill is forced to keep loaded at all times. Keep it and the skill is model-invoked; delete it (`disable-model-invocation: true`) and it's **user-invoked**.

### Context Pointer

A reference held in the agent's context that names out-of-context material and encodes the condition for reaching it. The description is the top-level context pointer (context window → skill); pointers to `references/*.md` files are the same object one level down. Its *wording*, not its target, decides when and how reliably the agent follows it.

### Context Load

The cost a model-invoked skill imposes on the agent's context window — its description, always loaded, spending tokens and attention on every turn. The brake on splitting into more model-invoked skills.

### Cognitive Load

The cost a user-invoked skill imposes on the human — remembering it exists and when to reach for it. Not a cost to minimize outright: it's the price of human agency where human judgment should decide. The brake on splitting into more user-invoked skills.

### Router Skill

A user-invoked skill whose job is to name your other user-invoked skills and when to reach for each, so the human has one thing to remember instead of many. It can only point, never fire — user-invoked skills have no description, so nothing but the human reaches them. (`workflow-router` in this repo is this pattern applied to workflow selection.)

### Granularity

How finely you divide skills. More model-invoked skills spend **context load**; more user-invoked skills spend **cognitive load**. Split by invocation when a **branch** deserves independent reach; split by sequence when a step's **post-completion steps** need hiding.

## Information Hierarchy

### Information Hierarchy

A skill's content ranked by how immediately the agent needs it: **steps** (in-file, primary) → in-file **reference** (secondary) → disclosed reference, behind a **context pointer** (tertiary). A skill with no steps uses just the bottom two rungs — a legitimately flat peer-set, not a smell. Keep the top legible; push down whatever you can.

### Steps

The ordered actions the agent performs, when a skill has them — the primary tier, and the part that earns its place in SKILL.md directly. Every step ends on a **completion criterion**.

### Reference

Material consulted on demand — definitions, facts, rules, examples. Secondary when a skill has steps; the entire content when it doesn't. Reached via **context pointers**; the prime candidate for **progressive disclosure**.

### External Reference

Reference that lives outside the skill system entirely — a plain file with no description, not invocable — that any skill can point at. The only shared home two user-invoked skills can use, since neither has a description to fire the other.

### Progressive Disclosure

Moving reference down the ladder — out of SKILL.md, behind a context pointer, into `references/*.md` — so the top stays legible. Licensed by **branching**: disclose what only some branches need, inline what every path needs. If a pointer fires unreliably on must-have material, sharpen its wording before pulling the content back inline.

### Co-location

Keeping material the agent needs at once in one place — a concept's definition, rules, and caveats under one heading, not scattered — so reading one part brings its neighbors with it. Distinct from **duplication**: co-location groups one meaning; duplication repeats it.

### Sprawl — *failure mode*

A skill that is simply too long, independent of whether its content is stale or repeated. Costs readability, maintainability, and tokens. Cured by the information hierarchy: push reference behind pointers, split by branch or sequence.

## Steering

### Branch

A distinct way a skill can be invoked or a distinct case it handles, so different runs take different paths through it. A skill with many steps may carry many branches; a linear one has none.

### Leading Word

A compact concept already living in the model's pretraining (*lesson*, *fog of war*, *tracer bullets*, *tight loop*) that the agent thinks with while running the skill. Repeated as a token — not restated as a sentence — it accumulates a distributed definition and anchors a whole region of behavior in the fewest tokens, by recruiting priors the model already holds. Anchors *execution* in the body and *invocation* in the description. A coined word works only if clearly defined; it recruits no priors, so you pay in definition tokens what a pretrained word gives free.

### Completion Criterion

The condition that tells the agent a unit of work is done. Two properties make it a lever: **clarity** (can the agent tell done from not-done? resists **premature completion**) and **demand** (how much it requires — "every modified file accounted for" forces more **legwork** than "produce a change list"). The strongest criteria are both checkable and exhaustive.

### Legwork

The work an agent does within a step — reading files, exploring, digging up what it needs rather than offloading to the user. Raised by a leading word (*thorough*, *relentless*) or a demanding completion criterion; goes thin when that demand is missing or **premature completion** cuts the step short.

### Post-Completion Steps

The steps that follow the current one. Visible, they pull the agent toward **premature completion** — the more of them it can see, the stronger the pull. Hiding them (by splitting the sequence across a real context boundary — a hand-off, a subagent dispatch) removes the pull; an inline model-invoked call doesn't, since the later steps stay in context anyway.

### Premature Completion — *failure mode*

Ending a step before it's genuinely done, because attention has slipped to *being done* rather than to the work. A tug-of-war between visible **post-completion steps** (the pull) and the **completion criterion**'s clarity (the resistance). Fix order: sharpen the criterion first (cheap, local); only hide later steps if the criterion is irreducibly fuzzy *and* you've actually observed the rush.

### Negation — *failure mode*

Steering by prohibition drags the forbidden behavior into context and makes it *more* available, not less ("don't think of an elephant"). Fix: state the positive target behavior so the banned one is never spoken. Keep a hard prohibition only as a guardrail you truly can't phrase positively, and pair it with the positive target even then.

## Pruning

### Single Source of Truth

The state where each meaning lives in exactly one authoritative place, so changing the skill's behavior is a one-place edit. **Duplication** is its violation.

### Duplication — *failure mode*

The same meaning stated in more than one place. Costs maintenance (fix one, must fix all), costs tokens, and inflates that meaning's apparent importance past its real rank.

### Relevance

Whether a line still bears on what the skill does. Lost either by never having borne on the task, or by going stale as the behavior or world it describes changes. Distinct from **no-op**: relevance asks whether a line bears on the task; no-op asks whether it changes behavior.

### Sediment — *failure mode*

Stale layers that settle because adding feels safe and removing feels risky, so irrelevant lines accumulate until you have to core down through them to find what's still live. The default fate of any skill without a pruning discipline.

### No-Op — *failure mode*

An instruction that changes nothing because the model already does it by default — load spent to say nothing. Test: does this line change behavior versus the default? A weak leading word (*be thorough* when the agent is already thorough-ish) is a no-op; the fix is a stronger word (*relentless*), not a different technique. This is model-relative: settle disagreement by running the skill, not by debate.
