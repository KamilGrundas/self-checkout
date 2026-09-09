# Object storage

Application code uses a provider-neutral S3-compatible contract. Configuration
includes endpoint, region, bucket names, credentials, TLS verification,
addressing style, timeouts, retries, and an optional browser-facing delivery
base URL. No component depends on a provider console, proprietary SDK, or
provider-specific hostname.

Development bucket creation may be explicitly enabled for isolated development
state. Production buckets, policies, lifecycle rules, and credentials are
operator-managed external dependencies. Product image URLs are delivered by the
backend's configured public URL, never an internal object-store DNS name.
