#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/git-common.sh"

REPOS=''
DRY_RUN=false

usage() {
  printf 'Usage: %s --repos key,key [--dry-run]\n' "$0"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repos) [ "$#" -ge 2 ] || die '--repos requires a comma-separated list'; REPOS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done
[ -n "$REPOS" ] || { usage >&2; exit 2; }

KEYS=''
for key in $(selected_repo_keys "$REPOS"); do validate_git_repo_key "$key"; KEYS="${KEYS} $key"; done

status_args=''
for key in $KEYS; do status_args="$status_args --repo $key"; done
# shellcheck disable=SC2086
"$SCRIPT_DIR/repos-status.sh" --no-remote-check $status_args

validation_args=''
for key in $KEYS; do
  [ "$key" = workspace ] || validation_args="$validation_args --repo $key"
done
if [ "$DRY_RUN" = true ]; then
  [ -z "$validation_args" ] || printf 'WOULD RUN: %s/dev-test.sh%s\n' "$SCRIPT_DIR" "$validation_args"
else
  if [ -n "$validation_args" ]; then
    # shellcheck disable=SC2086
    "$SCRIPT_DIR/dev-test.sh" $validation_args
  fi
fi

for key in $KEYS; do
  repo="$(git_repo_absolute_path "$key")"
  printf '\n===== %s =====\n' "$key"
  git -C "$repo" diff --check
  printf '%s\n' '-- status'
  git -C "$repo" status --short
  printf '%s\n' '-- diff stat'
  git -C "$repo" diff --stat
  git -C "$repo" diff --cached --stat
  if git -C "$repo" diff --no-ext-diff --unified=0 | grep -Eiq '^\+.*(-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16})'; then
    die "Potential secret detected in $key diff; inspect locally without printing it"
  fi
  base="$(configured_base_branch "$key")"
  if [ -n "$base" ] && git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$base"; then
    "$SCRIPT_DIR/check-commits.sh" --repo "$key" --range "origin/$base..HEAD"
  fi
  printf '%s\n' '-- suggested commit groups'
  git -C "$repo" status --short | awk '
    { path=$0; sub(/^.../, "", path) }
    path ~ /(^|\/)docs?\// || path ~ /README|AGENTS|CONTRIBUTING|CHANGELOG/ { docs=docs " " path; next }
    path ~ /(^|\/)(tests?|specs?)\// { tests=tests " " path; next }
    path ~ /Dockerfile|compose|\.github|(^|\/)ops\// || path ~ /\.ya?ml$/ { tooling=tooling " " path; next }
    { code=code " " path }
    END {
      if (code) print "code:" code
      if (tests) print "tests:" tests
      if (tooling) print "tooling/ci:" tooling
      if (docs) print "docs:" docs
    }'
  printf '%s\n' '-- PR summary skeleton'
  printf 'Purpose: [describe]\nValidation: [record exact checks]\nDependencies: [list repository PRs or none]\nRollback: [describe]\nMerge order: [position or independent]\n'
done

printf '\nNo push, PR creation, merge, release, or deployment was performed.\n'
