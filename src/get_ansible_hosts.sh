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

command=(timeout 90s python3 "$ODEV_PATH/booking/client.py" --odev-path "$ODEV_PATH" --booked-hosts)
if [[ "$EUID" == 0 ]]; then
  command=(sudo -H -u "$username" -- "${command[@]}")
fi

status=0
if [[ "$("$ODEV_PATH/src/tailscale_auth_status.sh")" != 1 ]]; then
  # Keep only the local template when Tailscale is unavailable.
  :
elif booked_hosts=$("${command[@]}"); then
  if [[ -n "$booked_hosts" ]]; then
    if magicdns_hosts=$(tailscale status --json | python3 -c '
import json
import re
import sys

status = json.load(sys.stdin)
tailnet = status.get("CurrentTailnet") or {}
suffix = (tailnet.get("MagicDNSSuffix") or status.get("MagicDNSSuffix") or "").rstrip(".").lower()
peers = {peer.get("DNSName", "").rstrip(".").lower() for peer in (status.get("Peer") or {}).values()}
hosts = []
for host in sys.argv[1].splitlines():
    name = f"{host.lower()}.{suffix}"
    if not suffix or not re.fullmatch(r"[a-z0-9][a-z0-9.-]*", name) or name not in peers:
        sys.exit(f"No MagicDNS peer found for {host}")
    hosts.append(name)
print("\n".join(hosts))
' "$booked_hosts"); then
      printf '%s\n' "$magicdns_hosts" >> "$inventory"
    else
      status=1
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
