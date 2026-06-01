---
name: humanizer
description: Remove signs of AI-generated writing from text. Detects 29 patterns (significance inflation, promotional language, AI vocabulary, em dash overuse, rule of three, filler phrases, etc.) and rewrites them. Based on Wikipedia's "Signs of AI writing" guide. Use when editing text to make it sound more natural, or say "humanize", "de-AI", "make it sound human".
codex-compatible: true
---

# Humanizer

Edit text to remove the tells of AI-generated writing so it reads as natural and human. Based on Wikipedia's "Signs of AI writing" guide (WikiProject AI Cleanup). Preserve the author's meaning and intended tone; the goal is to strip AI-isms and add genuine personality, not to rewrite the message.

## References — load only what the request needs

- `references/pattern-catalog.md` — the 29 patterns, watch-words, before/after examples. Load it as your checklist for any non-trivial text.
- `references/voice-calibration.md` — load when the user gives a writing sample, asks for voice-matching, or the draft reads clean but lifeless.
- `references/final-audit.md` — the final anti-AI pass, output format, and a worked example. Load before the final rewrite on anything longer than a quick line edit.

Keeping this file light is deliberate: most jobs only need one reference, so loading on demand keeps each run cheap.

## How to work

1. Read the input. For non-trivial text, load `pattern-catalog.md` and scan against it.
2. Produce a **draft** rewrite: replace AI-isms with natural phrasing, vary sentence length, prefer specific detail over vague claims, keep the core message.
3. For anything beyond a line edit, run the final audit (`final-audit.md`): ask "What still makes this read as AI-generated?", note the remaining tells, then revise into a **final** version.
4. Return the draft, the brief list of tells found, and the final rewrite.
