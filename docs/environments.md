# Environment boundary

This portable workspace intentionally does not define environment directories,
provisioning state, active runtimes, project names, host bindings, secrets, or
deployment targets. Those are responsibilities of the local operator layer.

The infra repository provides portable Compose service contracts and safe
examples only. Browser builds receive browser-accessible API URLs from local
configuration; internal Compose service names are not browser URLs.

The autolabel endpoint is an OpenAI-compatible VLM inference provider endpoint.
Its endpoint and credentials are local configuration and separate from
self-checkout API credentials.
