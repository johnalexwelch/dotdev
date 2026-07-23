# Session Reflection: "Is toon used?" — grep said no, the running system said yes

**Date**: 2026-07-16
**Goal**: Determine whether `toon` is used anywhere and clean it up if not; ended up enabling it (installed CLI + `optimizer` toggle).

## What Went Well

- Once pointed at the runtime, traced the warning to its exact source (`@xynogen/pix-optimizer/src/json.ts`) and read the gating logic (`enabled && mentionsJson` lazy probe) instead of guessing — gave a precise, correct explanation and corrected my own draft assumption that it was an "unconditional startup probe."
- On "i just enabled it", verified with `which toon` rather than assuming — found they'd installed the binary (`/opt/homebrew/bin/toon`), not just toggled the mode. Smoke-tested the JSON→TOON output before declaring success.

## What Went Wrong / Friction

- **Declared "toon is not used, nothing to clean up" from a source grep** (dotdev repo + skills + config dirs). That sweep omitted the two authoritative sources: installed runtime modules (`~/.pi/agent/npm/node_modules/@xynogen/pix-optimizer`) and the program's live startup diagnostics. The conclusion was wrong.

## Corrections

| # | What the user corrected | Root cause | Owning skill/file |
|---|---|---|---|
| 1 | "but i got this warning when opening pi … toon not found" — rebutted my "not used" verdict | Scoped a usage audit to source grep and concluded before checking the running system (installed deps + live warning) | `cleanup-delivery` (Safety Checks) |

## Ground-truth vs proxy

- **Proxy**: my grep over repo/skills/config → "toon unused." **Authoritative**: the actual `pi` startup warning + the installed `pix-optimizer` module → toon IS wired. Authoritative won.
- **Meta**: this is the *same* proxy-over-ground-truth anti-pattern the previous reflection (2026-07-16-skill-path-and-fix-verification) was about — repeated one arc later. A lesson living only in a reflection doc did **not** change in-session behavior; the reflex has to live in the skill I actually invoke (cleanup-delivery), not a passive artifact.

## Lessons

1. **A "not used / safe to remove" verdict is a claim about the running system, not the source tree.** Before concluding, check installed/runtime deps and live diagnostics (startup warnings, `which`, a runtime probe) — a source grep is a proxy that misses runtime wiring (plugins, extensions, npm modules loaded by the host program).
2. **Reflections don't self-enforce.** Encode the reflex in the operational skill, or it won't fire under time pressure.

## Proposed Improvements

- [ ] `cleanup-delivery/SKILL.md` — Safety Checks: add a check before classifying anything as unused/removable — "verify against the running system (installed runtime deps, live startup diagnostics/warnings, a `which`/runtime probe), not just a source grep; a repo/skills/config search is a proxy that misses host-loaded plugins/extensions/modules." Cite: declared `toon` unused from a source sweep; the pi startup warning (pix-optimizer wiring) disproved it. (priority: **high**)
