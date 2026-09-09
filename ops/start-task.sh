#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/git-common.sh"
REPOS=''
DRY_RUN=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repos) [ "$#" -ge 2 ] || die '--repos requires keys'; REPOS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) printf 'Usage: %s --repos key,key [--dry-run]\nChecks main; never creates branches, commits, merges or pushes.\n' "$0"; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done
[ -n "$REPOS" ] || die '--repos is required'
KEYS="$(selected_repo_keys "$REPOS")"
[ -n "$KEYS" ] || die "No repositories selected"
for key in $KEYS; do
  validate_git_repo_key "$key"
  require_clean_safe_repository "$key"
  repo="$(git_repo_absolute_path "$key")"
  [ "$(git -C "$repo" branch --show-current)" = main ] || die "$key must already be on main; inspect before switching"
  [ "$(configured_base_branch "$key")" = main ] || die "$key must configure main as its workflow base"
  git -C "$repo" remote get-url origin >/dev/null || die "$key has no origin"
done
for key in $KEYS; do
  repo="$(git_repo_absolute_path "$key")"
  if [ "$DRY_RUN" = false ]; then
    GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=10' git -C "$repo" fetch --prune origin
  fi
  git -C "$repo" show-ref --verify --quiet refs/remotes/origin/main || die "$key has no cached origin/main"
  [ "$(git -C "$repo" rev-parse HEAD)" = "$(git -C "$repo" rev-parse origin/main)" ] || die "$key differs from origin/main; inspect and reconcile explicitly"
  printf '%s: clean main matches %sorigin/main\n' "$key" "$([ "$DRY_RUN" = true ] && printf 'cached ' || true)"
done
printf 'Ready for local changes. Commit and push require direct user approval of the diff.\n'
