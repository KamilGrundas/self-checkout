#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
require_command git
require_control_repository
printf 'Workspace: %s\n' "$WORKSPACE_ROOT"
printf 'Branch: %s\n' "$(git -C "$WORKSPACE_ROOT" branch --show-current)"
if docker compose version >/dev/null 2>&1; then
  docker compose version
elif podman compose version >/dev/null 2>&1; then
  podman compose version
else
  printf 'Compose runtime: unavailable (local operator configuration)\n'
fi
printf 'Component checkout directory: %s\n' "${SELF_CHECKOUT_COMPONENTS_DIR:-not configured}"
printf 'No component checkout or environment was contacted or changed.\n'
