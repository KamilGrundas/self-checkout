# Development reset and recovery

`self-checkout-infra/ops/reset-dev.sh` validates the independent dev marker,
prints a plan, optionally snapshots the dev database, stops applications,
removes only explicitly allowlisted volumes whose Compose project label
matches, recreates the stack, and leaves imports to the one-way refresh tool.
It never invokes a system-wide or volume-wide prune.

Recovery order is: verify target, snapshot if requested, stop applications,
remove selected dev resources, recreate Compose services, restore PostgreSQL,
run current migrations, synchronize S3, restore MLflow relationships if
selected, start applications, verify integrity, run health checks, and retain a
secret-free report.

Production recovery and deployment are separate approved infrastructure
procedures. Development reset tooling has no production target, cannot reverse
the refresh direction, and must never be used as a production disaster-recovery
mechanism.
