# Development

Run all workspace scripts from the parent directory. `ops/repos-status.sh` reports live branch, SHA, remote, dirty state, and upstream ahead/behind counts for every child repository.

Bootstrap safe repository-local Git defaults and shared hooks with:

```bash
./ops/git-setup.sh --dry-run --all
./ops/git-setup.sh --apply --all
```

The bootstrap never changes global Git configuration, author identity, signing, credentials, or proxy settings. It preserves effective values already configured by the user. It intentionally avoids `fetch.pruneTags` because published tags are immutable and avoids `rebase.autoStash` because workspace automation must not stash user changes.

Create new work with `ops/start-task.sh`. The script fetches selected remotes, refuses dirty or in-progress repositories, resolves `main` as the configured base from `repos.yaml`, preflights every selected repository, and creates the same logical branch independently. Use `--dry-run` to preview. It never touches unselected repositories.

Use `ops/check-commits.sh --message 'fix(client): prevent duplicate payment'` or `--repo <key> --range <range>` to validate Conventional Commits. `ops/finish-task.sh --repos <keys>` runs remote dev validation, reviews diffs and untracked files, validates new commit messages, suggests commit groups, and prints PR summary skeletons. Its `--dry-run` mode skips remote validation but still performs local review.

Run `ops/context.sh` once to verify that `dev` resolves, `/etc/codex-environment` contains exactly `dev`, and to display safe workspace candidates. Set the selected absolute path in `repos.yaml` as `workspace.dev_root` (or temporarily export `SELF_CHECKOUT_DEV_ROOT`). Accepted paths must end in `/self-checkout` or `/self-checkout-workspace` and cannot be a broad system directory.

Synchronization is dry-run by default:

```bash
./ops/dev-sync.sh
./ops/dev-sync.sh --repo backend --dry-run
./ops/dev-sync.sh --repo backend --apply
```

For a new isolated dev workspace, `./ops/dev-init.sh` creates the required remote-only `self-checkout-infra/.env` from its example. It refuses to overwrite an existing file, uses mode `0600`, generates secret values on dev, and does not print them. Never copy a local `.env` into the remote workspace.

The optional `--delete-safe` flag uses delayed deletion only inside validated per-repository targets. It is never enabled by default. Git metadata, env files, credentials, caches, build outputs, dependencies, test reports, and infra data are excluded.

Use `ops/dev-test.sh --repo <key>` for affected repositories. It synchronizes all required Compose build contexts, verifies the dev marker, delegates repository validation to the controlled infra runner, and checks Compose service status. Do not run local Docker commands.
