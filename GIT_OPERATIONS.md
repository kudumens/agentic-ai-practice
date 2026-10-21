# Git Operations for n8n AI Agent Lab

This file documents the git procedures used for managing worktrees and branches for different phases of the n8n AI agent lab project.

## Worktree Management

### Creating a New Worktree for a Phase
```bash
# Create a new worktree for a specific phase
git worktree add .claude/worktrees/phase-1-n8n-setup

# Switch to the worktree directory
cd .claude/worktrees/phase-1-n8n-setup
```

### Working in a Worktree
```bash
# Make changes in the worktree
# Commit changes
git add .
git commit -m "Implement Phase 1: n8n setup"

# Push to remote (if needed)
git push origin phase-1-n8n-setup
```

## Git Workflow for This Project

1. **Create worktree**: `git worktree add .claude/worktrees/phase-1-n8n-setup`
2. **Switch to worktree**: `cd .claude/worktrees/phase-1-n8n-setup`
3. **Make changes** in the worktree directory
4. **Commit changes**: `git add . && git commit -m "..."`
5. **Push changes**: `git push origin phase-1-n8n-setup`
6. **Create Pull Request**: `gh pr create` (see below) or the GitHub UI

### Branch Naming Convention

- Use descriptive names like: `phase-1-n8n-setup`, `phase-2-postgres-db`, etc.
- Follow the pattern: `phase-{number}-{description}`
- The remote already has `phase-1-n8n-setup` and `main`. Push with
  `git push origin <branch>` on the first push of a new branch, so the
  upstream is tracked and later pushes work without `-u`.

### Creating the Pull Request

The GitHub CLI is installed and authenticated as `kudumens`, so the pull
request can be created from the terminal instead of the browser:

```bash
# From inside the worktree
gh pr create \
  --base main \
  --head phase-1-n8n-setup \
  --title "Add Phase 1 n8n and PostgreSQL stack" \
  --body-file PR_BODY.md
```

Useful checks afterwards:

```bash
gh pr view <number>                 # view the PR
gh pr list --state all              # list PRs
gh pr diff <number>                 # review the diff
gh pr merge <number> --squash       # merge once reviewed
```

`gh pr merge` is deliberately left to a human. The branch protection on
`main` is not currently enabled, so nothing stops an accidental merge; the
pull request is the review gate.

## Pull Request Template

When creating a pull request for this work, use this template:

```
## Summary

One or two sentences on what the change does.

## What changed

List the files and the reason for each change.

## Why

The reason the change is needed.

## How it was tested

The commands that were run and their results.

## Follow-ups

Anything deliberately left out, and the known gaps.
```

The pull requests already in this repository (PR #1 and PR #2) use this
structure: Summary, What changed, Why, How it was tested, Follow-ups.

## Important Notes
- All worktrees are created under `.claude/worktrees/` directory
- Worktrees contain only the files specific to that phase implementation
- Main branch remains unchanged until PRs are merged
- The root `README.md` is the project overview. Phase-specific documents use
  a different filename (`PHASE1.md`) so that a phase branch cannot overwrite
  the project documentation
- The compose file is `compose.yaml`, matching PLAN.md section 9
- Commands use Docker Compose v2 (`docker compose`), not the deprecated
  `docker-compose` binary