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

The three SSH targets have separate responsibilities:

- `ssh dev` is the main development server. Docker, Docker Compose, integration
  tests, development services, health checks, backend services, and
  browser-facing application validation run only there through scripts under
  `ops/` and controlled scripts owned by `self-checkout-infra`.
- `ssh prod` is production. Its existing immutable-release, controlled
  status/deploy/rollback, and source-synchronization restrictions remain in
  force.
- `ssh dev-client` is an optional, replaceable target computer for direct
  Rust/Iced client testing. It is not a Docker or general integration host. Check it
  non-interactively with a bounded timeout before every synchronization or
  validation operation. Its unavailability skips only device work and never
  blocks local client implementation or validation.

Docker is not installed locally and must never be invoked on the MacBook.
Never install Codex on `dev`, `prod`, or `dev-client`. Do not introduce Docker
on `dev-client` unless read-only inspection proves that the established client
workflow intentionally uses it there.

Compose files are `self-checkout-infra/compose.yml`, `compose.override.yml`, and optionally `compose.mlflow.yml`. Preserve their sibling build-context layout.

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

Local uncommitted `self-checkout-client` sources may be synchronized to
`dev-client` for testing. Synchronize only client build inputs and explicitly
required non-secret runtime configuration. Preserve `.env`, device identity,
persisted settings, credentials, device startup files, and unmanaged
configuration unless the task explicitly requires a reviewed change. Device
synchronization never authorizes a commit, push, pull request, merge, release,
or production deployment.

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

## Client target-device workflow

For changes affecting `self-checkout-client`:

1. Inspect workspace and repository state, read the root and client
   `AGENTS.md` files, and preserve existing changes.
2. Implement locally and run supported local `cargo fmt --check`,
   `cargo clippy --all-targets --all-features -- -D warnings`, `cargo check`,
   and `cargo test` checks. A lack of device access must not block this work.
3. Check `dev-client` using `ops/dev-client-check.sh --optional`, which uses
   batch-mode SSH and a bounded connection timeout.
4. If unavailable, report device synchronization, build, restart, and
   validation as `SKIPPED` and continue with local validation.
5. If reachable, read the cached target profile with
   `ops/dev-client-inspect.sh`. If the profile is absent, stale, or inconsistent
   with live identity checks, perform read-only discovery once and replace it
   with `ops/dev-client-inspect.sh --refresh`. The device-owned profile records
   non-secret OS, architecture, toolchain, packages, paths, permissions,
   graphical/runtime environment, startup mechanism, logs, and endpoint facts
   so ordinary tasks do not rescan unchanged target details.
6. Dry-run and apply `ops/dev-client-sync.sh`. It may synchronize uncommitted
   client build inputs, but it must exclude Git metadata, targets, caches,
   `.env` files, secrets, device identity, persisted settings, and unrelated
   repositories.
7. Use `ops/dev-client-deploy.sh` to build the latest synchronized sources on
   the target, retain the prior binary for simple rollback, restart through the
   inspected existing startup mechanism, and verify the running executable
   hash against both the build and source metadata. Do not merely copy files
   while leaving an old binary running.
8. Use `ops/dev-client-status.sh` to check the process, immediate stability,
   observable logs/output targets, graphical-session variables, deployment
   metadata, development API connectivity, and checkout-counter
   authentication. Once the host is reachable,
   synchronization, build, authentication, configuration, restart, or runtime
   failures are real failures and must not be hidden by optional-host handling.
9. Review all local diffs and device-side changes, and leave repository changes
   uncommitted unless commits are explicitly requested.

Do not assume a graphical session, display protocol, username, home directory,
source path, service manager, or launch mechanism. Reuse what inspection finds;
do not create a new service when the existing mechanism is suitable. Package
changes must be minimal, directly related to the client, and documented. Do not
run broad upgrades or use `sudo` unless the established build/install workflow
requires it. Destructive device reconfiguration needs explicit approval.

Remote checks can prove process state, logs/output routing, hashes, exit status,
session prerequisites, and API connectivity. They cannot prove physical
display, touch, camera, scale, or complete kiosk behavior; record the remaining
visual/hardware confirmation for the user at the target computer.

`dev-client` must always use development services hosted by `dev`.
`API_BASE_URL` and `ML_API_BASE_URL` on the target must resolve, directly or
through a controlled development-only route, to the backend and ML API running
on `dev`. Never use loopback services on `dev-client`, the control computer as
an application backend, or any production endpoint. Treat failed connectivity
to `dev` as a real target validation failure.

The backend on `dev` and a reachable `dev-client` must be configured together.
Before target validation, verify that the development backend contains a
dedicated checkout-counter authorization for the target (use the stable name
`dev-client` unless the device profile records another explicit name) and that
the matching ID and password are present only in the device-owned runtime
configuration. If the authorization is absent or the credentials no longer
work, create or rotate that development-only authorization and update the
device atomically with `ops/dev-client-authorize.sh`. Never put credentials in
the target profile, documentation, command output, or repository files.

After every change that affects the running system, restore and validate the
normal environment on `dev`. For client-affecting changes, also synchronize,
rebuild, restart, and validate the client against those same `dev` services
when `dev-client` is reachable. The task is complete only when the affected
parts work together on `dev` and, when available, `dev-client`; if the optional
host is unavailable, record only that target portion as skipped.

Use branch names `feat/…`, `fix/…`, `refactor/…`, `chore/…`, `docs/…`, `test/…`, `ci/…`, `security/…`, or `hotfix/…`. Commit messages must use the English Conventional Commit form `<type>(<scope>): <imperative description>`. Use `ops/check-commits.sh` before committing and `ops/finish-task.sh` before requesting a push.

Commits and pull requests are opt-in actions. Do not infer permission to create
them from a request to implement, fix, validate, or deploy changes to `dev`.
Only create commits or pull requests when the current user prompt explicitly
asks for them.

## Pull request creation

Create or update a pull request only when the current user prompt explicitly
requests a pull request. A request to implement, validate, commit, push, or
deploy does not authorize pull-request creation. Creating a pull request never
authorizes merging it.

Before creating a pull request:

1. Confirm the affected repository is on its task branch and has no unrelated
   changes.
2. Run `ops/check-commits.sh` before committing and `ops/finish-task.sh` before
   pushing.
3. Push the exact task branch and set its upstream without force-pushing.
4. Prepare a repository-specific title and body containing a summary, exact
   validation performed, dependencies, rollback guidance, and merge/deployment
   order.
5. Check whether an open pull request already exists for the same repository
   and head branch; update that pull request instead of creating a duplicate.

Use `gh pr create` or `gh pr edit` when the authenticated GitHub CLI is
available. If `gh` is unavailable, do not stop immediately and do not install
it automatically. Use an available authenticated GitHub connector or the
GitHub REST API. For the REST fallback, obtain existing HTTPS credentials with
`git credential fill`, keep the username and token only in shell variables,
and send the request to `/repos/{owner}/{repo}/pulls`. Never print, log, write,
or include credentials in command output, files, commits, or pull-request
content. Set `GIT_TERMINAL_PROMPT=0` so the fallback cannot hang on an
interactive credential prompt.

After creation or update, verify the pull request's number, URL, open state,
base branch, and head branch through GitHub before reporting success. If no
authenticated GitHub mechanism is available, report the exact blocker and
provide the repository's compare URL; do not claim that a pull request was
created.

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
