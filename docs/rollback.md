# Rollback

Roll back a code change with a reviewed revert or a documented immutable image
revision. Do not rewrite history, force-push, or delete data as a rollback
shortcut.

Database and object-store rollback requires an environment-specific, tested
restore procedure. A DEV rollback must remain within DEV; a future production
rollback must never reuse DEV data, volumes, secrets, or configuration.
