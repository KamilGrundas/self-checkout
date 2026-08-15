# Environments and configuration

The project uses three distinct SSH targets. `dev` owns Docker Compose,
integration services, and browser-facing validation. `prod` accepts only
approved immutable releases through controlled procedures. `dev-client` is an
optional, replaceable computer that runs the Rust/Iced client natively against
development-only APIs; it owns its runtime credentials and graphical startup
configuration and is never a source or Docker deployment target.

Dev uses `compose.yml` plus `compose.override.yml`. It includes local
PostgreSQL, application containers, local volumes, migrations, health checks,
Redis with separate training/autolabel workers, the development mail catcher,
and either an external S3 endpoint or a separately chosen provider overlay.
`compose.s3-provider.example.yml` documents the stable DNS/port contract without
selecting a product. `compose.s3-contract-test.yml` is isolated automated-test
tooling, not an architectural provider.

Production uses `compose.yml` plus `compose.prod.yml`. It requires external
`DATABASE_URL` and S3 settings, disables bucket creation, has no local database,
S3 server or stateful-infrastructure volume, and has no
`depends_on` relationship to dev-only services.

Canonical database settings are `DATABASE_URL`, `DB_CONNECT_TIMEOUT`,
`DB_POOL_SIZE`, and `DB_MAX_OVERFLOW`. S3 settings are `S3_ENDPOINT_URL`,
`S3_REGION`, `S3_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`,
`S3_SESSION_TOKEN`, `S3_USE_SSL`, `S3_FORCE_PATH_STYLE`, `S3_VERIFY_TLS`,
`S3_CONNECT_TIMEOUT`, `S3_READ_TIMEOUT`, `S3_MAX_RETRIES`,
`S3_CREATE_BUCKETS`, and `S3_PUBLIC_BASE_URL`. The backend additionally requires
`BACKEND_PUBLIC_URL` for browser-accessible product images. ML adds
`S3_SHELF_BUCKET`, `S3_SCALE_BUCKET`, `S3_EXTERNAL_BUCKET`,
and `S3_TRAINING_BUCKET`. Labeled images, datasets, model artifacts, metrics,
and active-version pointers are stored through this generic contract.
The admin image compiles browser-accessible `VITE_API_URL` and
`VITE_ML_API_URL`; Compose-only service names must not be used for a LAN-facing
build.

Normal development uses `https://dev.admin.teik.pl` for the admin UI,
`https://dev.api.teik.pl` for the backend, `https://dev.ml.teik.pl` for ML, and
`https://dev.s3-api.teik.pl` for the browser-facing S3-compatible API. These
origins are independent configuration values rather than ports derived from a
single host. `https://dev.s3.teik.pl` is the provider console and is not an S3
API endpoint.

`TRAINING_QUEUE_URL` is the generic Redis connection used by classifier
training and scale autolabeling. The queues have separate workers; the
`scale-autolabel` worker has concurrency one for the local VLM. The VLM URL and
timeouts are not environment variables: a superuser stores them in the backend
system-settings singleton, and ML snapshots them when creating a batch.
The canonical DEV value is `https://ai.teik.pl/v1/files/inference`.
`compose.override.yml` provides the DEV-only hostname mapping and Caddy root CA
needed by ML containers; production must supply its own routable endpoint and
trust policy.

Only local development receives safe endpoint/bucket/database defaults.
Production validates required external values at Compose interpolation and
application startup. Examples contain placeholders only; actual secrets come
from independent environment configuration.

The target client reads `DEFAULT_LANG`, `APP_ENV`, `API_BASE_URL`,
`ML_API_BASE_URL`, `CHECKOUT_COUNTER_ID`, `CHECKOUT_COUNTER_PASSWORD`, and
`CLIENT_ID_STORAGE_PATH` from its device-owned `.env` or process environment.
Synchronization must not overwrite that file. Both API endpoints must resolve
to the canonical development HTTPS routes, never to `prod`, raw published
Compose ports, or application services hosted by `dev-client`. Native HTTPS and
WSS use the operating-system trust store, which must trust the Caddy
development CA. Validation must fail visibly when the route or certificate
trust is unavailable. See [dev-client.md](dev-client.md).
