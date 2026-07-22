#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/git-common.sh"

MODE=dry-run
REQUESTED=''

usage() {
  printf 'Usage: %s (--dry-run | --apply) (--all | --repo KEY [...])\n' "$0"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) MODE=dry-run; shift ;;
    --apply) MODE=apply; shift ;;
    --all) REQUESTED=all; shift ;;
    --repo) [ "$#" -ge 2 ] || die '--repo requires a key'; validate_git_repo_key "$2"; [ "$REQUESTED" != all ] || die 'Do not combine --all and --repo'; REQUESTED="${REQUESTED} $2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done
[ -n "$REQUESTED" ] || { usage >&2; exit 2; }

configure_if_unset() {
  local repo="$1"
  local config_key="$2"
  local value="$3"
  local existing
  existing="$(git -C "$repo" config --get "$config_key" 2>/dev/null || true)"
  if [ -n "$existing" ]; then
    printf 'KEEP  %-24s %s (effective value: %s)\n' "$config_key" "$repo" "$existing"
  elif [ "$MODE" = apply ]; then
    git -C "$repo" config --local "$config_key" "$value"
    printf 'SET   %-24s %s -> %s\n' "$config_key" "$repo" "$value"
  else
    printf 'WOULD %-24s %s -> %s\n' "$config_key" "$repo" "$value"
  fi
}

git_repo_records | while IFS=$'\t' read -r key name path; do
  if [ "$REQUESTED" != all ]; then case " $REQUESTED " in *" $key "*) ;; *) continue ;; esac; fi
  repo="$WORKSPACE_ROOT/$path"
  [ -d "$repo/.git" ] || die "$key is not a Git repository"
  printf '\n[%s]\n' "$key"
  configure_if_unset "$repo" fetch.prune true
  configure_if_unset "$repo" push.autoSetupRemote true
  configure_if_unset "$repo" rerere.enabled true
  configure_if_unset "$repo" pull.ff only
  configure_if_unset "$repo" branch.sort -committerdate
  configure_if_unset "$repo" tag.sort -version:refname
  if [ "$key" = workspace ]; then hooks_path=.githooks; else hooks_path=../.githooks; fi
  configure_if_unset "$repo" core.hooksPath "$hooks_path"
done

printf '\nMode: %s\n' "$MODE"
printf 'Not configured by design: author identity, signing, credentials, proxy, fetch.pruneTags, rebase.autoStash.\n'
