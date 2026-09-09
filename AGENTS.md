# Self-checkout workspace instructions

## Scope and hierarchy

Start at the workspace root. Before changing a file, read this file and every
applicable `AGENTS.md` in the affected component. If a parent environment
instruction is available, follow it for local operations, but do not copy its
host policy, absolute paths, domains, runtime choice, or operator identity into
this repository.

This repository coordinates independent `admin`, `backend`, `client`, `infra`,
and `ml` repositories listed in `repos.yaml`. Local checkout placement is an
operator decision and is not part of this repository's contract. Use `git -C
<path>` for component Git commands; preserve each repository's independent
history and working tree. Do not create missing component directories as
substitutes.

The versioned workspace root contains only general instructions, scripts,
documentation, tests, and the repository inventory. Environment layout,
provisioning, runtime state, and secrets belong to the local operator layer,
not this repository.

## Environments and Compose

Infrastructure owns the portable Compose Specification and service contracts.
It must remain compatible with both `docker compose` and `podman compose`.
Use neutral `localhost`, `127.0.0.1`, and example domains in examples; do not
put real addresses, domains, proxy routing, host users, or selected identity or
inference providers in this workspace or a component repository. Databases and
Redis remain internal to their project network and have no host-published
ports. Web services bind to localhost by default unless local operator
configuration deliberately supplies another binding.

The project depends on a generic OpenAI-compatible VLM/vision inference
provider. Product code, UI, API paths, configuration, and documentation use
that neutral term. Preserve historical migration identifiers when changing them
would invalidate existing database history.

## Pre-v0.1 policy

Until the first intentional v0.1 release, backward compatibility with earlier
unreleased development versions is not required. Prefer a coherent current
architecture over compatibility shims. When replacing an internal contract,
remove the obsolete code, tests, configuration, and documentation in the same
change unless a historical database migration must retain an identifier for
already-created data. Coordinate breaking changes across affected components
and validate their current integration. Before v0.1, replace this policy with
explicit compatibility, versioning, upgrade, and data-migration rules.

## Workflow and safety

Inspect all affected working trees before editing and preserve existing changes.
Work on `main`; do not create task branches or pull requests in the standard
workflow. An implementation request never authorizes a commit, push, release,
or environment deployment. After validation, show the exact diff and leave it
uncommitted until direct approval. Commit separately per repository only after
approval; push only when publication is explicitly approved. Never force-push,
rewrite history, reset hard, clean, or automatically stash.

`ops/repos-status.sh --no-remote-check` reports local repository state.
`ops/start-task.sh` and `ops/finish-task.sh` are review helpers; they do not
deploy or alter branches. Old SSH-oriented helper names are retained only as
safe no-op compatibility wrappers and must not be presented as an environment
workflow.

Keep secrets, environment files, keys, runtime data, backups, and generated
local state out of Git. Examples contain placeholders only. Production work,
data refresh, destructive operations, migrations against live data, and
environment deployment require separate explicit instructions and a reviewed
backup/restore procedure.
