# Cost Spike Postmortem: Delphi green-stone-8433

**Date:** 2026-08-31  
**Cost:** ~$20 (expected: ~$3)  
**Visible output:** "just a terraform script" + Airflow infrastructure  
**Actual work:** 99 commits, 24 fix cycles, 96-file model migration

---

## What Happened

**User expectation:** Write terraform for SageMaker execution role (~$2-3 session).

**Actual session:**

- 99 total commits
- 24 fix commits (debugging loops)
- 96-file monster commit (model migration, 8876 lines)
- 22 commits touched terraform
- Airflow DAG + Docker + CI workflows
- No intent folding, no cost guards

**Cost drivers:**

1. **Context churn** — 99 commits in one worktree = massive repeated reads
2. **Fix cycles** — 24 debugging loops (fail → retry → fail → retry)
3. **No guards** — unbounded session, no max_cost_usd, no folding
4. **Large reads** — 96-file commit means reading thousands of lines repeatedly

---

## Why It Looked Small

**Terraform output was 449 lines.** But hidden work:

- 8876 lines in model migration
- 24 fix iterations
- Airflow + Docker + IAM + CI
- 99 commits of context loading

**Terraform was the visible artifact, not the scope.**

---

## Root Cause

**No intent folding.**

Without guards:

- No max_cost_usd hard stop
- No token threshold folding
- No turn count warnings (loop detection)
- No audit trail

Session grew unbounded → $20.

---

## Prevention

### 1. Use intent for ALL delphi work

```bash
cd ~/projects/delphi
piid  # alias for: pi --intent ~/.pi/intents/delphi-work.yaml
```

**Guards in delphi-work.yaml:**

- `max_cost_usd: 5.00` — hard stop at $5 (not $20!)
- `max_turns: 50` — warn after 50 turns (detect loops)
- Fold at 32K tokens → compress to 2K summary

### 2. CI enforcement

`.github/workflows/verify-intent-evidence.yml` now blocks PRs without intent evidence for:

- Research/investigation work
- Multi-file changes (>10 files)
- Comprehensive/exhaustive tasks

### 3. Post-session audit

```bash
cd ~/.pi/agent/extensions/pi-intent-folding
npm run audit -- <session-id>
```

Verifies:

- Intent was loaded
- Guards enforced
- Folds executed
- No violations

---

## Lessons

**1. Visible output ≠ session scope**

"Just terraform" hid:

- Model migration
- 24 debugging cycles
- Infrastructure scaffolding

**2. Fix cycles burn tokens fast**

24 fix commits = 24× context reload + retry.  
Each cycle: read files → attempt fix → run check → fail → read again.

**3. Guards prevent runaway cost**

Without `max_cost_usd`, sessions grow unbounded.  
$5 guard would've stopped at $5, not $20.

**4. Turn count detects loops**

50-turn soft guard would've flagged after ~15 fix cycles:  
"You've hit 50 turns — possible loop?"

---

## Action Items

- [x] Create `delphi-work.yaml` intent ($5 cap, 32K fold)
- [x] Add to ~/.pi/intents/
- [x] Document usage in README
- [ ] Add delphi-specific routing hint (workflow-router)
- [ ] Dogfood: use intent for next 3 delphi sessions
- [ ] Measure: compare cost with/without intent

---

## References

- [Intent Folding Guide](../pi-intent-folding-guide.md)
- [Delphi Worktree](~/.herdr/worktrees/delphi/worktree-green-stone-8433)
- [Latest Handoff](~/.herdr/worktrees/delphi/worktree-green-stone-8433/docs/executions/handoffs/2026-08-31-airflow-training.md)
- PR #230: Enforcement layer (telemetry, audit, CI gate)

---

**Prevention:** Use intent. Always.
