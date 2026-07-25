#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/dev-client-common.sh"

[ "$#" -eq 0 ] || die "Usage: $0"
require_workspace_root
verify_remote_environment dev dev
require_dev_client

dev_root="$(configured_dev_root)"
validate_remote_root "$dev_root"
remote_root="$(configured_dev_client_root)"
validate_dev_client_root "$remote_root"

dev_root_q="$(dev_client_shell_quote "$dev_root")"
remote_root_q="$(dev_client_shell_quote "$remote_root")"
target_update_script='
set -euo pipefail
root="$1"
env_file="$root/.env"
[ -f "$env_file" ] || {
  printf "ERROR: device runtime configuration is absent\n" >&2
  exit 1
}
umask 077
backup="$root/.env.before-dev-client-authorization"
if [ ! -e "$backup" ]; then
  cp -p -- "$env_file" "$backup"
  chmod 600 "$backup"
fi
IFS= read -r counter_id
IFS= read -r counter_password
[ -n "$counter_id" ] && [ -n "$counter_password" ]
temporary="$env_file.tmp.$$"
trap '\''rm -f -- "$temporary"'\'' EXIT
grep -Ev "^(CHECKOUT_COUNTER_ID|CHECKOUT_COUNTER_PASSWORD)=" \
  "$env_file" > "$temporary" || [ "$?" -eq 1 ]
printf "%s\n" \
  "CHECKOUT_COUNTER_ID=$counter_id" \
  "CHECKOUT_COUNTER_PASSWORD=$counter_password" >> "$temporary"
chmod 600 "$temporary"
mv -f -- "$temporary" "$env_file"
trap - EXIT
printf "AUTHORIZED: dev-client credentials updated; values withheld\n"
'
target_update_base64="$(
  printf '%s' "$target_update_script" | base64 | tr -d '\n'
)"
target_update_command="
script=\$(printf '%s' '$target_update_base64' | base64 -d)
eval \"\$script\"
"
target_update_q="$(dev_client_shell_quote "$target_update_command")"

{
  ssh -o BatchMode=yes -o ConnectTimeout=10 dev \
    "bash -s -- $dev_root_q" <<'REMOTE_DEV'
set -euo pipefail
dev_root="$1"
env_file="$dev_root/self-checkout-infra/.env"
[ -f "$env_file" ]

read_value() {
  sed -n "s/^$1=//p" "$env_file" | tail -n1
}

admin_email="$(read_value FIRST_SUPERUSER)"
admin_password="$(read_value FIRST_SUPERUSER_PASSWORD)"
[ -n "$admin_email" ] && [ -n "$admin_password" ]
token="$(
  curl -fsS --connect-timeout 5 --max-time 15 \
    --data-urlencode "username=$admin_email" \
    --data-urlencode "password=$admin_password" \
    http://127.0.0.1:8000/api/v1/login/access-token |
    jq -er .access_token
)"
counters="$(
  curl -fsS --connect-timeout 5 --max-time 15 \
    -H "Authorization: Bearer $token" \
    http://127.0.0.1:8000/api/v1/checkout-counters/
)"
counter_id="$(
  printf '%s' "$counters" |
    jq -r '.data[] | select(.name == "dev-client") | .id' |
    head -n1
)"
counter_password="$(openssl rand -hex 24)"
payload="$(
  jq -cn --arg name dev-client --arg password "$counter_password" \
    '{name:$name,password:$password}'
)"
if [ -n "$counter_id" ]; then
  response="$(
    curl -fsS --connect-timeout 5 --max-time 15 -X PUT \
      -H "Authorization: Bearer $token" \
      -H 'Content-Type: application/json' \
      --data "$payload" \
      "http://127.0.0.1:8000/api/v1/checkout-counters/$counter_id"
  )"
else
  response="$(
    curl -fsS --connect-timeout 5 --max-time 15 -X POST \
      -H "Authorization: Bearer $token" \
      -H 'Content-Type: application/json' \
      --data "$payload" \
      http://127.0.0.1:8000/api/v1/checkout-counters/
  )"
  counter_id="$(printf '%s' "$response" | jq -er .id)"
fi
[ "$(printf '%s' "$response" | jq -r .name)" = dev-client ]
printf '%s\n%s\n' "$counter_id" "$counter_password"
REMOTE_DEV
} | ssh "${DEV_CLIENT_SSH_ARGS[@]}" "$DEV_CLIENT_HOST" \
  "bash -c $target_update_q -- $remote_root_q"

printf 'Restart the client and run ops/dev-client-status.sh to verify authentication.\n'
