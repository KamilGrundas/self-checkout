#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

verify_remote_environment dev dev
dev_root="$(configured_dev_root)"
[ -n "$dev_root" ] || die 'Configure workspace.dev_root in repos.yaml first'
validate_remote_root "$dev_root"
infra="$dev_root/self-checkout-infra"
ssh -o BatchMode=yes dev "set -eu; cd '$infra'; test -x ./scripts/status-dev.sh; ./scripts/status-dev.sh"
