#!/usr/bin/env bash
set -euo pipefail

unit="${1:-GB}"
numa_index="${2:-}"

# Count available space once per mounted local disk filesystem.
# Follow partitions/LVM back to their disks to determine NUMA locality.
total_bytes=$(python3 - "$numa_index" <<'PYTHON'
import json
import os
from pathlib import Path
import subprocess
import sys

requested_node = sys.argv[1]
topology = json.loads(subprocess.check_output(
    ["lsblk", "--json", "--tree", "--output", "NAME,TYPE,MAJ:MIN,MOUNTPOINTS"],
    text=True,
))["blockdevices"]
filesystems = {}

def visit(device, disks=()):
    if device["type"] == "disk":
        disks = (device["name"],)
    if disks:
        entry = filesystems.setdefault(device["maj:min"], {"mounts": [], "disks": set()})
        entry["disks"].update(disks)
        entry["mounts"].extend(m for m in device.get("mountpoints", []) if m and m != "[SWAP]")
    for child in device.get("children", []):
        visit(child, disks)

for device in topology:
    visit(device)

node_paths = list(Path("/sys/devices/system/node").glob("node[0-9]*"))

def disk_node(disk):
    path = (Path("/sys/class/block") / disk).resolve()
    # SATA disks may expose NUMA locality on their parent PCI controller.
    for parent in (path, *path.parents):
        node_file = parent / "numa_node"
        if node_file.is_file():
            node = int(node_file.read_text().strip())
            if node >= 0:
                return str(node)
    if len(node_paths) == 1:
        return node_paths[0].name[4:]
    raise RuntimeError(f"Cannot determine NUMA node for {disk}")

total = 0
for entry in filesystems.values():
    if not entry["mounts"]:
        continue
    if requested_node:
        nodes = {disk_node(disk) for disk in entry["disks"]}
        if len(nodes) != 1:
            raise RuntimeError("Filesystem spans multiple NUMA nodes")
        if requested_node not in nodes:
            continue
    stats = os.statvfs(entry["mounts"][0])
    total += max(0, stats.f_bavail) * stats.f_frsize
print(total)
PYTHON
)

# ---- single output block ----
case "$unit" in
    B)  printf "%sB\n"  "$total_bytes" ;;
    KB) printf "%.0fKB\n" "$(awk -v b="$total_bytes" 'BEGIN{print b/1024}')" ;;
    MB) printf "%.0fMB\n" "$(awk -v b="$total_bytes" 'BEGIN{print b/1024/1024}')" ;;
    GB) printf "%.0fGB\n" "$(awk -v b="$total_bytes" 'BEGIN{print b/1024/1024/1024}')" ;;
    TB) printf "%.1fTB\n" "$(awk -v b="$total_bytes" 'BEGIN{print b/1024/1024/1024/1024}')" ;;
    *)  printf "%s\n" "$total_bytes" ;;
esac