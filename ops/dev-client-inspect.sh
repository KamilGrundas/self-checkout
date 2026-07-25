#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/dev-client-common.sh"

mode=read
case "${1:-}" in
  '') ;;
  --refresh) mode=refresh ;;
  -h|--help)
    printf 'Usage: %s [--refresh]\n' "$0"
    printf 'Reads the cached non-secret target profile; --refresh rescans and replaces it.\n'
    exit 0
    ;;
  *) die "Unknown argument: $1" ;;
esac
[ "$#" -le 1 ] || die 'Too many arguments'

require_workspace_root
require_dev_client
remote_root="$(configured_dev_client_root)"
validate_dev_client_root "$remote_root"
remote_root_q="$(dev_client_shell_quote "$remote_root")"
mode_q="$(dev_client_shell_quote "$mode")"

ssh "${DEV_CLIENT_SSH_ARGS[@]}" "$DEV_CLIENT_HOST" \
  "bash -s -- $mode_q $remote_root_q" <<'REMOTE'
set -euo pipefail
mode="$1"
root="$2"
profile_dir="$HOME/.config/self-checkout-client"
profile="$profile_dir/dev-client-profile"

safe_value() {
  printf '%s' "$1" | tr '\r\n' '  '
}

if [ "$mode" = read ]; then
  if [ ! -f "$profile" ]; then
    printf 'ERROR: target profile is absent: %s\n' "$profile" >&2
    printf 'Run ops/dev-client-inspect.sh --refresh after read-only inspection of a new or changed target.\n' >&2
    exit 4
  fi
  printf 'cached_target_profile=%s\n' "$profile"
  sed -n '1,240p' "$profile"
  printf 'live_identity: user=%s home=%s host=%s\n' "$(id -un)" "$HOME" "$(hostname)"
  [ -d "$root" ] && printf 'live_client_root=present\n' || printf 'live_client_root=absent\n'
  exit 0
fi

mkdir -p -- "$profile_dir"
chmod 700 "$profile_dir"
api_route="$(sed -n 's/^api_route=//p' "$profile" 2>/dev/null | tail -n1)"
api_route_service="$(sed -n 's/^api_route_service=//p' "$profile" 2>/dev/null | tail -n1)"
checkout_counter_name="$(
  sed -n 's/^checkout_counter_name=//p' "$profile" 2>/dev/null | tail -n1
)"
[ -n "$api_route" ] || api_route=unknown
[ -n "$api_route_service" ] || api_route_service=none
[ -n "$checkout_counter_name" ] || checkout_counter_name=dev-client
temporary="$profile.tmp"
trap 'rm -f -- "$temporary"' EXIT

if [ -r /etc/os-release ]; then
  os_name="$(. /etc/os-release; safe_value "${PRETTY_NAME:-${ID:-unknown}}")"
else
  os_name="$(safe_value "$(uname -s)")"
fi
architecture="$(safe_value "$(uname -m)")"
kernel="$(safe_value "$(uname -r)")"
if [ -f "$HOME/.cargo/env" ]; then . "$HOME/.cargo/env"; fi
cargo_version="$(cd "$root" 2>/dev/null && cargo --version 2>/dev/null || printf unavailable)"
rustc_version="$(cd "$root" 2>/dev/null && rustc --version 2>/dev/null || printf unavailable)"
rustup_toolchain="$(cd "$root" 2>/dev/null && rustup show active-toolchain 2>/dev/null || printf unavailable)"
rsync_version="$(rsync --version 2>/dev/null | sed -n '1p' || printf unavailable)"

binary="$root/target/release/self-checkout-client"
client_pid=''
for proc in /proc/[0-9]*; do
  exe="$(readlink "$proc/exe" 2>/dev/null || true)"
  exe="${exe% (deleted)}"
  if [ "$exe" = "$binary" ]; then client_pid="${proc##*/}"; break; fi
done
startup_strategy=manual-review
startup_parent=unknown
startup_log_unit=none
stdout_target=unknown
stderr_target=unknown
if [ -n "$client_pid" ]; then
  parent_pid="$(ps -o ppid= -p "$client_pid" | tr -d ' ')"
  startup_parent="$(ps -o comm= -p "$parent_pid" | tr -d ' ')"
  stdout_target="$(readlink "/proc/$client_pid/fd/1" 2>/dev/null || printf unknown)"
  stderr_target="$(readlink "/proc/$client_pid/fd/2" 2>/dev/null || printf unknown)"
  if [ -n "$startup_parent" ] && [ "$startup_parent" != unknown ]; then
    startup_strategy=parent-respawn
  fi
fi
if systemctl is-active --quiet getty@tty1.service 2>/dev/null; then
  startup_log_unit=getty@tty1.service
fi

session_type=unknown
display_name=unknown
runtime_dir=unknown
if [ -n "$client_pid" ]; then
  while IFS='=' read -r key value; do
    case "$key" in
      XDG_SESSION_TYPE) session_type="$(safe_value "$value")" ;;
      WAYLAND_DISPLAY|DISPLAY)
        [ "$display_name" = unknown ] && display_name="$(safe_value "$value")"
        ;;
      XDG_RUNTIME_DIR) runtime_dir="$(safe_value "$value")" ;;
    esac
  done < <(tr '\0' '\n' < "/proc/$client_pid/environ")
fi

package_manager=unknown
build_runtime_packages=unknown
if command -v dpkg-query >/dev/null 2>&1; then
  package_manager=dpkg
  build_runtime_packages="$(
    dpkg-query -W -f='${binary:Package}\n' 2>/dev/null \
      | awk 'tolower($0) ~ /(clang|cmake|pkg-config|udev|v4l|wayland|xkbcommon|vulkan|mesa|libinput)/ {print}' \
      | LC_ALL=C sort | paste -sd, -
  )"
elif command -v rpm >/dev/null 2>&1; then
  package_manager=rpm
  build_runtime_packages="$(
    rpm -qa 2>/dev/null \
      | awk 'tolower($0) ~ /(clang|cmake|pkg-config|udev|v4l|wayland|xkbcommon|vulkan|mesa|libinput)/ {print}' \
      | LC_ALL=C sort | paste -sd, -
  )"
fi

api_base_url=unset
ml_api_base_url=unset
checkout_counter_credentials=absent
if [ -f "$root/.env" ]; then
  api_base_url="$(sed -n 's/^API_BASE_URL=//p' "$root/.env" | tail -n1)"
  ml_api_base_url="$(sed -n 's/^ML_API_BASE_URL=//p' "$root/.env" | tail -n1)"
  counter_id="$(sed -n 's/^CHECKOUT_COUNTER_ID=//p' "$root/.env" | tail -n1)"
  counter_password="$(
    sed -n 's/^CHECKOUT_COUNTER_PASSWORD=//p' "$root/.env" | tail -n1
  )"
  if [ -n "$counter_id" ] && [ -n "$counter_password" ]; then
    checkout_counter_credentials=present
  elif [ -n "$counter_id" ] || [ -n "$counter_password" ]; then
    checkout_counter_credentials=incomplete
  fi
fi

{
  printf 'profile_version=1\n'
  printf 'refreshed_at_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'hostname=%s\n' "$(safe_value "$(hostname)")"
  printf 'user=%s\n' "$(safe_value "$(id -un)")"
  printf 'home=%s\n' "$(safe_value "$HOME")"
  printf 'os=%s\n' "$os_name"
  printf 'architecture=%s\n' "$architecture"
  printf 'kernel=%s\n' "$kernel"
  printf 'client_root=%s\n' "$(safe_value "$root")"
  printf 'binary=%s\n' "$(safe_value "$binary")"
  printf 'cargo=%s\n' "$(safe_value "$cargo_version")"
  printf 'rustc=%s\n' "$(safe_value "$rustc_version")"
  printf 'rustup_toolchain=%s\n' "$(safe_value "$rustup_toolchain")"
  printf 'rsync=%s\n' "$(safe_value "$rsync_version")"
  printf 'package_manager=%s\n' "$package_manager"
  printf 'build_runtime_packages=%s\n' "$(safe_value "$build_runtime_packages")"
  printf 'startup_strategy=%s\n' "$(safe_value "$startup_strategy")"
  printf 'startup_parent=%s\n' "$(safe_value "$startup_parent")"
  printf 'startup_log_unit=%s\n' "$(safe_value "$startup_log_unit")"
  printf 'session_type=%s\n' "$(safe_value "$session_type")"
  printf 'display_name=%s\n' "$(safe_value "$display_name")"
  printf 'runtime_dir=%s\n' "$(safe_value "$runtime_dir")"
  printf 'stdout_target=%s\n' "$(safe_value "$stdout_target")"
  printf 'stderr_target=%s\n' "$(safe_value "$stderr_target")"
  printf 'backend_environment=dev\n'
  printf 'api_base_url=%s\n' "$(safe_value "$api_base_url")"
  printf 'ml_api_base_url=%s\n' "$(safe_value "$ml_api_base_url")"
  printf 'api_route=%s\n' "$(safe_value "$api_route")"
  printf 'api_route_service=%s\n' "$(safe_value "$api_route_service")"
  printf 'checkout_counter_name=%s\n' \
    "$(safe_value "$checkout_counter_name")"
  printf 'checkout_counter_credentials=%s\n' \
    "$checkout_counter_credentials"
  printf 'cursor_policy=hidden\n'
} > "$temporary"
chmod 600 "$temporary"
mv -f -- "$temporary" "$profile"
trap - EXIT
printf 'refreshed_target_profile=%s\n' "$profile"
sed -n '1,240p' "$profile"
REMOTE
