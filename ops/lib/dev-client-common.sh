#!/usr/bin/env bash

DEV_CLIENT_LIB_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$DEV_CLIENT_LIB_DIR/common.sh"

DEV_CLIENT_HOST="${SELF_CHECKOUT_DEV_CLIENT_HOST:-dev-client}"
DEV_CLIENT_CONNECT_TIMEOUT="${SELF_CHECKOUT_DEV_CLIENT_CONNECT_TIMEOUT:-5}"

case "$DEV_CLIENT_HOST" in
  ''|*[!A-Za-z0-9._-]*)
    printf 'ERROR: invalid dev-client SSH alias: %s\n' "$DEV_CLIENT_HOST" >&2
    exit 2
    ;;
esac
case "$DEV_CLIENT_CONNECT_TIMEOUT" in
  ''|*[!0-9]*)
    printf 'ERROR: SELF_CHECKOUT_DEV_CLIENT_CONNECT_TIMEOUT must be numeric\n' >&2
    exit 2
    ;;
esac
if [ "$DEV_CLIENT_CONNECT_TIMEOUT" -lt 1 ] || [ "$DEV_CLIENT_CONNECT_TIMEOUT" -gt 30 ]; then
  printf 'ERROR: SELF_CHECKOUT_DEV_CLIENT_CONNECT_TIMEOUT must be between 1 and 30 seconds\n' >&2
  exit 2
fi

DEV_CLIENT_SSH_ARGS=(
  -o BatchMode=yes
  -o "ConnectTimeout=$DEV_CLIENT_CONNECT_TIMEOUT"
  -o ConnectionAttempts=1
)

dev_client_probe() {
  local error_file status error_text
  require_command ssh
  if ! ssh -G "$DEV_CLIENT_HOST" >/dev/null 2>&1; then
    printf 'ERROR: dev-client SSH alias is not configured: %s\n' "$DEV_CLIENT_HOST" >&2
    return 2
  fi
  error_file="$(mktemp "${TMPDIR:-/tmp}/self-checkout-dev-client.XXXXXX")"
  if ssh -n "${DEV_CLIENT_SSH_ARGS[@]}" "$DEV_CLIENT_HOST" true 2>"$error_file"; then
    rm -f -- "$error_file"
    return 0
  else
    status=$?
  fi
  error_text="$(sed -n '1,8p' "$error_file")"
  rm -f -- "$error_file"

  case "$error_text" in
    *'Permission denied'*|*'Host key verification failed'*|*'Bad configuration option'*|*'command-line:'*)
      printf 'ERROR: dev-client SSH authentication or configuration failed: %s\n' "$error_text" >&2
      return 2
      ;;
    *'Connection timed out'*|*'Connection refused'*|*'No route to host'*|*'Network is unreachable'*|*'Could not resolve hostname'*)
      printf 'UNAVAILABLE: %s cannot be reached within %ss\n' "$DEV_CLIENT_HOST" "$DEV_CLIENT_CONNECT_TIMEOUT" >&2
      return 3
      ;;
    *)
      printf 'ERROR: dev-client SSH check failed (ssh exit %s): %s\n' "$status" "$error_text" >&2
      return 2
      ;;
  esac
}

require_dev_client() {
  local status
  set +e
  dev_client_probe
  status=$?
  set -e
  [ "$status" -eq 0 ] || exit "$status"
}

dev_client_remote_home() {
  ssh -n "${DEV_CLIENT_SSH_ARGS[@]}" "$DEV_CLIENT_HOST" 'printf "%s\n" "$HOME"'
}

configured_dev_client_root() {
  local remote_home
  if [ -n "${SELF_CHECKOUT_DEV_CLIENT_ROOT:-}" ]; then
    printf '%s\n' "$SELF_CHECKOUT_DEV_CLIENT_ROOT"
    return
  fi
  remote_home="$(dev_client_remote_home)"
  printf '%s/self-checkout-client\n' "$remote_home"
}

validate_dev_client_root() {
  local root="$1"
  case "$root" in
    ''|/|/home|/root|/tmp|/var|/usr|/opt) die "Unsafe dev-client root: '$root'" ;;
    /*/self-checkout-client) ;;
    *) die "dev-client root must be an absolute path ending in /self-checkout-client: '$root'" ;;
  esac
  case "$root" in
    *$'\n'*|*$'\r'*) die 'dev-client root must not contain newlines' ;;
  esac
  if printf '%s' "$root" | LC_ALL=C grep -q '[^A-Za-z0-9_./ -]'; then
    die "dev-client root contains unsupported characters: '$root'"
  fi
}

dev_client_local_root() {
  printf '%s/self-checkout-client\n' "$WORKSPACE_ROOT"
}

dev_client_rsync_shell() {
  printf 'ssh -o BatchMode=yes -o ConnectTimeout=%s -o ConnectionAttempts=1\n' \
    "$DEV_CLIENT_CONNECT_TIMEOUT"
}

dev_client_shell_quote() {
  local value="$1"
  printf "'%s'" "$(printf '%s' "$value" | sed "s/'/'\\\\''/g")"
}
