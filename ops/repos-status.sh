#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/git-common.sh"

require_command git
require_control_repository

REMOTE_CHECK=true
REQUESTED=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) [ "$#" -ge 2 ] || die '--repo requires a key'; validate_git_repo_key "$2"; REQUESTED="${REQUESTED} $2"; shift 2 ;;
    --all) REQUESTED=''; shift ;;
    --no-remote-check) REMOTE_CHECK=false; shift ;;
    -h|--help) printf 'Usage: %s [--all | --repo KEY ...] [--no-remote-check]\n' "$0"; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

printf '%-10s %-24s %-24s %-12s %-6s %-16s %-12s %-13s %s\n' NAME PATH BRANCH SHA STATE OPERATION REMOTE AHEAD/BEHIND LAST_COMMIT
git_repo_records | while IFS=$'\t' read -r key name path; do
  case " $REQUESTED " in *" $key "*) ;; *) [ -z "$REQUESTED" ] || continue ;; esac
  repo="$WORKSPACE_ROOT/$path"
  [ -d "$repo/.git" ] || die "$path is not a Git repository"
  branch="$(git -C "$repo" branch --show-current)"
  [ -n "$branch" ] || branch='(detached)'
  sha="$(git -C "$repo" rev-parse --short=12 HEAD 2>/dev/null || printf '(unborn)')"
  if [ -n "$(git -C "$repo" status --porcelain)" ]; then state=dirty; else state=clean; fi
  operation="$(git_operation_state "$repo")"
  if git -C "$repo" remote get-url origin >/dev/null 2>&1; then
    if [ "$REMOTE_CHECK" = true ]; then
      if git_remote_available "$repo"; then remote_state=available; else remote_state=unavailable; fi
    else
      remote_state=configured
    fi
  else
    remote_state=none
  fi
  upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
  if [ -z "$upstream" ]; then
    base="$(configured_base_branch "$key")"
    if [ -n "$base" ] && git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$base"; then
      upstream="origin/$base"
    fi
  fi
  if [ -n "$upstream" ]; then
    counts="$(git -C "$repo" rev-list --left-right --count "$upstream...HEAD" 2>/dev/null || true)"
    behind="$(printf '%s' "$counts" | awk '{print $1}')"
    ahead="$(printf '%s' "$counts" | awk '{print $2}')"
    relation="${ahead:-?}/${behind:-?}"
  else
    relation='-/-'
  fi
  last="$(git -C "$repo" log -1 --format='%h %s' 2>/dev/null || printf '(no commits)')"
  printf '%-10s %-24s %-24s %-12s %-6s %-16s %-12s %-13s %s\n' "$key" "$path" "$branch" "$sha" "$state" "$operation" "$remote_state" "$relation" "$last"
done
