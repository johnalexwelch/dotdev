# Wiring-verification method — how we prove every skill/hook/router is actually invoked

Research asset for [ticket #70](https://github.com/johnalexwelch/dotdev/issues/70) (map [#68](https://github.com/johnalexwelch/dotdev/issues/68)). 2026-07-09.

## Question

What signal proves a skill / hook / persona / router is actually wired at runtime — never silently dead, never ambiguously wired so the model ignores it — across **pi / claude / codex**? Produce a repeatable check a later session can add to CI.

## Key finding: "wired" is two different claims, proven by two different signals

| Claim | Meaning | Deterministic in CI? | Signal |
|---|---|---|---|
| **Reachable** | The piece exists on disk, parses, and is registered where the harness looks. Catches *silently dead* (drift, missing symlink, unsynced codex). | **Yes** | static audit + hook-fire smoke test |
| **Invoked** | A live session actually fired it. Catches *ambiguously wired* (loaded but the model never picks it). | **No** — forcing a model to invoke is non-deterministic | telemetry (Langfuse / pi-observability), sampled |

You cannot force a model to invoke a skill in CI, so "invoked" can never be a green/red gate. Split the problem: **CI proves reachable; telemetry proves invoked.** Chasing a single runtime CI gate is the trap this ticket exists to avoid.

## Decision: two-layer method

### Layer 1 — Static wiring audit (the one runnable CI check)

One script enumerates every piece and asserts it is reachable in each harness. Runs offline, no model, deterministic → the CI gate. Covers:

- **Skills discoverable** — every `dotfiles/.claude/skills/*/SKILL.md` has valid frontmatter (`name`, `description`) and resolves in each harness's skill path: claude `~/.claude/skills` (recursive), pi `skills:["~/.claude/skills"]`, codex `~/.codex/skills`.
- **Codex sync clean** — `sync-codex-skills.sh` dry-run produces an empty diff (minus `codex-runtime-allowlist.txt` entries). A non-empty diff = codex drifted = silently dead there. **This is the FIND-27 graduation**: codex verification today = "sync dry-run clean," runtime deferred (no codex trace sink yet).
- **Router labels match intent** — the set of skills carrying `disable-model-invocation: true` (12/85 today) equals the set `workflow-router` is meant to gate. Audit enforces whatever set **#71** decides — #71 picks it, this check locks it.
- **Hook scripts exist + executable** — every `command` hook in claude `settings.json` points to an existing `+x` script; pi hook packages (`pi-permission-gate`, `pi-dirty-repo-guard`) present in the packages list.
- **Symlinks resolve** — `.agents/skills` precedent targets (`find-skills`, `herdr`) are not dangling.

### Layer 2a — Hook-fire smoke test (also CI-runnable)

Hooks are the one piece you *can* exercise deterministically offline: they are shell scripts reading stdin JSON. Feed each hook its trigger payload; assert exit code + stdout marker (e.g. `workflow-guard.sh` fed a `ready-for-agent`+PRD `gh issue edit` → exit 2 / "Blocked:"). This is what turns "enforcement unverified" (git-guardrails / pi-dirty-repo-guard / pi-permission-gate) into proven. Belongs in CI alongside Layer 1.

### Layer 2b — Runtime invocation evidence (telemetry, NOT CI)

Proves a piece actually fired in real sessions. Sampled / dashboard, not a gate.

- **claude** — **Langfuse** (`TRACE_TO_LANGFUSE=true`, `192.168.4.43:3050`) is ground truth: every Skill/tool/hook call is traced. Query "was skill X invoked in the last N sessions." Hook stdout markers in transcript are the cheap in-session tell.
- **pi** — `pi-observability` session events + `pi-tool-display` surface invocation in-session; `pi-observational-memory` gives a persisted per-session record.
- **codex** — no trace sink → runtime evidence N/A until one exists. Static-only for now (see FIND-27 graduation above).

## What this graduates / backs

- **FIND-27 (codex wiring fog)** → graduates: codex verification = sync-dry-run-clean now; runtime deferred until a codex trace sink lands. Fog can become a concrete ticket.
- **#71 (router-exclusivity)** → the static audit *enforces* the `disable-model-invocation` set; #71 only needs to decide the set.
- **Hook enforcement** ("unverified") → the hook-fire smoke test is the proof.

## Handoff for the cleared route

This is infra/tooling → per map Notes, route the *build* via `/design-plan` → `/execute-phase`. Two shippable pieces: (1) `scripts/verify-wiring.sh` (Layer 1 + 2a) added to the Lint/CI workflow; (2) a documented Langfuse/pi-observability query recipe (Layer 2b) — not automated, run when confidence is needed. Building them is downstream delivery, not this ticket (wayfinder plans, doesn't do).

### Runnable-check spec (for the later session)

`scripts/verify-wiring.sh` — exit non-zero on any failure:

1. For each `SKILL.md`: assert `---` frontmatter parses and has `name:` + `description:`.
2. `SOURCE_SKILLS_DIR=... sync-codex-skills.sh` (dry-run): assert diff is empty modulo allowlist.
3. Assert `{disable-model-invocation:true}` skill set == the #71-decided list (checked-in manifest).
4. For each claude `settings.json` `command` hook: assert referenced script exists and is `+x`.
5. Resolve every symlink under `.claude/skills`; fail on dangling.
6. Hook-fire: pipe canned trigger JSON to each hook; assert expected exit/marker.
