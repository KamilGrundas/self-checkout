#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/git-common.sh"

TYPE=''
NAME=''
REPOS=''
DRY_RUN=false

usage() {
  printf 'Usage: %s --type TYPE --name NAME --repos key,key [--dry-run]\n' "$0"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --type) [ "$#" -ge 2 ] || die '--type requires a value'; TYPE="$2"; shift 2 ;;
    --name) [ "$#" -ge 2 ] || die '--name requires a value'; NAME="$2"; shift 2 ;;
    --repos) [ "$#" -ge 2 ] || die '--repos requires a comma-separated list'; REPOS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done

case "$TYPE" in feat|fix|refactor|chore|docs|test|ci|security|hotfix) ;; *) die "Unsupported task type: '$TYPE'" ;; esac
[ -n "$NAME" ] || die '--name is required'
printf '%s\n' "$NAME" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$' || die 'Task name must contain only letters, digits, dots, underscores, and hyphens'
case "$NAME" in *..*|*-|*.) die "Unsafe task name: '$NAME'" ;; esac
[ -n "$REPOS" ] || die '--repos is required'
branch="$TYPE/$NAME"
git check-ref-format --branch "$branch" >/dev/null 2>&1 || die "Invalid branch name: $branch"

KEYS=''
for key in $(selected_repo_keys "$REPOS"); do
  validate_git_repo_key "$key"
  case " $KEYS " in *" $key "*) ;; *) KEYS="${KEYS} $key" ;; esac
done
[ -n "$KEYS" ] || die 'No repositories selected'

printf 'Task branch: %s\n' "$branch"
for key in $KEYS; do
  repo="$(git_repo_absolute_path "$key")"
  [ -d "$repo/.git" ] || die "$key is not a Git repository"
  operation="$(git_operation_state "$repo")"
  [ "$operation" = none ] || die "$key has an active Git operation: $operation"
  if [ -n "$(git -C "$repo" status --porcelain)" ]; then
    printf 'Dirty repository %s:\n' "$key" >&2
    git -C "$repo" status --short >&2
    die "Refusing to create branches while $key is dirty"
  fi
  git -C "$repo" show-ref --verify --quiet "refs/heads/$branch" && die "$key already has local branch $branch"
  git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$branch" && die "$key already has remote branch origin/$branch"
done

for key in $KEYS; do
  repo="$(git_repo_absolute_path "$key")"
  if git -C "$repo" remote get-url origin >/dev/null 2>&1; then
    printf 'Fetch %s\n' "$key"
    git -C "$repo" fetch --prune origin
  fi
done

for key in $KEYS; do
  repo="$(git_repo_absolute_path "$key")"
  base="$(configured_base_branch "$key")"
  [ -n "$base" ] || base="$(configured_default_branch "$key")"
  [ -n "$base" ] || die "No workflow base branch configured for $key"
  if git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$base"; then
    source_ref="origin/$base"
    if git -C "$repo" show-ref --verify --quiet "refs/heads/$base"; then
      local_sha="$(git -C "$repo" rev-parse "$base")"
      remote_sha="$(git -C "$repo" rev-parse "origin/$base")"
      [ "$local_sha" = "$remote_sha" ] || die "$key local $base differs from origin/$base; reconcile it explicitly"
    fi
  elif git -C "$repo" show-ref --verify --quiet "refs/heads/$base"; then
    source_ref="$base"
  else
    die "$key has no usable base ref for $base"
  fi
  printf '%-10s create %-40s from %s\n' "$key" "$branch" "$source_ref"
done

if [ "$DRY_RUN" = true ]; then
  printf 'Dry-run: no branch was created.\n'
  exit 0
fi

for key in $KEYS; do
  repo="$(git_repo_absolute_path "$key")"
  base="$(configured_base_branch "$key")"; [ -n "$base" ] || base="$(configured_default_branch "$key")"
  if git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$base"; then source_ref="origin/$base"; else source_ref="$base"; fi
  git -C "$repo" switch --no-track -c "$branch" "$source_ref"
done
printf 'Created independent branch %s in:%s\n' "$branch" "$KEYS"
