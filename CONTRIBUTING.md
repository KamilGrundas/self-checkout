# Contributing

This workspace coordinates five independent repositories. A system change may require multiple branches, commits, and pull requests; it is never one cross-repository commit.

## Start work

1. Run `./ops/repos-status.sh` and identify only the affected repositories.
2. Read `AGENTS.md` here and in each affected repository.
3. Use `./ops/start-task.sh --type <type> --name <name> --repos <keys>` to fetch and create independent short-lived branches.
4. Keep existing user changes intact. Stop if a repository is dirty or has an active merge, rebase, cherry-pick, or revert.

Allowed branch types are `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `ci`, `security`, and `hotfix`. Include a task identifier when one exists, for example `feat/SC-123-payment-flow`.

## Validate and commit

Run Docker, Compose, integration tests, and application health checks only on remote `dev` through the workspace scripts. Use `./ops/finish-task.sh --repos <keys>` for the final review and validation.

Commits use English Conventional Commits:

```text
<type>(<scope>): <short imperative description>
```

Keep implementation and its essential tests together. Separate unrelated tooling, documentation, infrastructure, migrations, or refactoring when that improves reversibility. Stage exact files or patches and inspect `git diff --cached` before every commit.

## Pull requests

Create a separate PR for every repository. Record dependent PRs, validation evidence, rollback, and merge/deployment order. The preferred merge method is squash merge with a valid Conventional Commit title.

Codex may create local branches and commits after successful validation, but must stop before push or PR creation unless explicitly instructed. Merge, release publication, remote settings, and production deployment always require separate approval.

See [docs/git-workflow.md](docs/git-workflow.md) and [docs/releases.md](docs/releases.md).
