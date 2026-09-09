# Git workflow

`main` is the single integration branch in the workspace and every component.
Changes are prepared directly on main and left uncommitted for direct user
review. After approval of the concrete diff, create separate atomic Conventional
Commits in the approved repositories and push directly to origin/main when
publication is included in the approval. Do not create PRs or task branches.

`ops/start-task.sh --repos workspace,infra [--dry-run]` requires clean main,
no active Git operation and no divergence from origin/main. Normal mode fetches;
dry-run only inspects cached refs. Neither mode merges, resets, commits or pushes.
Dirty existing task work must be inspected and preserved rather than reset.

`ops/finish-task.sh --repos workspace,infra` reviews local diffs, untracked
files, suspicious additions and unpublished commit messages. Run relevant
component tests separately and report their exact results. Config validation
alone does not prove application health. Review staged as well as unstaged
changes before asking for approval.

Before publication, fetch and check remote divergence again. Remote changes
require review and reconciliation; do not overwrite them or silently include
new changes in an earlier approval. Never force-push or disable branch protection.
If GitHub requires PRs, report the conflict rather than creating one or bypassing
protection. User approval is not proof that a push will be permitted remotely.

Use English Conventional Commits and precise staging, with separate commits
per repository. Record dependency and publication order. A production release
or deployment is separate from commit/push approval. Roll back code through a
reviewed revert, not history rewriting or deleting production data.
