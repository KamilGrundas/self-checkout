#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

require_command git
require_command ssh
require_control_repository

printf 'Local hostname: %s\n' "$(hostname)"
printf 'Local user: %s\n' "$(id -un)"
printf 'Workspace: %s\n' "$WORKSPACE_ROOT"
printf 'Control branch: %s\n' "$(git -C "$WORKSPACE_ROOT" branch --show-current)"
printf 'Control commit: %s\n' "$(git -C "$WORKSPACE_ROOT" rev-parse --verify --short=12 HEAD 2>/dev/null || printf '(no commits)')"
if [ -n "$(git -C "$WORKSPACE_ROOT" status --porcelain)" ]; then
  printf 'Control working tree: dirty\n'
else
  printf 'Control working tree: clean\n'
fi

for alias_name in dev prod; do
  if ssh -G "$alias_name" >/dev/null 2>&1; then
    resolved_host="$(ssh -G "$alias_name" 2>/dev/null | awk '$1 == "hostname" { print $2; exit }')"
    printf 'SSH alias %s: available (%s)\n' "$alias_name" "$resolved_host"
  else
    printf 'SSH alias %s: unavailable\n' "$alias_name"
  fi
done

verify_remote_environment dev dev
ssh -o BatchMode=yes -o ConnectTimeout=10 dev 'printf "Dev hostname: %s\n" "$(hostname)"; printf "Dev environment: "; tr -d "[:space:]" < /etc/codex-environment; printf "\nDev home: %s\n" "$HOME"; for p in "$HOME/self-checkout" "$HOME/self-checkout-workspace" "$HOME/Repositories/self-checkout"; do if [ -d "$p" ]; then printf "Dev workspace candidate: %s\n" "$p"; fi; done'
ssh -o BatchMode=yes -o ConnectTimeout=10 dev 'printf "Dev OS: "; if [ -r /etc/os-release ]; then . /etc/os-release; printf "%s %s\n" "$ID" "$VERSION_ID"; else uname -srm; fi; for tool in rsync docker; do if command -v "$tool" >/dev/null 2>&1; then printf "Dev tool %s: available\n" "$tool"; else printf "Dev tool %s: unavailable\n" "$tool"; fi; done; if command -v docker >/dev/null 2>&1; then docker compose version 2>/dev/null || printf "Dev tool docker compose: unavailable\n"; fi'
