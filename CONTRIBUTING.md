# Contributing

Read AGENTS.md and each affected component's AGENTS.md. Keep repository
boundaries intact. Work locally on main; preserve all existing changes.
Run `ops/start-task.sh --repos <keys>` to fetch and check a clean, synchronized
main without creating branches or merging. For an already dirty task tree,
inspect it directly; do not discard or stash changes to satisfy the helper.

Run relevant local tests and `ops/finish-task.sh --repos <keys>`. This is a
review helper, not a replacement for component tests or deployment validation.
Show the actual diff, test results, limitations and intended commit message.
Wait for the user's direct approval before committing or pushing to main.
No PRs, force pushes, automatic commits or changes to remote branch protections.

Use English Conventional Commits: `<type>(<scope>): <imperative description>`.
Validate with `ops/check-commits.sh --message 'docs(workspace): clarify portable workflow'`.
Stage precise paths per repository. Production deployment requires separate
approval and an immutable release. See docs/git-workflow.md and AGENTS.md.
