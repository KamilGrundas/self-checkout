# Architecture

The local parent repository is a control plane, not an application monorepo. Five sibling repositories retain independent Git histories and lifecycle. `repos.yaml` is inventory metadata, not a lock file; recorded inventory branches can become stale and runtime scripts always query Git directly.

`self-checkout-infra` owns the runtime topology. The base `compose.yml` defines PostgreSQL, MinIO, bucket initialization, backend, admin, and ML services. `compose.override.yml` adds development ports, reload/watch configuration, and the backend coverage bind mount. `compose.mlflow.yml` adds optional MLflow and Label Studio services. No Compose profiles or explicit networks are currently defined.

Compose build contexts are sibling paths for backend, admin, and ML. Consequently, the dev workspace must preserve the same five-directory layout as the MacBook workspace. The Rust client is not a Compose service and is validated separately on dev.

Named volumes hold PostgreSQL, MinIO, ML model cache, MLflow, and Label Studio data. `self-checkout-infra/.env` is required remotely and is never synchronized from the MacBook.
