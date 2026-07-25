#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/dev-client-common.sh"

optional=false
case "${1:-}" in
  '') ;;
  --optional) optional=true ;;
  -h|--help)
    printf 'Usage: %s [--optional]\n' "$0"
    printf 'Synchronize, build, restart through the startup strategy cached on dev-client, and verify the deployed binary.\n'
    exit 0
    ;;
  *) die "Unknown argument: $1" ;;
esac
[ "$#" -le 1 ] || die 'Too many arguments'

set +e
dev_client_probe
probe_status=$?
set -e
if [ "$probe_status" -eq 3 ] && [ "$optional" = true ]; then
  printf 'SKIPPED: dev-client unavailable; local validation remains authoritative\n'
  exit 0
fi
[ "$probe_status" -eq 0 ] || exit "$probe_status"

"$SCRIPT_DIR/dev-client-sync.sh" --apply
remote_root="$(configured_dev_client_root)"
validate_dev_client_root "$remote_root"
remote_root_q="$(dev_client_shell_quote "$remote_root")"

ssh "${DEV_CLIENT_SSH_ARGS[@]}" "$DEV_CLIENT_HOST" "bash -s -- $remote_root_q" <<'REMOTE'
set -euo pipefail
root="$1"
binary="$root/target/release/self-checkout-client"
previous="$root/target/release/self-checkout-client.previous"
metadata="$root/.dev-client-deployment"
profile="$HOME/.config/self-checkout-client/dev-client-profile"

profile_value() {
  sed -n "s/^$1=//p" "$profile" | tail -n1
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
source_fingerprint() {
  (
    cd "$root"
    {
      printf '%s\n' Cargo.toml Cargo.lock rust-toolchain.toml
      find src assets -type f -print
    } | LC_ALL=C sort | while IFS= read -r file; do sha256sum "$file"; done | sha256sum | awk '{print $1}'
  )
}

cd "$root"
[ -f Cargo.toml ] && [ -f Cargo.lock ] && [ -f rust-toolchain.toml ] \
  || { printf 'ERROR: synchronized build inputs are incomplete\n' >&2; exit 1; }
[ -f "$profile" ] || {
  printf 'ERROR: target profile is absent; run ops/dev-client-inspect.sh --refresh first\n' >&2
  exit 1
}
profile_root="$(profile_value client_root)"
[ "$profile_root" = "$root" ] || {
  printf 'ERROR: cached target profile describes a different client root\n' >&2
  exit 1
}
startup_strategy="$(profile_value startup_strategy)"
expected_parent="$(profile_value startup_parent)"
[ "$startup_strategy" = parent-respawn ] || {
  printf 'ERROR: cached startup strategy requires manual review: %s\n' "$startup_strategy" >&2
  exit 1
}
case "$expected_parent" in
  ''|*[!A-Za-z0-9._-]*)
    printf 'ERROR: cached startup parent is invalid\n' >&2
    exit 1
    ;;
esac
old_pid="$(find_client_pid || true)"
[ -n "$old_pid" ] || {
  printf 'ERROR: no running client was found; refusing to assume a graphical startup mechanism over SSH\n' >&2
  exit 1
}
parent_pid="$(ps -o ppid= -p "$old_pid" | tr -d ' ')"
[ "$(ps -o comm= -p "$parent_pid" | tr -d ' ')" = "$expected_parent" ] || {
  printf 'ERROR: running client no longer matches the cached startup profile\n' >&2
  exit 1
}

if [ -x "$binary" ]; then
  cp -p -- "$binary" "$previous.tmp"
  mv -f -- "$previous.tmp" "$previous"
fi
if [ -f "$HOME/.cargo/env" ]; then . "$HOME/.cargo/env"; fi
command -v cargo >/dev/null 2>&1 || { printf 'ERROR: Cargo is unavailable on dev-client\n' >&2; exit 1; }
printf 'Building current synchronized sources with %s\n' "$(cargo --version)"
cargo build --locked --release
[ -x "$binary" ] || { printf 'ERROR: release binary was not produced\n' >&2; exit 1; }

source_hash="$(source_fingerprint)"
binary_hash="$(sha256sum "$binary" | awk '{print $1}')"
metadata_tmp="$metadata.tmp"
{
  printf 'deployed_at_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'source_sha256=%s\n' "$source_hash"
  printf 'binary_sha256=%s\n' "$binary_hash"
  printf 'toolchain=%s\n' "$(rustc --version)"
  printf 'startup=%s\n' "$startup_strategy"
} > "$metadata_tmp"
chmod 600 "$metadata_tmp"
mv -f -- "$metadata_tmp" "$metadata"

printf 'Restarting client through cached strategy: %s\n' "$startup_strategy"
kill -TERM "$old_pid"
for _ in $(seq 1 40); do
  new_pid="$(find_client_pid || true)"
  if [ -n "$new_pid" ] && [ "$new_pid" != "$old_pid" ]; then break; fi
  sleep 1
done
new_pid="${new_pid:-}"
[ -n "$new_pid" ] && [ "$new_pid" != "$old_pid" ] \
  || { printf 'ERROR: client did not restart through the cached startup strategy\n' >&2; exit 1; }
sleep 5
kill -0 "$new_pid" 2>/dev/null || { printf 'ERROR: restarted client exited immediately\n' >&2; exit 1; }
running_hash="$(sha256sum "/proc/$new_pid/exe" | awk '{print $1}')"
[ "$running_hash" = "$binary_hash" ] \
  || { printf 'ERROR: running process is not the newly built binary\n' >&2; exit 1; }
printf 'DEPLOYED: pid=%s source_sha256=%s binary_sha256=%s\n' "$new_pid" "$source_hash" "$binary_hash"
printf 'Rollback binary retained at %s\n' "$previous"
printf 'Application stdout/stderr targets: %s / %s\n' \
  "$(readlink "/proc/$new_pid/fd/1" 2>/dev/null || printf unavailable)" \
  "$(readlink "/proc/$new_pid/fd/2" 2>/dev/null || printf unavailable)"
REMOTE

printf 'Build and process verification passed. Run ops/dev-client-status.sh for API connectivity and current runtime details.\n'
