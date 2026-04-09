#!/usr/bin/env bash
set -euo pipefail

numa_index="${1:-}"

if [ -z "$numa_index" ]; then
    # total CPUs
    cpu_count_lscpu=$(lscpu | grep -i "^CPU(s):" | awk '{print $2}')
    echo "$cpu_count_lscpu"
else
    # CPUs in NUMA node
    numa_cpus_lscpu=$(lscpu | grep -i "NUMA node${numa_index} CPU(s)" | awk -F: '{print $2}' | xargs)
    echo "$numa_cpus_lscpu"
fi