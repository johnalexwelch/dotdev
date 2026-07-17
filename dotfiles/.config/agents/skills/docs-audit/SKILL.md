---
name: docs-audit
model: sonnet
reasoning: high
description: 'Audits documentation drift across a repo: docs that no longer match the code, each other, or the agent-facing entry points, plus skill-frontmatter/invocation drift in this skills library. Checks completeness, accuracy, freshness, and coherence against whatever doc convention the repo actually uses (ADR/PRD/decision-log, or llms.txt/AGENTS.md/openwiki, or both) — not a fixed layout. Use for periodic doc-health checks, "audit docs", "check documentation", "are docs up to date", "doc drift", or after adding a new doc-generating tool.'
---

# Docs Audit

## Contract

Consumes: repo docs (whatever exists — README, AGENTS.md/CLAUDE.md, llms.txt, openwiki/, docs/adr, docs/decision-log.md, docs/roadmaps, SKILL.md files), git history
Produces: severity-tiered drift report; `fix`/`full` modes also edit files and commit
Requires: git
Side effects: `audit` mode none; `fix`/`full` modes edit docs and commit; `full` additionally writes a roadmap
Human gates: `fix`/`full` only auto-correct mechanical drift (paths, links, counts, staleness metadata); anything needing judgment is reported, not edited

## Context

Typical workflows: periodic maintenance, after wiring a new doc-generating tool (openwiki, hunk, etc.), before/after a `repo-audit`'s docs+handoff lane
Pairs well with: decision-log, to-prd (ADR promotion), repo-audit (broader state-of-repo — use that for a full investigation, this for a fast doc-drift pass), write-a-skill (skill hygiene checks below reuse its review checklist)

## Purpose

Docs drift from three things independently: the code they describe, each other, and the entry points agents actually read first. Most drift is silent — a stale path or a contradiction between two docs doesn't error, it just quietly misleads the next agent. This skill surfaces that drift with evidence, not opinion.

## Mode detection

| User intent | Mode | Trigger phrases |
| --- | --- | --- |
| Check health | **audit** (default, read-only) | "audit docs", "check documentation", "are docs up to date", "doc drift" |
| Fix mechanical issues | **fix** | "fix docs", "sync docs", "update documentation" |
| Fix + roadmap | **full** | "full doc audit", "doc audit with roadmap" |

Default to **audit** when ambiguous.

## Step 1 — Detect which doc families exist

Don't assume one convention — this repo (and others it's copied to) may use several at once. Check for each, additively:

| Family | Detect via | Governing skill/convention |
| --- | --- | --- |
| Agent entry points | `AGENTS.md`, `CLAUDE.md` at root (symlink pair, independent files, or pointer stubs to a generated wiki — all valid) | — |
| Generated wiki | `openwiki/`, `llms.txt`, `.last-update.json` | this repo's `dotfiles/.config/openwiki/USAGE.md` |
| ADRs | `docs/adr/`, `docs/adrs/`, `docs/decisions/` | `to-prd` step 2c (ADR promotion) |
| Decision log | `docs/decision-log.md` or a documented local equivalent (check nested `*/docs/decision-log.md` in monorepos) | `decision-log` skill's Canonical Location |
| PRDs/roadmaps | `docs/roadmaps/YYYY-MM-DD-*.md` (local); PRDs themselves live as tracker issues, not files — don't expect a local PRD file | `to-prd`, `workflow-roadmap` |
| Classic | `ARCHITECTURE.md`, `README.md`, `docs/` | — |
| Skills library | `*/SKILL.md` under the shared skills root | `write-a-skill` |

Only run the dimension checks below for families actually present. A repo with none of ADR/decision-log/openwiki isn't broken — it just has less to check.

```bash
for f in AGENTS.md CLAUDE.md llms.txt openwiki README.md ARCHITECTURE.md; do [ -e "$f" ] && echo "found: $f"; done
find . -maxdepth 3 \( -path "*/docs/adr*" -o -path "*/docs/decisions*" -o -name "decision-log.md" -o -path "*/docs/roadmaps" \) -not -path "*/node_modules/*" 2>/dev/null
```

## Step 2 — Assess each dimension

### Completeness — are the artifacts that should exist actually there?

- Root entry point (AGENTS.md/CLAUDE.md) has real content, not an empty stub with no target — if it's a pointer stub, does the thing it points to (openwiki/, docs/) actually exist?
- If ADRs are referenced from decision-log/PRD entries, do the referenced ADR files exist on disk?
- `llms.txt` present when the repo has a public doc set worth indexing for agents (skip for private-only repos — this is a completeness question, not a mandate).
- Does the human-facing front door (README) actually link the agent-facing entry points (`llms.txt`/`AGENTS.md`/generated wiki)? A doc set that's individually complete but not cross-linked from the front door fails completeness in practice — nobody finds it.

### Accuracy — do docs match reality?

```bash
# paths quoted in docs actually exist
grep -oE '`[^`]+/[^`]*`' AGENTS.md CLAUDE.md ARCHITECTURE.md 2>/dev/null | tr -d '`' | while read -r p; do [ ! -e "$p" ] && echo "MISSING: $p"; done

# commands referenced actually exist (package.json scripts, Makefile targets)
grep -oE '(npm|pnpm|yarn|make|cargo|go) [a-z:-]+' AGENTS.md CLAUDE.md README.md 2>/dev/null | sort -u

# ports/versions drifted between docs and config
grep -oE '[0-9]{4,5}' docker-compose.yml .env.example 2>/dev/null | sort -u
```

For the generated-wiki family, verify every link resolves (this is what caught our own `llms.txt` gap — check both repo-relative and `raw.githubusercontent.com` forms):

```bash
grep -oE '\(https://raw\.githubusercontent\.com/[^/]+/[^/]+/main/[^)]+\)' llms.txt 2>/dev/null | sed -E 's#\(https://raw\.githubusercontent\.com/[^/]+/[^/]+/main/##; s#\)$##' | while read -r p; do [ ! -e "$p" ] && echo "MISS: $p"; done
```

### Freshness — has upkeep kept pace with change?

```bash
for f in AGENTS.md CLAUDE.md ARCHITECTURE.md docs/decision-log.md openwiki/.last-update.json; do
  [ -f "$f" ] && echo "$f: $(git log -1 --format='%ai (%ar)' -- "$f" 2>/dev/null)"
done
echo "HEAD: $(git log -1 --format='%ai (%ar)')"
git log --since="30 days ago" --diff-filter=A --name-only --pretty=format:"" 2>/dev/null | grep -vE '\.md$' | sort -u | head -20
```

For openwiki specifically: compare `.last-update.json`'s recorded HEAD sha against current HEAD — large gaps mean the wiki is stale and `openwiki code --update` is overdue. Note: running `--update` can also silently revert hand-hardened files it considers its own scope (seen with `.github/workflows/openwiki-update.yml`) — diff its output before trusting it.

### Coherence — do the docs agree with each other and with entry-point conventions?

```bash
# broken relative markdown links, repo-wide
for doc in $(find . -maxdepth 4 -name "*.md" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null); do
  grep -oE '\[.*\]\([^)]+\.md[^)]*\)' "$doc" 2>/dev/null | grep -oE '\([^)]+\)' | tr -d '()' | sed 's/#.*//' | while read -r ref; do
    dir=$(dirname "$doc"); [ ! -f "$dir/$ref" ] && [ ! -f "$ref" ] && echo "BROKEN in $doc: $ref"
  done
done

# duplicate content: same section heading in 2+ files not cross-referencing each other
grep -rhoE '^#{1,2} .+' --include="*.md" . 2>/dev/null | sort | uniq -c | sort -rn | awk '$1>1'

# filename collisions: anything literally named CLAUDE.md/AGENTS.md that isn't a recognized entry point (confusable with the real agent-instruction convention)
find . -iname "CLAUDE.md" -o -iname "AGENTS.md" 2>/dev/null | grep -v node_modules
```

Two additional checks folded in from the CLAUDE.md-token-optimization research (not a separate tool — same dimension, same report):

- **Thin link vs rich abstract.** A reference like "see docs/testing.md" with no synopsis gets opened on every ambiguous question; a 2-3 sentence concrete summary (framework, convention, threshold) plus the link lets an agent answer most questions without opening it. Flag thin links in always-loaded files (AGENTS.md/CLAUDE.md) as coherence findings, not just missing-content ones.
- **Size drift.** `AGENTS.md`/`CLAUDE.md` past ~200 lines, or a `SKILL.md` past 500 lines, degrades adherence (Anthropic's own guidance) — flag for progressive-disclosure split. `wc -l AGENTS.md CLAUDE.md */SKILL.md | sort -rn | head`.

### Skill-library hygiene (when a `skills/` family is present)

Reuse `write-a-skill`'s review checklist as the check, not a second implementation:

```bash
python3 -c "
import yaml, glob
for f in glob.glob('*/SKILL.md'):
    fm = yaml.safe_load(open(f).read().split('---',2)[1])
    desc = (fm.get('description') or '').lower()
    if ('deprecated' in desc or 'standalone use' in desc) and not fm.get('disable-model-invocation'):
        print(f'{f}: description says deprecated/standalone-only but still model-invocable')
"
```

Also check: any skill still referenced by name from another skill's process steps whose own description says it's superseded (contradiction — cross-grep the replacement skill's name against skills that still call the old name directly).

## Step 3 — Report

Severity: **Critical** (actively misleading — wrong path, contradictory instructions, dead skill still auto-firing), **Warning** (stale, incomplete, thin link on a load-bearing doc), **Info** (minor drift, nice-to-have gaps). Cite the file and, where possible, the line.

## Mode: fix

Run the audit, then auto-correct only mechanical drift: broken relative links to a renamed-not-deleted target, path/port/count updates where the new value is unambiguous, missing skill `disable-model-invocation` when the description already says deprecated, missing cross-links from a front-door doc to an existing entry point. State before/after for each edit, then commit:

```bash
git add -A && git commit -m "docs-audit: <summary of fixes>"
```

Anything needing judgment (new content, restructuring, deciding whether a superseded skill should be deleted vs kept as a fallback) is reported, not edited.

## Mode: full

Run `fix`, then produce a prioritized roadmap: Priority 1 accuracy fixes, Priority 2 coverage gaps, Priority 3 structural improvements (splits, reorganization), Priority 4 process improvements (CI doc-freshness checks, a recurring `docs-audit` cadence). Each item specific enough to hand to an agent as-is.
