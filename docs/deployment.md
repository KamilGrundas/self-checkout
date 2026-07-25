# Deployment

Synchronization and native rebuilds on the optional `dev-client` computer
are development-device validation, not production releases. They may use local
uncommitted client sources, must retain device-owned configuration, and grant
no authority to commit, push, release, or operate on `prod`.

Production deployment is intentionally not implemented in the workspace repository. `self-checkout-infra` remains the source of truth for CI/CD, immutable image naming, production health checks, migrations, and the approved deploy command.

A release must identify exact application commits and immutable image tags or digests, pass repository checks and integrated validation on dev, and state merge/deploy order. The MacBook may invoke only an approved infra-owned deployment script through `ssh prod`; it must never copy source code to prod.

Until such an infra-owned procedure exists and is reviewed, use `ops/prod-status.sh` only for the minimal read-only environment/uptime check. Do not infer that a successful status check authorizes deployment.

Production topology is `compose.yml` plus `compose.prod.yml`: application
containers receive an external `DATABASE_URL`, S3-compatible endpoint and
buckets, and an optional external `MLFLOW_TRACKING_URI`. It does not start or
own PostgreSQL, object storage, or MLflow. The pre-1.0 policy permits breaking
development changes but never authorizes production data modification,
uncommitted deployment, or an untested release.
