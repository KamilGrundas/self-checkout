#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/git-common.sh"

MESSAGE=''
MESSAGE_FILE=''
REPO_KEY=''
RANGE=''

usage() {
  printf 'Usage: %s (--message TEXT | --message-file FILE | --repo KEY [--range RANGE])\n' "$0"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --message) [ "$#" -ge 2 ] || die '--message requires text'; MESSAGE="$2"; shift 2 ;;
    --message-file) [ "$#" -ge 2 ] || die '--message-file requires a path'; MESSAGE_FILE="$2"; shift 2 ;;
    --repo) [ "$#" -ge 2 ] || die '--repo requires a key'; REPO_KEY="$2"; validate_git_repo_key "$REPO_KEY"; shift 2 ;;
    --range) [ "$#" -ge 2 ] || die '--range requires a revision range'; RANGE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done

validate_message() {
  content="$1"
  header="$(printf '%s\n' "$content" | sed -n '1p')"
  [ -n "$header" ] || { printf 'ERROR: empty commit message\n' >&2; return 1; }
  [ "${#header}" -le 72 ] || { printf 'ERROR: commit header exceeds 72 characters\n' >&2; return 1; }
  printf '%s\n' "$header" | grep -Eq '^(feat|fix|refactor|perf|test|docs|build|ci|chore|revert|security)(\([a-z0-9][a-z0-9._/-]*\))?(!)?: [a-z0-9]' \
    || { printf 'ERROR: commit header is not a supported Conventional Commit\n' >&2; return 1; }
  case "$header" in *.) printf 'ERROR: commit header must not end with a period\n' >&2; return 1 ;; esac
  description="${header#*: }"
  case "$description" in
    update|changes|'fix stuff'|work|wip|misc)
      printf 'ERROR: commit description is too generic\n' >&2; return 1 ;;
  esac
  return 0
}

if [ -n "$MESSAGE" ]; then
  validate_message "$MESSAGE"
  printf 'Commit message: OK\n'
  exit 0
fi

if [ -n "$MESSAGE_FILE" ]; then
  [ -f "$MESSAGE_FILE" ] || die "Message file does not exist: $MESSAGE_FILE"
  validate_message "$(sed '/^#/d' "$MESSAGE_FILE")"
  printf 'Commit message: OK\n'
  exit 0
fi

[ -n "$REPO_KEY" ] || { usage >&2; exit 2; }
repo="$(git_repo_absolute_path "$REPO_KEY")"
if [ -z "$RANGE" ]; then
  base="$(configured_base_branch "$REPO_KEY")"
  [ -n "$base" ] || die "No --range and no workflow base configured for $REPO_KEY"
  RANGE="origin/$base..HEAD"
fi
git -C "$repo" rev-parse "$RANGE" >/dev/null 2>&1 || die "Invalid revision range for $REPO_KEY: $RANGE"
failed=false
for commit in $(git -C "$repo" rev-list --reverse "$RANGE"); do
  if ! validate_message "$(git -C "$repo" show -s --format='%B' "$commit")"; then
    printf 'ERROR: invalid commit %s in %s\n' "$(git -C "$repo" rev-parse --short=12 "$commit")" "$REPO_KEY" >&2
    failed=true
  fi
done
[ "$failed" = false ] || exit 1
printf 'Commit range %s (%s): OK\n' "$RANGE" "$REPO_KEY"
