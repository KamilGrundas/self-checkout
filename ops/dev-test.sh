#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

usage() {
  printf 'Usage: ops/dev-test.sh [--repo NAME]... [--ml-dev]\n'
}

selected=''
ml_dev=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)
      shift
      [ "$#" -gt 0 ] || die '--repo requires a repository key'
      selected="${selected}${selected:+ }$1"
      ;;
    --ml-dev) ml_dev=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
  shift
done

require_workspace_root
"$SCRIPT_DIR/repos-status.sh"

sync_args=(--apply)
if [ -n "$selected" ]; then
  for key in $selected; do sync_args+=(--repo "$key"); done
  # Compose build contexts always require infra, backend, admin, and ml.
  for key in infra backend admin ml; do
    case " $selected " in
      *" $key "*) ;;
      *) sync_args+=(--repo "$key") ;;
    esac
  done
fi
"$SCRIPT_DIR/dev-sync.sh" "${sync_args[@]}"

verify_remote_environment dev dev
require_remote_command dev docker
dev_root="$(configured_dev_root)"
[ -n "$dev_root" ] || die 'Configure workspace.dev_root in repos.yaml first'
validate_remote_root "$dev_root"
infra="$dev_root/self-checkout-infra"

if [ "$ml_dev" = true ]; then
  compose_files='-f compose.yml -f compose.override.yml -f compose.s3-contract-test.yml -f compose.mlflow.yml'
  up_script='./scripts/up-validation.sh --mlflow'
else
  compose_files='-f compose.yml -f compose.override.yml -f compose.s3-contract-test.yml'
  up_script='./scripts/up-validation.sh'
fi

ssh -o BatchMode=yes dev "set -eu; cd '$infra'; ./scripts/repair-dev-env.sh; export S3_ENDPOINT_URL=http://s3-contract-test:4566 S3_ACCESS_KEY_ID=contract-test S3_SECRET_ACCESS_KEY=contract-test S3_USE_SSL=false S3_FORCE_PATH_STYLE=true S3_VERIFY_TLS=true; docker compose $compose_files config --quiet; $up_script; docker compose $compose_files ps"

# Repository-specific validation is delegated to the infra-owned controlled runner.
ssh -o BatchMode=yes dev "set -eu; cd '$infra'; test -x ./scripts/validate-dev.sh; ./scripts/validate-dev.sh $selected"

ssh -o BatchMode=yes dev "set -eu; cd '$infra'; docker compose $compose_files ps --format json"
