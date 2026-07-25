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

After syncing or validating changes on `dev`, always rebuild and recreate the
affected services with the latest synchronized sources before handing the task
back. A successful `ops/dev-test.sh` run is not proof that its final containers
use the normal development configuration: validation overlays are temporary
and must not be left as the active runtime. Re-run the appropriate controlled
startup script owned by `self-checkout-infra`, wait for every required service
to become healthy, and verify the browser-accessible application and API
endpoints. Synchronizing files without restarting the affected services is
incomplete.

Production accepts only an approved, immutable tag, digest, or release. Never rsync/scp local source to prod, improvise commands on prod, deploy uncommitted changes, run migrations without an approved deployment procedure, or merge automatically. Production access is limited to controlled status/log/health/deploy/rollback operations owned by the infra repository.

## Standard workflow

When asked to implement a feature or fix:

1. Inspect workspace and repository status with `ops/repos-status.sh`.
2. Identify affected repositories and read their `AGENTS.md` files.
3. Fetch remotes with pruning when network access is available.
4. Create matching short-lived branches from `main` with `ops/start-task.sh`; never implement directly on `main` or `master`.
5. Implement focused changes and preserve all pre-existing user changes.
6. Sync and validate on dev with `ops/dev-sync.sh` and `ops/dev-test.sh`.
7. Restore the normal dev runtime from the latest synchronized sources, wait
   for health checks, and verify browser-facing connectivity; never leave
   `compose.validation.yml` active after validation.
8. Review every repository diff, untracked file, and possible secret.
9. Leave changes uncommitted for user review by default.
10. Create separate, atomic Conventional Commits only when the user's prompt
    explicitly requests commits.
11. Create or update pull requests only when the user's prompt explicitly
    requests pull requests.
12. When commits or pull requests are requested, prepare a separate PR summary
    and merge/deployment order for each repository.
13. Never merge, publish a release, or deploy to prod without explicit approval.

Use branch names `feat/…`, `fix/…`, `refactor/…`, `chore/…`, `docs/…`, `test/…`, `ci/…`, `security/…`, or `hotfix/…`. Commit messages must use the English Conventional Commit form `<type>(<scope>): <imperative description>`. Use `ops/check-commits.sh` before committing and `ops/finish-task.sh` before requesting a push.

Commits and pull requests are opt-in actions. Do not infer permission to create
them from a request to implement, fix, validate, or deploy changes to `dev`.
Only create commits or pull requests when the current user prompt explicitly
asks for them.

The configured `workflow_base_branch` in `repos.yaml` is authoritative and is `main` for every application repository. All work enters `main` through short-lived branches and pull requests; do not infer that similarly named branches across repositories share commits or lifecycle. See `docs/git-workflow.md`.

If a working tree is dirty, show the changed and untracked files, determine which belong to the task, and preserve them. Never use `git reset --hard`, `git clean -fd`, automatic stash, force-push, or history rewriting. Stage precise paths or patches instead of broad `git add .` or `git add -A` when unrelated changes exist.

## Pre-1.0 architecture policy

The project is in pre-1.0 development. Backward compatibility with earlier
unreleased development versions is not required. Prefer a coherent, modern
implementation across all current components over compatibility with obsolete
internal versions.

Breaking API, configuration, schema, and infrastructure changes are allowed
when they improve the current architecture. They must be coordinated across
affected repositories, documented, and fully validated on dev. Incorrect or
unused interfaces may be removed, technologies may be replaced, and
development environments may be rebuilt instead of supporting every historic
development migration path.

All current components must work together. Compatibility between the current
version of one component and an older unreleased version of another component
is not required. Tests and documentation describe the current system, and the
pre-1.0 policy never excuses untested changes. Before the first intentional
production release, replace this policy with explicit API stability,
compatibility, versioning, data-migration, and supported-upgrade rules.

Production data must never be modified as part of development validation.

Application code must depend only on a generic S3-compatible object-storage
contract. Do not introduce vendor-specific object-storage names, SDK
assumptions, configuration variables, or infrastructure requirements.

No permanent S3 provider is selected yet. Provider choice must remain an
infrastructure configuration decision that does not require application-code
changes.

Stateful production services are external dependencies. Production application
containers connect to external PostgreSQL, S3-compatible object storage, and
optional MLflow through configuration.

Development runs application services and required development infrastructure
through Docker Compose. S3 connectivity must support an external endpoint and
a replaceable provider overlay without coupling the application to a product.

Data refresh is strictly one-way from production to development. Never create,
suggest, or execute a dev-to-prod data synchronization workflow.

Application data may be copied from production to development without
anonymization. Do not copy infrastructure credentials, secrets, private keys,
environment files, or production system configuration as part of a data
refresh.
