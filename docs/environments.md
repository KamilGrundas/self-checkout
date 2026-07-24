# Environments and configuration

Dev uses `compose.yml` plus `compose.override.yml`. It includes local
PostgreSQL, application containers, local volumes, migrations, health checks,
MLflow, Label Studio, the development mail catcher, and either an external S3
endpoint or a separately chosen provider overlay. Standard dev scripts include
`compose.mlflow.yml`.
`compose.s3-provider.example.yml` documents the stable DNS/port contract without
selecting a product. `compose.s3-contract-test.yml` is isolated automated-test
tooling, not an architectural provider.

Production uses `compose.yml` plus `compose.prod.yml`. It requires external
`DATABASE_URL` and S3 settings, disables bucket creation, has no local database,
S3 server, MLflow server, or stateful-infrastructure volume, and has no
`depends_on` relationship to dev-only services.

Canonical database settings are `DATABASE_URL`, `DB_CONNECT_TIMEOUT`,
`DB_POOL_SIZE`, and `DB_MAX_OVERFLOW`. S3 settings are `S3_ENDPOINT_URL`,
`S3_REGION`, `S3_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`,
`S3_SESSION_TOKEN`, `S3_USE_SSL`, `S3_FORCE_PATH_STYLE`, `S3_VERIFY_TLS`,
`S3_CONNECT_TIMEOUT`, `S3_READ_TIMEOUT`, `S3_MAX_RETRIES`,
`S3_CREATE_BUCKETS`, and `S3_PUBLIC_BASE_URL`. The backend additionally requires
`BACKEND_PUBLIC_URL` for browser-accessible product images. ML adds
`S3_SHELF_BUCKET`, `S3_SCALE_BUCKET`, `S3_EXTERNAL_BUCKET`,
`S3_TRAINING_BUCKET`, and `S3_LABEL_STUDIO_EXPORT_BUCKET`.

MLflow separates `MLFLOW_TRACKING_URI`, `MLFLOW_BACKEND_STORE_URI`, and
`MLFLOW_ARTIFACT_ROOT`. Tracking is optional for API health and storage-only ML
work, but training, registry operations, and model loading require a reachable
tracking server. Dev starts the local tracking server by default; production
may use an external server or omit MLflow when the scenario does not need it.

Only local development receives safe endpoint/bucket/database defaults.
Production validates required external values at Compose interpolation and
application startup. Examples contain placeholders only; actual secrets come
from independent environment configuration.
