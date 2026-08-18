---
name: workflow-debug
disable-model-invocation: true
description: Superseded by workflow-deliver (D-006 #11, 2026-08-18). Do not invoke; Load and run workflow-deliver with kind=bug instead.
---

# Workflow Debug — superseded

Merged into `workflow-deliver` on 2026-08-18 (D-006 #11): one orchestrator, kind-templated ledger gates. For bug work, Load and run `workflow-deliver/SKILL.md` with `kind=bug` — the kernel inserts required `diagnose`/`fix` steps and refuses `stamp fix` without a red repro, which is what the old diagnose-first cardinal rule enforced by prose. This directory remains only until Phase 4/5 rewires remaining callers; do not add content here.
