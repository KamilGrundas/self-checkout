#!/usr/bin/env bash

GIT_LIB_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$GIT_LIB_DIR/common.sh"

git_repo_records() {
  printf 'workspace\tself-checkout\t.\n'
  repo_records
}

validate_git_repo_key() {
  case "$1" in
    workspace|admin|backend|client|infra|ml) ;;
    *) die "Unknown repository key: '$1'" ;;
  esac
}

git_repo_path_for() {
  validate_git_repo_key "$1"
  if [ "$1" = workspace ]; then
    printf '.\n'
  else
    repo_path_for "$1"
  fi
}

git_repo_name_for() {
  validate_git_repo_key "$1"
  if [ "$1" = workspace ]; then
    printf 'self-checkout\n'
  else
    repo_records | awk -F '\t' -v wanted="$1" '$1 == wanted { print $2; found=1 } END { if (!found) exit 1 }'
  fi
}

repository_field() {
  key="$1"
  field="$2"
  validate_git_repo_key "$key"
  awk -v wanted="$key" -v field="$field" '
    $0 == "  " wanted ":" { in_repo=1; next }
    in_repo && /^  [a-zA-Z0-9_-]+:$/ { exit }
    in_repo && $0 ~ "^    " field ":" {
      value=$0
      sub("^    " field ":[[:space:]]*", "", value)
      gsub(/^"|"$/, "", value)
      if (value != "null") print value
      exit
    }
  ' "$REPOS_FILE"
}

configured_base_branch() {
  repository_field "$1" workflow_base_branch
}

configured_default_branch() {
  repository_field "$1" default_branch
}

git_repo_absolute_path() {
  path="$(git_repo_path_for "$1")"
  if [ "$path" = . ]; then
    printf '%s\n' "$WORKSPACE_ROOT"
  else
    printf '%s/%s\n' "$WORKSPACE_ROOT" "$path"
  fi
}

git_operation_state() {
  repo="$1"
  git_dir="$(git -C "$repo" rev-parse --git-dir)" || return 1
  case "$git_dir" in
    /*) ;;
    *) git_dir="$repo/$git_dir" ;;
  esac
  states=''
  [ -f "$git_dir/MERGE_HEAD" ] && states="${states}merge,"
  [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ] && states="${states}rebase,"
  [ -f "$git_dir/CHERRY_PICK_HEAD" ] && states="${states}cherry-pick,"
  [ -f "$git_dir/REVERT_HEAD" ] && states="${states}revert,"
  if [ -n "$states" ]; then
    printf '%s\n' "${states%,}"
  else
    printf 'none\n'
  fi
}

git_remote_available() {
  repo="$1"
  git -C "$repo" remote get-url origin >/dev/null 2>&1 || return 2
  GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' \
    git -C "$repo" ls-remote --exit-code origin HEAD >/dev/null 2>&1
}

selected_repo_keys() {
  csv="$1"
  printf '%s\n' "$csv" | tr ',' '\n' | awk 'NF && !seen[$0]++ { print }'
}

require_clean_safe_repository() {
  key="$1"
  repo="$(git_repo_absolute_path "$key")"
  [ -d "$repo/.git" ] || die "$key is not a Git repository: $repo"
  operation="$(git_operation_state "$repo")"
  [ "$operation" = none ] || die "$key has an active Git operation: $operation"
  [ -z "$(git -C "$repo" status --porcelain)" ] || die "$key has uncommitted changes"
}
