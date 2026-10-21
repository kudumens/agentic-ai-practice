# Git Operations for n8n AI Agent Lab

This file documents the git procedures used for managing branches for the different phases of the n8n AI agent lab project.

## Branch Management

### Creating a branch for a phase
```bash
# Branch from the current main
git checkout main
git pull
git checkout -b phase-1-completion
```

### Working on a branch
```bash
# Make changes
git add .
git commit -m "Complete Phase 1: Ollama credential, model variants, docs"

# Push changes (first push of a new branch)
git push origin phase-1-completion
```

## Git Workflow for This Project

1. **Branch from `main`**: `git checkout -b phase-{n}-{description} main`
2. **Make changes** on the branch
3. **Commit changes**: `git add . && git commit -m "..."`
4. **Push changes**: `git push origin <branch>`
5. **Create Pull Request**: `gh pr create` (see below) or the GitHub UI
6. **Merge** after review: `gh pr merge <number> --squash`

### Branch Naming Convention

- Use descriptive names like: `phase-1-completion`, `phase-2-first-agent`
- Follow the pattern: `phase-{number}-{description}`
- The remote currently has only `main`. Phase branches are deleted from the
  remote once their pull request is merged. Push with `git push origin <branch>`
  on the first push of a new branch, so the upstream is tracked and later
  pushes work without `-u`.

### Worktrees

Earlier phases used a worktree under `.claude/worktrees/`, so that a phase
branch could not overwrite the project documentation. This is no longer
needed: the work is done on a plain branch in the repository root, and
phase-specific documents use a distinct filename (`PHASE1.md`) so they
cannot overwrite `README.md`.

If a worktree is used again:

```bash
git worktree add .claude/worktrees/phase-2-first-agent
cd .claude/worktrees/phase-2-first-agent
# ... work, commit, push, merge ...
git worktree remove .claude/worktrees/phase-2-first-agent
```

The `.claude/worktrees/` directory is gitignored, and its leftovers from
earlier phases have been removed. `git worktree list` should show only the
main working tree when no worktree is in use.

Remember that the compose project name follows the directory name, so a
stack started from a worktree has its own volumes and containers. Migrating
to the root means `docker compose down` in the old directory and
`docker compose up -d` in the new one.

### Creating the Pull Request

The GitHub CLI is installed and authenticated as `kudumens`, so the pull
request can be created from the terminal instead of the browser:

```bash
# From the repository root
gh pr create \
  --base main \
  --head phase-1-completion \
  --title "Complete Phase 1: Ollama credential, model variants, docs" \
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

The pull requests already in this repository (PR #1 through PR #4) use this
structure: Summary, What changed, Why, How it was tested, Follow-ups.

## Important Notes
- Work is done on a branch in the repository root. Branches are created from
  `main`, and `main` is only changed by merging a reviewed pull request
- The root `README.md` is the project overview. Phase-specific documents use
  a different filename (`PHASE1.md`) so that a phase branch cannot overwrite
  the project documentation
- The compose file is `compose.yaml`, matching PLAN.md section 9
- Commands use Docker Compose v2 (`docker compose`), not the deprecated
  `docker-compose` binary
- Real secrets stay in `.env`, which is gitignored. `.env.example` holds the
  variable names only
- The n8n owner account password is not in the repository. It is reset through
  the editor's UI if it is lost