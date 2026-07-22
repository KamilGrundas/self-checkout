# Self-checkout workspace instructions

This directory is a control workspace containing five independent Git repositories. The parent Git repository stores only workspace instructions, orchestration scripts, shared documentation, and repository inventory. It is not the source of truth for application code.

## Repository boundaries

- `self-checkout-admin`: React/Vite admin UI.
- `self-checkout-backend`: FastAPI application.
- `self-checkout-client`: Rust/Iced kiosk client.
- `self-checkout-infra`: Docker Compose, service topology, infrastructure health checks, deployment, and rollback source of truth.
- `self-checkout-ml`: FastAPI ML service.

Before editing, name every affected repository, run `ops/repos-status.sh`, and read that repository's `AGENTS.md`. Use `git -C <path>` for every application-code Git operation. Never make a cross-repository commit, assume matching SHAs/branches, or automatically merge changes.

If an affected repository is dirty, show its existing changes before editing it. Create corresponding task branches independently in every affected repository. Each repository keeps its own commits, tags, remote, PR, tests, and review. For multi-repository work, document merge and deployment order.

## Runtime rules

Docker is not installed locally and must never be invoked on the MacBook. Run Docker, Docker Compose, integration tests, application startup, and health checks only on the host reached through `ssh dev`, using scripts under `ops/` and controlled scripts owned by `self-checkout-infra`.

Compose files are `self-checkout-infra/compose.yml`, `compose.override.yml`, and optionally `compose.mlflow.yml`. Preserve their sibling build-context layout. Never install Codex on dev or prod.

Production accepts only an approved, immutable tag, digest, or release. Never rsync/scp local source to prod, improvise commands on prod, deploy uncommitted changes, run migrations without an approved deployment procedure, or merge automatically. Production access is limited to controlled status/log/health/deploy/rollback operations owned by the infra repository.

## Standard workflow

When asked to implement a feature or fix:

1. Inspect workspace and repository status with `ops/repos-status.sh`.
2. Identify affected repositories and read their `AGENTS.md` files.
3. Fetch remotes with pruning when network access is available.
4. Create matching short-lived branches with `ops/start-task.sh`; never implement directly on `main`, `master`, or `dev`.
5. Implement focused changes and preserve all pre-existing user changes.
6. Sync and validate on dev with `ops/dev-sync.sh` and `ops/dev-test.sh`.
7. Review every repository diff, untracked file, and possible secret.
8. Create separate, atomic Conventional Commits in each repository.
9. Prepare a separate PR summary and merge/deployment order for each repository.
10. Stop before push unless the user explicitly instructs otherwise.
11. Never merge, publish a release, or deploy to prod without explicit approval.

Use branch names `feat/…`, `fix/…`, `refactor/…`, `chore/…`, `docs/…`, `test/…`, `ci/…`, `security/…`, or `hotfix/…`. Commit messages must use the English Conventional Commit form `<type>(<scope>): <imperative description>`. Use `ops/check-commits.sh` before committing and `ops/finish-task.sh` before requesting a push.

The configured `workflow_base_branch` in `repos.yaml` is authoritative. It is temporarily `dev` while the existing development history is migrated to `main`; do not infer that similarly named branches across repositories share commits or lifecycle. See `docs/git-workflow.md`.

If a working tree is dirty, show the changed and untracked files, determine which belong to the task, and preserve them. Never use `git reset --hard`, `git clean -fd`, automatic stash, force-push, or history rewriting. Stage precise paths or patches instead of broad `git add .` or `git add -A` when unrelated changes exist.
