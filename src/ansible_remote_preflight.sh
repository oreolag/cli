#!/usr/bin/env bash
set -euo pipefail

ODEV_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
username="$(id -un)"
inventory_file="$1"

if [[ "$("$ODEV_PATH/src/tailscale_auth_status.sh")" != 1 ]]; then
  python3 "$ODEV_PATH/src/odev_messages.py" --error login_failed tailscale
  exit 1
fi

"$ODEV_PATH/src/get_ansible_hosts.sh" "$username" || exit 1
if [[ ! -f "$inventory_file" ]] ||
   ! inventory_json="$(ANSIBLE_INVENTORY_ANY_UNPARSED_IS_FAILED=true ansible-inventory -i "$inventory_file" --list)"; then
  python3 "$ODEV_PATH/src/odev_messages.py" --error invalid_inventory -- "$inventory_file"
  exit 1
fi
hosts="$(python3 -c 'import json, sys; print("\n".join(json.load(sys.stdin).get("my_hosts", {}).get("hosts", [])))' <<< "$inventory_json")"
if [[ -z "$hosts" ]]; then
  python3 "$ODEV_PATH/src/odev_messages.py" --error no_booked_remote_hosts -- "$username"
  exit 1
fi

while IFS= read -r host; do
  if timeout 20s ssh -n -o BatchMode=yes -o ConnectTimeout=5 -- "$host" true; then
    continue
  else
    status=$?
    if [[ "$status" == 124 ]]; then
      python3 "$ODEV_PATH/src/odev_messages.py" --error ssh_check_timed_out -- "$host"
    else
      python3 "$ODEV_PATH/src/odev_messages.py" --error ssh_check_failed -- "$host"
    fi
    exit 1
  fi
done <<< "$hosts"
