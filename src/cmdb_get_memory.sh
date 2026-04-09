#!/usr/bin/env bash
set -euo pipefail

numa_index="${1:-}"

if [ -z "$numa_index" ]; then
    # total memory
    total_memory=$(lstopo-no-graphics 2>/dev/null | awk -F'[()]' '/^Machine/ {print $2}' | awk '{print $1}')
    echo "$total_memory"
else
    # numa memory
    numa_memory_lstopo=$(lstopo-no-graphics 2>/dev/null | grep -i "NUMANode L#$numa_index" | awk -F'[()]' '{print $2}' | awk '{print $NF}')
    echo "$numa_memory_lstopo"
fi