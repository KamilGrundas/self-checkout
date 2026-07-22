# Releases before 1.0

The system is in initial development. The first intentional release should be `0.1.0`; do not create that tag until a reviewed release candidate exists.

Use Semantic Versioning independently for deployable components:

- increase `0.y.0` for a meaningful development milestone or incompatible pre-1.0 contract change;
- increase `0.y.z` for a compatible fix to a released milestone;
- do not promise a stable public API before `1.0.0`;
- never move, recreate, or delete a published release tag;
- build images with the full Git commit SHA and optionally an immutable release tag;
- record image digests in the release manifest.

Admin, backend, client, and ML should be versioned independently because they can change and release at different rates. Infra should use its own tags for versioned deployment topology and scripts. The control workspace may be tagged only when its orchestration contract changes materially; it does not impose a shared version on the five repositories.

A system release is a manifest, not a shared Git tag. It records the exact version or SHA of every participating repository, immutable image digests, configuration schema, migration requirements, validation evidence, deployment order, and rollback targets.
