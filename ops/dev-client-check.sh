#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/dev-client-common.sh"

optional=false
case "${1:-}" in
  '') ;;
  --optional) optional=true ;;
  -h|--help)
    printf 'Usage: %s [--optional]\n' "$0"
    printf 'Exit 0 when reachable, 3 when unavailable, and 2 for SSH configuration/authentication errors.\n'
    exit 0
    ;;
  *) die "Unknown argument: $1" ;;
esac
[ "$#" -le 1 ] || die 'Too many arguments'

set +e
dev_client_probe
status=$?
set -e
case "$status" in
  0)
    printf 'AVAILABLE: %s is reachable\n' "$DEV_CLIENT_HOST"
    ;;
  3)
    if [ "$optional" = true ]; then
      printf 'SKIPPED: dev-client unavailable; local development and validation may continue\n'
      exit 0
    fi
    exit 3
    ;;
  *) exit "$status" ;;
esac
