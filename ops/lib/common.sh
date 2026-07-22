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
      key=$1; sub(/:$/, "", key); path=""; name=""; next
    }
    /^    name:/ { name=$0; sub(/^    name:[[:space:]]*/, "", name); next }
    /^    path:/ {
      path=$0; sub(/^    path:[[:space:]]*/, "", path)
      if (key != "" && name != "") print key "\t" name "\t" path
    }
  ' "$REPOS_FILE"
}

repo_path_for() {
  repo_records | awk -F '\t' -v wanted="$1" '$1 == wanted { print $3; found=1 } END { if (!found) exit 1 }'
}

configured_dev_root() {
  if [ -n "${SELF_CHECKOUT_DEV_ROOT:-}" ]; then
    printf '%s\n' "$SELF_CHECKOUT_DEV_ROOT"
    return
  fi
  awk '
    /^workspace:/ { in_workspace=1; next }
    /^repositories:/ { in_workspace=0 }
    in_workspace && /^  dev_root:/ {
      value=$0; sub(/^  dev_root:[[:space:]]*/, "", value)
      gsub(/^"|"$/, "", value); print value; exit
    }
  ' "$REPOS_FILE"
}

validate_remote_root() {
  case "$1" in
    ""|/|/home|/Users|/root|/tmp|/var|/usr|/etc) die "Unsafe or empty dev root: '$1'" ;;
  esac
  case "$1" in
    /*) ;;
    *) die "Dev root must be an absolute path: '$1'" ;;
  esac
  case "$1" in
    *[!A-Za-z0-9_./-]*) die "Dev root contains unsupported characters: '$1'" ;;
  esac
  case "$1" in
    */self-checkout|*/self-checkout-workspace) ;;
    *) die "Dev root must end in /self-checkout or /self-checkout-workspace: '$1'" ;;
  esac
}

validate_repo_path() {
  case "$1" in
    self-checkout-admin|self-checkout-backend|self-checkout-client|self-checkout-infra|self-checkout-ml) ;;
    *) die "Unsafe repository path from repos.yaml: '$1'" ;;
  esac
}

verify_ssh_alias() {
  require_command ssh
  ssh -G "$1" >/dev/null 2>&1 || die "SSH alias is unavailable: $1"
}

verify_remote_environment() {
  alias_name="$1"
  expected="$2"
  verify_ssh_alias "$alias_name"
  actual="$(ssh -o BatchMode=yes -o ConnectTimeout=10 "$alias_name" 'if [ ! -r /etc/codex-environment ]; then printf "__MISSING__"; else tr -d "[:space:]" < /etc/codex-environment; fi')" || die "Cannot connect to or verify $alias_name environment"
  [ "$actual" != '__MISSING__' ] || die "$alias_name does not provide a readable /etc/codex-environment marker"
  [ "$actual" = "$expected" ] || die "SSH alias $alias_name reports '$actual', expected '$expected'"
}

require_remote_command() {
  alias_name="$1"
  command_name="$2"
  case "$command_name" in
    rsync|docker) ;;
    *) die "Remote command is not allowlisted: $command_name" ;;
  esac
  ssh -o BatchMode=yes -o ConnectTimeout=10 "$alias_name" "command -v '$command_name' >/dev/null 2>&1" \
    || die "Required command is unavailable on $alias_name: $command_name"
}
