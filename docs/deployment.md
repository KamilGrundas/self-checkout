# Deployment

Production is not provisioned by this workspace. No versioned script connects to
or deploys a remote environment.

A future production deployment requires a separate explicit instruction,
reviewed backup and restore procedure, exact component revisions or immutable
image digests, documented migration order, and health validation. Its local
operator configuration must isolate data, volumes, secrets, networks, and
configuration from every other environment.

Commit or push approval does not authorize a deployment. Never deploy
uncommitted source, delete production data or volumes, or infer runtime health
from Compose configuration validation alone.
