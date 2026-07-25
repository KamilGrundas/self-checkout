# Self-checkout control workspace

This thin repository coordinates five sibling, independent Git repositories. Their directories are intentionally ignored by the parent repository and are not submodules.

Start with:

```bash
./ops/context.sh
./ops/repos-status.sh
./ops/git-setup.sh --dry-run --all
./ops/dev-sync.sh --dry-run
./ops/dev-client-check.sh --optional
```

After `context.sh` verifies the remote dev host, set `workspace.dev_root` in `repos.yaml` to the dedicated absolute workspace path reported or provisioned on dev. Synchronization defaults to dry-run and never targets prod.

Start a future task with independent branches:

```bash
./ops/start-task.sh \
  --type feat \
  --name SC-123-payment-flow \
  --repos backend,client,infra
```

Finish with `./ops/finish-task.sh --repos backend,client,infra`. It validates and reviews each repository separately and never pushes or merges.

`dev-client` is an optional, replaceable target computer for native Rust/Iced
client testing. Its absence never blocks local client development. See
`docs/dev-client.md` for controlled synchronization, build, restart, and
verification.

See `CONTRIBUTING.md`, `docs/git-workflow.md`, `docs/releases.md`, `docs/architecture.md`, `docs/development.md`, `docs/deployment.md`, and `docs/rollback.md` before changing system-wide behavior.
