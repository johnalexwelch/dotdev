---
name: ci-deploy-fix
description: Use when a GitHub Actions CI or deployment workflow has failed and needs diagnosis, code fixes, and a PR with the solution. Triggers on "CI failed", "build broke", "deploy failed", "fix the red check", "pipeline is failing", "CI is red". Covers lint, type errors, test failures, build failures, migration errors, k8s manifest issues, and deploy-time problems.
---

# CI & Deploy Failure Fix

Diagnose CI/deployment failures, fix code/config/manifests, and open a PR with structured reasoning.

## When to Use

- CI pipeline failed (lint, typecheck, test, build, security scan)
- Deployment workflow failed (image build, migration, k8s deploy, skaffold)
- You see a red check on a branch or PR
- `gh run list` shows a failed run

**When NOT to use:** Infra/permissions issues (IAM, ECR login, runner availability) — diagnose only, escalate to human.

## Workflow

```
Identify failed run -> Pull failure logs -> Classify failure
  -> [fixable?]
     YES: Create fix branch -> Apply fix -> Verify locally -> Push branch / Open PR
     NO:  Post diagnosis comment
  -> Always: Comment on original PR/commit with structured analysis
```

## Step 1: Identify the Failed Run

```bash
# List recent failures for a specific workflow
gh run list --workflow=ci.yml --status=failure --limit=5
gh run list --workflow=publish.yml --status=failure --limit=5

# Or find the latest failure on a branch
gh run list --branch=main --status=failure --limit=3
```

Pick the run ID. If the user provides a PR number, find its branch and check runs on that branch.

## Step 2: Pull Failure Logs

```bash
# Failed job logs only (fastest path to root cause)
gh run view <RUN_ID> --log-failed 2>/dev/null | tail -300

# List jobs to see which failed
gh run view <RUN_ID> --json jobs --jq '.jobs[] | select(.conclusion == "failure") | .name'

# Full logs for a specific job (when --log-failed is insufficient)
gh run view <RUN_ID> --log | grep -B5 -A50 "error\|Error\|FAILED\|fatal"
```

**For deploy failures**, also check:

- The workflow file itself (`publish.yml`) to understand the pipeline stages
- Recent commits on main that may have introduced the issue
- Migration files if the failure is in the migration step

## Step 3: Classify the Failure

### CI Failures

| Type | Signals | Fix approach |
|------|---------|-------------|
| **Lint** | `ruff check`, ESLint errors, import sorting | Run `ruff check --fix`, `eslint --fix` |
| **Type error** | `mypy`, `tsc --noEmit`, Pyright errors | Fix type annotations, add type guards |
| **Test failure** | `pytest`, `vitest` assertion errors | Read test + source, fix logic |
| **Build failure** | Docker build, missing deps, import errors | Fix imports, update deps, fix Dockerfile |
| **Security scan** | Trivy HIGH/CRITICAL CVE | Update dependency version |

### Deploy Failures

| Type | Signals | Fix approach |
|------|---------|-------------|
| **Image build** | Docker build fails during deploy | Same as CI build failure |
| **Migration** | Alembic errors, SQL failures, timeout | Fix migration file, add guards |
| **K8s manifest** | kubectl apply errors, invalid YAML | Fix k8s YAML in `k8s/` directory |
| **Skaffold** | skaffold build/deploy errors | Fix `skaffold.yaml` or profile config |
| **Infra/permissions** | ECR login, IAM, EKS auth | **Diagnose only** — cannot fix from code |
| **Resource** | OOM, pod scheduling, timeout | **Diagnose only** — needs infra change |

### Fixable vs. Diagnose-Only

**Fixable from code:** Lint, types, tests, builds, migrations (schema), k8s manifests, skaffold config, dependency versions.

**Diagnose only (escalate):** IAM/permissions, ECR registry issues, runner availability, networking, resource limits, secrets management. Post a diagnosis comment explaining root cause and what the human needs to do.

## Step 4: Create Fix Branch

Use git worktrees for isolation (project convention):

```bash
# CI failure on a feature branch
git worktree add ../iris-fix-ci-<description> -b fix/ci-<description> origin/<failing-branch>
cd ../iris-fix-ci-<description>

# Deploy failure on main
git worktree add ../iris-fix-deploy-<description> -b fix/deploy-<description> origin/main
cd ../iris-fix-deploy-<description>
```

Fallback if worktrees unavailable: `git checkout -b fix/<description> origin/<ref>`

## Step 5: Apply and Verify the Fix

**CI fixes — verify with the same tool that failed:**

```bash
# Lint
cd backend && ruff check src/ tests/ --fix
cd frontend && npx eslint src/ --fix

# Type check
cd backend && mypy src/
cd frontend && npx tsc --noEmit

# Tests
cd backend && pytest tests/ -x -v
cd frontend && npx vitest run
```

**Deploy fixes — verify what you can locally:**

```bash
# Migration: test against local DB
cd backend && alembic upgrade head

# K8s manifests: validate YAML
kubectl apply --dry-run=client -f k8s/staging/

# Docker build: test the build stage
docker build --target runtime ./backend
```

**Cannot verify locally:** Skaffold deploys, actual k8s deployments, ECR pushes. Note this in the PR.

## Step 6: Push Branch and Open PR

Push the fix branch. Ask the user before creating a PR — some prefer push-only.

```bash
git push -u origin fix/<description>

# If user wants a PR:
gh pr create --base <target-branch> --head fix/<description> \
  --title "fix(<scope>): <what was fixed>" \
  --body "$(cat <<'EOF'
## Diagnosis

**Failed workflow:** <workflow name> — Run #<RUN_ID>
**Failed job(s):** <job names>
**Failure type:** <classification from Step 3>

## Root Cause

<Specific explanation of what went wrong and why, citing log lines>

## Fix

<What was changed and reasoning>

## Verification

- [ ] <What was verified locally>
- [ ] <What cannot be verified locally and needs CI/deploy to confirm>

## Log excerpt

```

<relevant error lines from the failure>
```

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"

```

## Step 7: Comment on Original PR/Commit

Always post a diagnosis comment, even if you opened a fix PR:

```bash
# If there's an associated PR
gh pr comment <PR_NUMBER> --body "## CI/Deploy Failure Diagnosis

**Run:** #<RUN_ID> — **Status:** <fixed in PR #X | needs manual intervention>
**Failure type:** <classification>

### Root Cause
<explanation>

### Resolution
<link to fix PR, or manual steps needed>"
```

For failures on main (deploy), comment on the merge commit:

```bash
gh api repos/<owner>/<repo>/commits/<SHA>/comments \
  -f body="## Deploy Failure Diagnosis ..."
```

## Common Patterns

**Migration: column already exists**
→ Add `IF NOT EXISTS` guard, or check if migration was already partially applied.

**Migration: relation does not exist**
→ Check migration ordering. May need to merge or reorder migrations.

**Ruff import sorting (I001)**
→ `ruff check --select I --fix` then re-stage.

**Docker build: module not found**
→ Check if new dependency was added to `pyproject.toml`/`package.json` but not in the Docker stage.

**K8s: image pull error**
→ Diagnose only. Usually ECR login or image tag mismatch. Note the expected vs actual image tag.

**Trivy CVE**
→ Update the flagged dependency. Check if the update has breaking changes.
