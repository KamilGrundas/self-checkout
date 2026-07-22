#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

verify_remote_environment prod prod
ssh -o BatchMode=yes -o ConnectTimeout=10 prod 'set -eu; printf "Prod hostname: %s\n" "$(hostname)"; printf "Prod environment: "; tr -d "[:space:]" < /etc/codex-environment; printf "\nUptime: "; uptime'
