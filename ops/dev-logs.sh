#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

[ "$#" -ge 1 ] && [ "$#" -le 2 ] || die 'Usage: ops/dev-logs.sh SERVICE [TAIL]'
service="$1"
tail_lines="${2:-200}"
case "$service" in admin|backend|db|ml|prestart|s3-contract-test) ;; *) die "Unsupported service: $service" ;; esac
case "$tail_lines" in ''|*[!0-9]*) die 'TAIL must be numeric' ;; esac

verify_remote_environment dev dev
dev_root="$(configured_dev_root)"
validate_remote_root "$dev_root"
infra="$dev_root/self-checkout-infra"
ssh -n -o BatchMode=yes dev "set -eu; cd '$infra'; test -x ./scripts/logs-dev.sh; ./scripts/logs-dev.sh '$service' '$tail_lines'" </dev/null
