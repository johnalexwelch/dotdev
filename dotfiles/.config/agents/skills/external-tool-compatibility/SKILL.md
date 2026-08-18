---
name: external-tool-compatibility
layer: judgment
model: sonnet
description: 'Ground-truth discipline for building output that a specific external tool must consume — a slicer, browser, IDE, spreadsheet app, media player, CAD/print tool: research how the target tool interprets the format, obtain a known-working reference output, and validate inside the target tool within the first iteration. Use when generating or exporting a file or format for a named external tool (e.g. 3MF for Bambu Studio, xlsx for Excel, SVG for a cutter), or when output passes spec/format validation but renders or behaves wrong in the consuming tool.'
---

## Contract

Consumes: target tool name + version, output format being generated
Produces: compatibility notes on how the target tool interprets the format; a known-working reference output; an implementation validated in the target tool
Requires: a way to run the ground-truth check — the target tool itself, or the user operating it
Side effects: downloads or exports reference sample files
Human gates: when only the user can run the target tool, every validation loops through them — schedule those checks first and batch variants to respect their time

## Context

Typical workflows: fires inside implementation/debugging whenever the deliverable is input to an external program
Pairs well with: diagnose (when the incompatibility becomes a hard bug), tdd (proxy checks are still useful *after* ground truth passes)

# External Tool Compatibility

**Spec compliance ≠ tool compatibility.** Tools implement subsets of a spec and add extensions; output can be perfectly valid against the format spec and still render or behave wrong in the tool that matters. The only test that counts is **ground truth**: the actual target tool consuming the actual output. Proxy metrics (schema-valid, watertight mesh, well-formed XML) confirm you followed the spec — not that the tool honors it (2026-08-11: 5+ hours and ~15 spec-correct 3MF export variants, all invisible to Bambu Studio, which ignores per-triangle color attributes entirely).

## Process

### 1. Research the target tool first

Before writing any output code, research how the *target tool* interprets the format — its docs, forums, GitHub issues, and community threads for `<tool> <format> <feature>`. You are researching the tool's behavior, not the format spec. Ten minutes here beats hours of spec-correct variants the tool ignores.

Done when: you can state, with a source, which parts/dialect of the format the target tool actually honors for the feature you're building.

### 2. Find a known-working reference output

Obtain a file that already does what you're trying to produce and provably works in the target tool: export one from the tool itself, download a community example, or take one from a sibling tool the target is known to import. Verify it works in the target tool before treating it as reference.

Done when: a reference file exists on disk and has been confirmed working in the target tool.

### 3. Reverse-engineer the reference before implementing

Examine the reference's structure (unzip it, pretty-print it, dump its sections) and note how it encodes the feature — which elements, attributes, extensions, or sidecar files carry it. Implement to match the reference's dialect, not your reading of the spec.

Done when: your implementation plan names the concrete structures the reference uses, and any spec features the reference avoids.

### 4. Ground-truth in the target tool within the first iteration

Validate the first generated output in the target tool *before* polishing proxy metrics. If the agent can't run the tool, hand the user one file and one question ("open this in X — do the colors show?") as the first check, not the fifteenth. Never queue multiple untested variants: each iteration earns its ground-truth check before the next variant exists.

Done when: the target tool has consumed a generated output and the observed result (pass or fail) is recorded.

### 5. When stuck, byte-compare against the reference

If generated output fails where the reference works, stop theorizing: diff the two artifacts directly (binary diff, unzipped-tree diff, element-by-element). Converge by mutating your output toward the reference until the tool accepts it, then identify which delta was load-bearing.

Done when: either the output works in the target tool, or the exact structural delta the tool rejects is identified and documented — including the case where the tool simply doesn't support the feature (that finding ends the format approach; say so rather than iterating).

## Success criterion

Output renders/functions correctly in the target tool on the first user-facing test — proxy validation may run before that, but never substitutes for it.
