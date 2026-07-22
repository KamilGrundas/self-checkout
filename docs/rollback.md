# Rollback

Rollback is an infra-owned production operation. A valid procedure must identify the previous immutable release, define database compatibility and migration handling, restore only approved application versions, and verify production health afterward.

Do not implement rollback as source synchronization, a checkout of an arbitrary branch, or an unreviewed Docker command. If database changes are not backward-compatible, stop and follow the separately approved database recovery plan. No generic workspace rollback command is provided until `self-checkout-infra` contains a reviewed controlled script.
