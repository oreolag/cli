#!/usr/bin/env bash
set -euo pipefail

ODEV_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cmdb_path="$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths cmdb)"
mtu_default="$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" constants mtu_default)"
mtu_default="${mtu_default:-1500}"
if [[ ! "$mtu_default" =~ ^[1-9][0-9]*$ ]]; then
  echo "Invalid default MTU: $mtu_default" >&2
  exit 1
fi

cmdb_file="$cmdb_path/$(hostname -s).yml"
[[ -f "$cmdb_file" ]] || exit 0

# Read the configured device and uplink IDs in one pass.
uplinks="$(python3 - "$cmdb_file" <<'PY'
import sys
import yaml

with open(sys.argv[1]) as stream:
    cmdb = yaml.safe_load(stream) or {}

for device in (cmdb.get("devices") or {}).get("endata") or []:
    for uplink in device.get("uplinks") or []:
        if uplink.get("name"):
            print(device["id"], uplink["id"], uplink["name"], sep="\t")
PY
)"

status=0
if [[ -n "$uplinks" ]]; then
  while IFS=$'\t' read -r device port name; do
    if [[ ! "$name" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.:-]*$ ]]; then
      echo "Invalid interface name: $device:$port ($name)" >&2
      status=1
    elif ! sudo -n ifconfig "$name" mtu "$mtu_default" up; then
      echo "Could not restore MTU: $device:$port ($name)" >&2
      status=1
    fi
  done <<< "$uplinks"
fi
exit "$status"
