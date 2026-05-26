---
name: writing-beats
description: Shape an article as a journey of beats, choose-your-own-adventure style. The user picks a starting beat from the raw material, you write only that beat, then offer options for where to pivot next, beat by beat, until the article reaches a natural end. Use when the user has raw material and wants to assemble it as a narrative rather than an argument.
codex-compatible: false
---

# Writing Beats

Build an article beat by beat, choose-your-own-adventure style.

## Contract

Consumes: markdown file of raw material (fragments, notes, rough draft)
Produces: article file, built one beat at a time with user choosing direction
Requires: none
Side effects: creates article file at user-specified path
Human gates: user picks starting beat, chooses direction at every step

## Soft Context

Typical workflows: second stage of writing pipeline (alternative to writing-shape), narrative-first article construction
Pairs well with: writing-fragments (produces the input file), humanizer (terminal polish), write-to-obsidian (persist to vault)

## Process

If the user did not say where to save the article, ask once and remember the path.

Then run a beat-by-beat journey:

1. Write 2-3 candidate starting beats, drawn from the raw material. Each is a different entry point into the article. Show the user the beats before writing to the file. Preview what beats that might lead to once written.
2. Once the user picks a starting beat, write only that beat to the article file. Stop there.
3. Re-read the article file from disk. Then offer 2-3 candidate next beats — different directions the journey could pivot to from where the article now stands.
4. Loop steps 2-3 until the article reaches a natural end.

## What is a beat

A beat is one move in the journey. It does one thing — sets a scene, lands a point, asks a question, drops an aside, twists the angle. Then it stops.

A beat is sized by what it needs:

- A single sentence if that's all the move is
- A short paragraph if the move needs setup
- Multiple paragraphs if the beat is a self-contained vignette, argument, or example

If a "beat" needs five paragraphs and three subheadings, it is two beats glued together. Split it.

## Writing rhythm

Append to the article file after each chosen beat. Re-read the file from disk before every write. The user may have edited between turns.

The user can say "cut the last beat", "rewrite that beat sharper", or "go back to the fork" at any time.

## Rules

- Write only the chosen beat. Do not write the next one.
- Do not impose structure on the whole article. The structure emerges from the choices.
- Pull material from the raw pile to populate beats. Paraphrase, split, recombine as needed.
- Do not edit the raw material file. It is read-only.
