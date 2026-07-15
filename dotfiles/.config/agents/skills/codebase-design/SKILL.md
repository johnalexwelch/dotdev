---
name: codebase-design
description: Shared vocabulary and principles for designing deep modules. Use when designing or improving a module's interface, deciding where a seam goes, or making code more testable. Also the reference vocabulary for improve-codebase-architecture and tdd.
---

## Context

Typical workflows: invoked inline during improve-codebase-architecture, tdd planning, domain-modeling
Pairs well with: improve-codebase-architecture, tdd, domain-modeling, grill-with-docs

# Codebase Design

Design **deep modules**: a lot of behaviour behind a small interface, placed at a clean seam, testable through that interface. Use this language and these principles wherever code is being designed or restructured.

Use these terms exactly — don't substitute "component," "service," "API," or "boundary." Consistent language is the whole point.

## Contract

Consumes: a module/interface/seam being designed, reviewed, or made more testable
Produces: shared design vocabulary + principles applied as guidance (deletion test, depth assessment, seam placement) — not code artifacts
Requires: none
Side effects: none (reference skill; advises, does not mutate files)
Human gates: none

## Glossary

**Module** — anything with an interface and an implementation. Deliberately scale-agnostic: a function, class, package, or tier-spanning slice. *Avoid*: unit, component, service.

**Interface** — everything a caller must know to use the module correctly: the type signature, but also invariants, ordering constraints, error modes, required configuration, and performance characteristics. *Avoid*: API, signature (too narrow — they refer only to the type-level surface).

**Implementation** — what's inside the module. Distinct from **Adapter**: a thing can be a small adapter with a large implementation (a Postgres repo) or a large adapter with a small implementation (an in-memory fake). Reach for "adapter" when the seam is the topic; "implementation" otherwise.

**Depth** — leverage at the interface: the amount of behaviour a caller can exercise per unit of interface they have to learn. A module is **deep** when a large amount of behaviour sits behind a small interface, **shallow** when the interface is nearly as complex as the implementation.

**Seam** *(Michael Feathers)* — a place where you can alter behaviour without editing in that place; the *location* at which a module's interface lives. Where to put the seam is its own design decision, distinct from what goes behind it. *Avoid*: boundary (overloaded with DDD's bounded context).

**Adapter** — a concrete thing that satisfies an interface at a seam. Describes *role* (what slot it fills), not substance (what's inside).

**Leverage** — what callers get from depth: more capability per unit of interface they learn.

**Locality** — what maintainers get from depth: change, bugs, knowledge, and verification concentrate in one place rather than spreading across callers. Fix once, fixed everywhere.

## Deep vs shallow

```
Deep module                          Shallow module (avoid)
┌─────────────────┐                  ┌──────────────────────────────┐
│  Small Interface│                  │       Large Interface         │
├─────────────────┤                  ├──────────────────────────────┤
│                 │                  │  Thin Implementation         │
│  Deep Impl      │                  └──────────────────────────────┘
│                 │
└─────────────────┘
```

When designing an interface, ask:
- Can I reduce the number of methods?
- Can I simplify the parameters?
- Can I hide more complexity inside?

## Principles

- **Depth is a property of the interface, not the implementation.** A deep module can be internally composed of small, swappable parts — they just aren't part of the interface.
- **The deletion test.** Imagine deleting the module. If complexity vanishes, it was a pass-through. If complexity reappears across N callers, it was earning its keep.
- **The interface is the test surface.** Callers and tests cross the same seam. If you want to test *past* the interface, the module is probably the wrong shape.
- **One adapter = hypothetical seam. Two adapters = real seam.** Don't introduce a seam unless something actually varies across it.

## Designing for testability

Good interfaces make testing natural:

1. **Accept dependencies, don't create them.**
   ```typescript
   // Testable
   function processOrder(order, paymentGateway) {}

   // Hard to test
   function processOrder(order) {
     const gateway = new StripeGateway(); // hidden dep
   }
   ```

2. **Return results, don't produce side effects.**
   ```typescript
   // Testable
   function calculateDiscount(cart): Discount {}

   // Hard to test
   function applyDiscount(cart): void { cart.total -= discount; }
   ```

3. **Small surface area.** Fewer methods = fewer tests needed. Fewer params = simpler test setup.

## Relationships

- A **Module** has exactly one **Interface** (the surface it presents to callers and tests).
- **Depth** is a property of a **Module**, measured against its **Interface**.
- A **Seam** is where a **Module**'s **Interface** lives.
- An **Adapter** sits at a **Seam** and satisfies the **Interface**.
- **Depth** produces **Leverage** for callers and **Locality** for maintainers.

## Rejected framings

- **Depth as ratio of implementation-lines to interface-lines** (Ousterhout): rewards padding the implementation. We use depth-as-leverage instead.
- **"Interface" as the TypeScript `interface` keyword or a class's public methods**: too narrow — interface here includes every fact a caller must know.
- **"Boundary"**: overloaded with DDD's bounded context. Say **seam** or **interface**.

## When to apply this skill

- Designing a new module from scratch
- Deciding where to put a seam before adding an adapter
- Evaluating whether a proposed abstraction earns its keep (deletion test)
- Making an existing module more testable without changing its callers
- Any time `improve-codebase-architecture` surfaces a deepening opportunity

## Reference docs

- [DEEPENING.md](DEEPENING.md) — dependency categories, seam discipline, and replace-don't-layer testing for deepening a cluster of shallow modules
- [DESIGN-IT-TWICE.md](DESIGN-IT-TWICE.md) — parallel sub-agent pattern for exploring radically different interfaces before committing to one
