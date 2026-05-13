---
name: zoom-out
description: Step back from current work context with structured perspective shifts (local, domain, strategic)
disable-model-invocation: true
---

# Zoom Out

## Purpose

Interrupt tunnel vision by offering three levels of perspective shift. When you're deep in implementation details, this skill forces a step back to check alignment with broader goals.

## Modes

### Local mode
**Scope:** Current module/file neighborhood

- Map the module's callers and callees
- Show the dependency graph 1-2 levels out
- Identify coupling points and abstraction boundaries
- Answer: "What does this module connect to, and are those connections healthy?"

**Output:** Module map with incoming/outgoing dependencies, coupling assessment

### Domain mode
**Scope:** Bounded context and domain language

- Read CONTEXT.md for domain term definitions
- Map current work to bounded context boundaries
- Check if implementation language matches domain language
- Identify concept drift (code using wrong terms or mixing contexts)
- Answer: "Is this work respecting domain boundaries and using correct terminology?"

**Output:** Domain alignment assessment, term mapping, boundary violations

### Strategic mode
**Scope:** Goal-level reframe from issue/PRD/plan

- Read the originating issue, PRD, or design plan
- Compare current implementation direction against stated goals
- Check if scope has crept or narrowed inappropriately
- Identify if current work is still the highest-leverage path
- Answer: "Are we still building the right thing, and is this the right approach?"

**Output:** Goal alignment assessment, scope check, pivot recommendation (if needed)

## Usage

Invoke without mode for auto-selection based on context:
- Deep in a single file → local
- Working across modules → domain
- Feeling uncertain about direction → strategic

Or specify explicitly: "zoom out local", "zoom out domain", "zoom out strategic"

## Contract

Consumes: current work context (open files, recent changes, active issue/plan)
Produces: perspective shift assessment (mode-dependent output above)
Requires: none
Side effects: none (read-only analysis)
Human gates: none

## Context

Typical workflows: any (interrupt utility, not part of a specific workflow)
Pairs well with: improve-codebase-architecture (local findings may trigger), design-plan (strategic findings may trigger replanning)
