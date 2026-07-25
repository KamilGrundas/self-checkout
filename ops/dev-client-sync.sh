#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/dev-client-common.sh"

mode=dry-run
usage() {
  printf 'Usage: %s [--dry-run|--apply]\n' "$0"
}
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) mode=dry-run ;;
    --apply) mode=apply ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
  shift
done

require_workspace_root
require_command rsync
require_dev_client

local_root="$(dev_client_local_root)"
[ -d "$local_root/.git" ] || die "Missing client repository: $local_root"
for required in Cargo.toml Cargo.lock rust-toolchain.toml src assets; do
  [ -e "$local_root/$required" ] || die "Missing required client input: $local_root/$required"
done

remote_root="$(configured_dev_client_root)"
validate_dev_client_root "$remote_root"
if [ "$mode" = apply ]; then
  remote_root_q="$(dev_client_shell_quote "$remote_root")"
  ssh -n "${DEV_CLIENT_SSH_ARGS[@]}" "$DEV_CLIENT_HOST" \
    "set -eu; root=$remote_root_q; mkdir -p -- \"\$root\"; test -O \"\$root\""
fi

rsync_args=(
  -az --checksum --itemize-changes --relative
  --exclude='.DS_Store' --exclude='*.swp' --exclude='*.swo' --exclude='*~'
)
[ "$mode" = dry-run ] && rsync_args+=(--dry-run)
rsync_shell="$(dev_client_rsync_shell)"
remote_rsync_root="$(printf '%s' "$remote_root" | sed 's/ /\\ /g')"

if [ "$mode" = apply ]; then mode_label=APPLY; else mode_label=DRY-RUN; fi
printf '%s client build inputs -> %s:%s\n' "$mode_label" "$DEV_CLIENT_HOST" "$remote_root"
(
  cd "$local_root"
  rsync "${rsync_args[@]}" -e "$rsync_shell" \
    ./Cargo.toml ./Cargo.lock ./rust-toolchain.toml ./src ./assets \
    "$DEV_CLIENT_HOST:$remote_rsync_root/" </dev/null
)
printf 'Preserved device-owned files: .env, .self-checkout-client-id, .self-checkout-settings.json, target/, startup files, and all unrelated paths.\n'
