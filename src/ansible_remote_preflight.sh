#!/usr/bin/env bash
set -euo pipefail

ODEV_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
username="$(id -un)"
inventory_file="$1"

if [[ "$("$ODEV_PATH/src/tailscale_auth_status.sh")" != 1 ]]; then
  echo "Login failed: tailscale" >&2
  exit 1
fi

"$ODEV_PATH/src/get_ansible_hosts.sh" "$username" || exit 1
if [[ ! -f "$inventory_file" ]] ||
   ! inventory_json="$(ANSIBLE_INVENTORY_ANY_UNPARSED_IS_FAILED=true ansible-inventory -i "$inventory_file" --list)"; then
  echo "Invalid inventory: $inventory_file" >&2
  exit 1
fi
hosts="$(python3 -c 'import json, sys; print("\n".join(json.load(sys.stdin).get("my_hosts", {}).get("hosts", [])))' <<< "$inventory_json")"
if [[ -z "$hosts" ]]; then
  echo "No booked remote hosts: $username" >&2
  exit 1
fi

while IFS= read -r host; do
  if timeout 20s ssh -n -o BatchMode=yes -o ConnectTimeout=5 -- "$host" true; then
    continue
  else
    status=$?
    if [[ "$status" == 124 ]]; then
      echo "SSH check timed out: $host" >&2
    else
      echo "SSH check failed: $host" >&2
    fi
    exit 1
  fi
done <<< "$hosts"
