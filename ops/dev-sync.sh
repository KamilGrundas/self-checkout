#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

usage() {
  printf 'Usage: ops/dev-sync.sh [--dry-run|--apply] [--delete-safe] [--repo NAME]...\n'
}

mode=dry-run
delete_safe=false
selected=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) mode=dry-run ;;
    --apply) mode=apply ;;
    --delete-safe) delete_safe=true ;;
    --repo)
      shift
      [ "$#" -gt 0 ] || die '--repo requires a repository key'
      selected="${selected}${selected:+ }$1"
      ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
  shift
done

require_workspace_root
require_control_repository
require_command rsync
verify_remote_environment dev dev
require_remote_command dev rsync

dev_root="$(configured_dev_root)"
[ -n "$dev_root" ] || die 'Set workspace.dev_root in repos.yaml or SELF_CHECKOUT_DEV_ROOT after running ops/context.sh'
validate_remote_root "$dev_root"

compose_dir="$WORKSPACE_ROOT/self-checkout-infra"
[ -f "$compose_dir/compose.yml" ] || die 'Missing infra compose.yml'
printf 'Compose build contexts detected:'
awk '$1 == "context:" { value=$2; sub(/^\.\.\//, "", value); print value }' "$compose_dir"/compose*.yml \
  | sort -u \
  | while IFS= read -r context_path; do
      validate_repo_path "$context_path"
      printf ' %s' "$context_path"
    done
printf '\n'

rsync_args=(-az --itemize-changes)
[ "$mode" = dry-run ] && rsync_args+=(--dry-run)
[ "$delete_safe" = true ] && rsync_args+=(--delete-delay)
rsync_args+=(
  --include='.env.example'
  --include='.env.*.example'
  --exclude='.git/' --exclude='.env' --exclude='.env.*'
  --exclude='.ssh/' --exclude='*.pem' --exclude='*.key' --exclude='id_rsa*' --exclude='id_ed25519*'
  --exclude='.self-checkout-client-id'
  --exclude='*secret*' --exclude='*token*'
  --exclude='.DS_Store' --exclude='*.log'
  --exclude='node_modules/' --exclude='dist/' --exclude='target/' --exclude='.venv/' --exclude='venv/'
  --exclude='__pycache__/' --exclude='.pytest_cache/' --exclude='.mypy_cache/' --exclude='.ruff_cache/' --exclude='.uv-cache/'
  --exclude='.cache/' --exclude='.tanstack/' --exclude='tmp/'
  --exclude='htmlcov/' --exclude='coverage/' --exclude='test-results/' --exclude='playwright-report/'
  --exclude='data/' --exclude='mydata/' --exclude='openapi.json'
)

want_repo() {
  [ -z "$selected" ] && return 0
  case " $selected " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

if [ -n "$selected" ]; then
  for key in $selected; do
    repo_path_for "$key" >/dev/null || die "Unknown repository key: $key"
  done
fi

repo_records | while IFS=$'\t' read -r key name path; do
  want_repo "$key" || continue
  validate_repo_path "$path"
  source_dir="$WORKSPACE_ROOT/$path"
  [ -d "$source_dir/.git" ] || die "Missing Git repository: $source_dir"
  target="$dev_root/$path"
  if [ "$mode" = apply ]; then mode_label=APPLY; else mode_label=DRY-RUN; fi
  printf '%s %s -> dev:%s\n' "$mode_label" "$path" "$target"
  if [ "$mode" = apply ]; then
    ssh -n -o BatchMode=yes dev "mkdir -p -- '$target'" </dev/null
  fi
  rsync "${rsync_args[@]}" -e ssh "$source_dir/" "dev:$target/" </dev/null
done

printf 'Sync mode: %s; delete: %s\n' "$mode" "$delete_safe"
