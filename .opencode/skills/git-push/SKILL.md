---
name: git-push
description: Use when committing and pushing completed work to the agent's assigned Git repository. Handles per-repo commit, checks, push, and result reporting. Enforces clean, app-only commits with gh-based authentication and no secrets.
---

# Git Push

Commit and push completed work to the agent's assigned Git repository.

## Rules

- Identify the current repository before making Git changes.
- Treat `frontend`, `middle-end`, and `backend` as separate repositories.
- Review `git status` and the diff before staging; stage only files that belong to the current task.
- Run relevant checks/tests before pushing when available.
- Create a clear, concise commit message describing the change.
- Push the commit to the configured remote and branch.
- Report the repository, branch, commit hash, and push result.
- Stop and report an error if the repository, remote, branch, or push state is unclear.

## What Gets Pushed

- Only files that are part of the system or app build: source code, required configs, and assets the app needs.
- Do not push test files, scratch scripts, temp or debug artifacts, logs, or output folders.
- Do not push files unrelated to the system or app. When unsure whether a file belongs, ask the user.

## Secrets and Authentication

- Never commit or embed secrets, tokens, API keys, or credentials in code, configs, or remote URLs.
- Use `gh` (GitHub CLI) for authentication: verify access with `gh auth status` and let gh handle credentials for push and repo operations.
- If a changed file contains secrets, exclude it from the commit and report it to the user instead of pushing.

## Scope Limits

Do not handle project planning, implementation, review, or PR workflows. Those belong to other skills.
