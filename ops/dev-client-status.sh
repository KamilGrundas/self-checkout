#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/dev-client-common.sh"

optional=false
case "${1:-}" in
  '') ;;
  --optional) optional=true ;;
  -h|--help) printf 'Usage: %s [--optional]\n' "$0"; exit 0 ;;
  *) die "Unknown argument: $1" ;;
esac
[ "$#" -le 1 ] || die 'Too many arguments'

set +e
dev_client_probe
probe_status=$?
set -e
if [ "$probe_status" -eq 3 ] && [ "$optional" = true ]; then
  printf 'SKIPPED: dev-client unavailable; device status was not checked\n'
  exit 0
fi
[ "$probe_status" -eq 0 ] || exit "$probe_status"

remote_root="$(configured_dev_client_root)"
validate_dev_client_root "$remote_root"
remote_root_q="$(dev_client_shell_quote "$remote_root")"
ssh "${DEV_CLIENT_SSH_ARGS[@]}" "$DEV_CLIENT_HOST" "bash -s -- $remote_root_q" <<'REMOTE'
set -euo pipefail
root="$1"
binary="$root/target/release/self-checkout-client"
metadata="$root/.dev-client-deployment"
profile="$HOME/.config/self-checkout-client/dev-client-profile"

profile_value() {
  sed -n "s/^$1=//p" "$profile" | tail -n1
}

source_fingerprint() {
  (
    cd "$root"
    {
      printf '%s\n' Cargo.toml Cargo.lock rust-toolchain.toml
      find src assets -type f -print
    } | LC_ALL=C sort | while IFS= read -r file; do sha256sum "$file"; done | sha256sum | awk '{print $1}'
  )
}
find_client_pid() {
  local proc exe
  for proc in /proc/[0-9]*; do
    exe="$(readlink "$proc/exe" 2>/dev/null || true)"
    exe="${exe% (deleted)}"
    if [ "$exe" = "$binary" ]; then printf '%s\n' "${proc##*/}"; return 0; fi
  done
  return 1
}

[ -f "$metadata" ] && { printf 'deployment_metadata:\n'; sed -n '1,20p' "$metadata"; } \
  || printf 'deployment_metadata=absent\n'
[ -f "$profile" ] || {
  printf 'ERROR: cached target profile is absent; run ops/dev-client-inspect.sh --refresh\n' >&2
  exit 1
}
printf 'target_profile=%s refreshed_at=%s\n' \
  "$profile" "$(profile_value refreshed_at_utc)"
if [ -x "$binary" ]; then
  stat -c 'binary=%n owner=%U:%G mode=%a size=%s mtime=%y' "$binary"
  disk_hash="$(sha256sum "$binary" | awk '{print $1}')"
  printf 'binary_sha256=%s\n' "$disk_hash"
else
  printf 'binary_status=absent\n'
  exit 1
fi
pid="$(find_client_pid || true)"
if [ -z "$pid" ]; then
  printf 'process_status=not-running\n'
  exit 1
fi
printf 'process_status=running pid=%s elapsed=%s\n' "$pid" "$(ps -o etime= -p "$pid" | tr -d ' ')"
running_hash="$(sha256sum "/proc/$pid/exe" | awk '{print $1}')"
printf 'running_binary_sha256=%s\n' "$running_hash"
[ "$running_hash" = "$disk_hash" ] || { printf 'ERROR: running binary differs from the deployed binary\n' >&2; exit 1; }
current_source="$(source_fingerprint)"
printf 'current_source_sha256=%s\n' "$current_source"
recorded_source="$(sed -n 's/^source_sha256=//p' "$metadata" 2>/dev/null | tail -n1)"
[ -n "$recorded_source" ] && [ "$recorded_source" = "$current_source" ] \
  || { printf 'ERROR: deployed metadata does not match current synchronized sources\n' >&2; exit 1; }

printf 'graphical_environment:\n'
tr '\0' '\n' < "/proc/$pid/environ" | awk -F= \
  '$1 ~ /^(DISPLAY|WAYLAND_DISPLAY|XDG_RUNTIME_DIR|XDG_SESSION_TYPE)$/ {print}'
printf 'output_targets:\n'
for fd in 1 2; do printf 'fd%s=%s\n' "$fd" "$(readlink "/proc/$pid/fd/$fd" 2>/dev/null || printf unavailable)"; done
printf 'recent_startup_logs:\n'
startup_log_unit="$(profile_value startup_log_unit)"
case "$startup_log_unit" in
  none|'') printf 'No persistent startup log source is recorded in the target profile.\n' ;;
  *[!A-Za-z0-9@._-]*)
    printf 'ERROR: cached startup log unit is invalid\n' >&2
    exit 1
    ;;
  *)
    recent_startup="$(journalctl --since '-5 minutes' --no-pager -u "$startup_log_unit" -n 30 2>/dev/null || true)"
    printf '%s\n' "$recent_startup"
    restart_count="$(printf '%s\n' "$recent_startup" | grep -c 'Scheduled restart job' || true)"
    printf 'startup_restart_count_last_5m=%s\n' "$restart_count"
    [ "$restart_count" -le 2 ] \
      || { printf 'ERROR: cached startup mechanism appears to be in a restart loop\n' >&2; exit 1; }
    ;;
esac

if [ -f "$root/.env" ] && command -v curl >/dev/null 2>&1; then
  printf 'development_api_connectivity:\n'
  api_failed=false
  while IFS='=' read -r key base; do
    case "$key" in
      API_BASE_URL|ML_API_BASE_URL)
        endpoint="${base%/}/api/v1/utils/health-check/"
        if code="$(curl --connect-timeout 5 --max-time 10 -sS -o /dev/null -w '%{http_code}' "$endpoint")"; then
          printf '%s=%s http=%s\n' "$key" "$base" "$code"
          if [ "$code" -lt 200 ] || [ "$code" -ge 400 ]; then api_failed=true; fi
        else
          printf 'ERROR: %s=%s is not reachable from dev-client\n' "$key" "$base" >&2
          api_failed=true
        fi
        ;;
    esac
  done < "$root/.env"

  api_base_url="$(sed -n 's/^API_BASE_URL=//p' "$root/.env" | tail -n1)"
  counter_id="$(sed -n 's/^CHECKOUT_COUNTER_ID=//p' "$root/.env" | tail -n1)"
  counter_password="$(
    sed -n 's/^CHECKOUT_COUNTER_PASSWORD=//p' "$root/.env" | tail -n1
  )"
  case "$counter_id" in
    ''|*[!0-9A-Fa-f-]*)
      printf 'ERROR: checkout-counter ID is absent or invalid\n' >&2
      exit 1
      ;;
  esac
  case "$counter_password" in
    ''|*[!A-Za-z0-9._~-]*)
      printf 'ERROR: checkout-counter password is absent or unsupported by controlled validation\n' >&2
      exit 1
      ;;
  esac
  authentication_payload="$(
    printf '{"counter_id":"%s","password":"%s","client_id":"codex-dev-client-status"}' \
      "$counter_id" "$counter_password"
  )"
  authentication_code="$(
    curl --connect-timeout 5 --max-time 15 -sS -o /dev/null -w '%{http_code}' \
      -H 'Content-Type: application/json' \
      --data-binary "$authentication_payload" \
      "${api_base_url%/}/api/v1/checkout-sessions/connect"
  )"
  printf 'checkout_counter_authentication=name:%s http=%s\n' \
    "$(profile_value checkout_counter_name)" "$authentication_code"
  [ "$authentication_code" -ge 200 ] && [ "$authentication_code" -lt 300 ] \
    || { printf 'ERROR: dev-client authorization was rejected by the development backend\n' >&2; exit 1; }
  [ "$api_failed" = false ] || exit 1
fi
REMOTE
