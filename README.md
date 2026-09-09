# Self-checkout workspace

This repository is the portable integration workspace for the independent
component repositories recorded in [repos.yaml](repos.yaml): admin, backend,
client, infrastructure, and ML. It describes service contracts, Compose
integration, development workflow, and repository inventory. It does not
prescribe a host, container runtime, proxy, identity provider, VLM provider, or
network topology.

The workspace root contains versioned instructions, scripts, documentation,
tests, and inventory only. Environment directories, checkout placement,
runtime state, and secrets are local operator concerns and remain outside this
repository's contract. Component repositories remain independent repositories,
not submodules.

## Portable workflow

Run review helpers from the workspace root after supplying the local directory
that contains component checkouts (the directory itself is operator
configuration, not workspace state):

```bash
SELF_CHECKOUT_COMPONENTS_DIR=/path/to/component-checkouts \
  ./ops/repos-status.sh --no-remote-check
```

Work is prepared on `main`. Review the concrete diff and validation evidence
before requesting approval. Commits and publication require separate explicit
approval; the helpers never commit, push, create branches, or deploy.

Compose definitions use the standard Compose Specification and are intended to
work with `docker compose` and `podman compose`. Browser-facing configuration
uses local operator values; versioned examples use `localhost`, `127.0.0.1`, or
neutral placeholders. PostgreSQL and Redis are internal services and must not
be published to the host.

The autolabel workflow uses a replaceable OpenAI-compatible VLM inference
provider. The chosen provider, endpoint, credentials, and host routing are
local infrastructure decisions, outside this repository.

See [AGENTS.md](AGENTS.md), [architecture](docs/architecture.md),
[environments](docs/environments.md), [development](docs/development.md), and
[Git workflow](docs/git-workflow.md).
