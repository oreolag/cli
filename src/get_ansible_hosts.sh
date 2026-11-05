#!/usr/bin/env bash
set -euo pipefail

ODEV_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
username="$1"
if [[ ! "$username" =~ ^[a-zA-Z_][a-zA-Z0-9_.-]*$ ]] || ! id -u -- "$username" >/dev/null 2>&1; then
  echo "Invalid user: $username" >&2
  exit 1
fi
if [[ "$EUID" != 0 && "$username" != "$(id -un)" ]]; then
  echo "Permission denied: $username" >&2
  exit 1
fi

TMP_PATH="$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths tmp)"
temp_dir="$(mktemp -d "$TMP_PATH/.odev-hosts.XXXXXXXX")"
trap 'rm -rf -- "$temp_dir"' EXIT
inventory="$temp_dir/hosts"
cp "$ODEV_PATH/templates/playbooks/hosts" "$inventory"
chmod 600 "$inventory"

command=(timeout 20s python3 "$ODEV_PATH/booking/client.py" --odev-path "$ODEV_PATH" --booked-hosts)
if [[ "$EUID" == 0 ]]; then
  command=(sudo -H -u "$username" -- "${command[@]}")
fi

status=0
if [[ "$("$ODEV_PATH/src/tailscale_auth_status.sh")" != 1 ]]; then
  # Keep only the local template when Tailscale is unavailable.
  :
elif booked_hosts=$("${command[@]}" 2>/dev/null); then
  if [[ -n "$booked_hosts" ]]; then
    while IFS= read -r host; do
      if [[ ! "$host" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]]; then
        status=1
        break
      fi
    done <<< "$booked_hosts"
    if [[ "$status" == 0 ]]; then
      printf '%s\n' "$booked_hosts" >> "$inventory"
    fi
  fi
else
  status=1
fi

if [[ "$EUID" == 0 ]]; then
  chown "$username" "$inventory"
fi
mv -fT -- "$inventory" "$TMP_PATH/hosts_$username"
if [[ "$status" != 0 ]]; then
  echo "Could not retrieve booked hosts for $username" >&2
fi
exit "$status"
