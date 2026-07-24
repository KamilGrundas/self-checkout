# S3-compatible object storage

No permanent object-storage provider is selected. Backend and ML use boto3
against the practical S3 subset they currently need: `HeadBucket`,
`CreateBucket` when explicitly enabled on dev, `ListObjectsV2`, `PutObject`,
`GetObject`, `DeleteObjects`, and `HeadObject`. Content type and user metadata
are preserved. boto3 supplies multipart upload for larger transfers where its
managed transfer API is used; the current request paths otherwise upload bounded
image and dataset objects. The applications do not currently require presigned
URLs.

Set `S3_FORCE_PATH_STYLE=true` for implementations that require path addressing.
Set a custom endpoint when the provider is not the default public S3 service.
TLS use and verification, region, retry count, connection/read timeouts, and
temporary session credentials are independent settings. ETag is never assumed
to be a content hash because multipart behavior differs. IAM extensions,
versioning, replication, provider administration, and vendor APIs are outside
the application contract.

Bucket creation is allowed only for local development with
`S3_CREATE_BUCKETS=true`. Production buckets, policies, identities, encryption,
and lifecycle rules are provisioned externally. Public object delivery, when
needed, uses `S3_PUBLIC_BASE_URL`; the application does not make buckets public.
