#!/usr/bin/env bash

set -o pipefail

OPS_LIB_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(CDPATH= cd -- "$OPS_LIB_DIR/../.." && pwd)"
REPOS_FILE="$WORKSPACE_ROOT/repos.yaml"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'WARNING: %s\n' "$*" >&2
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_workspace_root() {
  [ "$PWD" = "$WORKSPACE_ROOT" ] || die "Run this command from $WORKSPACE_ROOT"
}

require_control_repository() {
  [ -d "$WORKSPACE_ROOT/.git" ] || die "Control repository is not initialized"
  [ -f "$REPOS_FILE" ] || die "Missing $REPOS_FILE"
}

repo_records() {
  awk '
    /^repositories:/ { in_repos=1; next }
    !in_repos { next }
    /^  [a-zA-Z0-9_-]+:$/ {
      key=$1; sub(/:$/, "", key); checkout_directory=""; name=""; next
    }
    /^    name:/ { name=$0; sub(/^    name:[[:space:]]*/, "", name); next }
    /^    checkout_directory:/ {
      checkout_directory=$0; sub(/^    checkout_directory:[[:space:]]*/, "", checkout_directory)
      if (key != "" && name != "") print key "\t" name "\t" checkout_directory
    }
  ' "$REPOS_FILE"
}

repo_path_for() {
  repo_records | awk -F '\t' -v wanted="$1" '$1 == wanted { print $3; found=1 } END { if (!found) exit 1 }'
}

validate_repo_path() {
  case "$1" in
    self-checkout-admin|self-checkout-backend|self-checkout-client|self-checkout-infra|self-checkout-ml) ;;
    *) die "Unsafe repository path from repos.yaml: '$1'" ;;
  esac
}
