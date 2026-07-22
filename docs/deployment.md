# Deployment

Production deployment is intentionally not implemented in the workspace repository. `self-checkout-infra` remains the source of truth for CI/CD, immutable image naming, production health checks, migrations, and the approved deploy command.

A release must identify exact application commits and immutable image tags or digests, pass repository checks and integrated validation on dev, and state merge/deploy order. The MacBook may invoke only an approved infra-owned deployment script through `ssh prod`; it must never copy source code to prod.

Until such an infra-owned procedure exists and is reviewed, use `ops/prod-status.sh` only for the minimal read-only environment/uptime check. Do not infer that a successful status check authorizes deployment.
