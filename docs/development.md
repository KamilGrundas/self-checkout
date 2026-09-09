# Development

Begin at the workspace root, inspect the independent repositories, and read the
applicable instructions before editing:

```bash
./ops/repos-status.sh --no-remote-check
```

Environment entrypoints and environment files are operator configuration. Do
not add them to Git or duplicate their topology in workspace documentation.

Portable infrastructure targets the standard Compose Specification and supports
both `docker compose` and `podman compose`. Before an authorized environment
change, validate the exact local entrypoint with the selected Compose runtime's
`config` command. Keep resolved output private because it can contain secrets.
Then run relevant component tests and, after an authorized deployment, inspect
service status, bounded logs, health checks, and application connectivity.

Do not interpret a configuration check as a deployment or hardware validation.
Native client validation, external identity integration, and VLM provider
connectivity require their own environment-specific procedures.
