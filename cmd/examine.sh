#!/bin/bash

# example: odev examine

# early exit
url="${HOSTNAME}"
hostname="${url%%.*}"

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW="$(basename "${BASH_SOURCE[0]}" .sh)"

# derive from SCRIPT_DIR
ODEV_PATH="${ODEV_PATH:-"$(dirname "$SCRIPT_DIR")"}"

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

# constants
TMP_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths tmp)")"

# print operating system information
. /etc/os-release
echo "${bold}${NAME} ${VERSION}${normal}"
description=$(lsb_release -d | awk -F'\t' '{print $2}' | sed 's/^[^0-9]*//')
codename=$(lsb_release -c | awk -F':' '{print $2}' | xargs)
linux_kernel=$(uname -r)
uptime_info=$(uptime -p)
echo "Description : ${bold}$description${normal}"
echo "Codename    : ${bold}$codename${normal}"
echo "Linux kernel: ${bold}$linux_kernel${normal}"
echo "Uptime      : ${bold}$uptime_info${normal}"

# lstopo
rm -rf $TMP_PATH/lstopo_output
lstopo-no-graphics 2>/dev/null > $TMP_PATH/lstopo_output

# get total memory
total_memory=$(awk -F'[()]' '/^Machine/ {print $2}' "$TMP_PATH/lstopo_output" | awk '{print $1}')

# lscpu
model_name=$(lscpu | awk -F: '/Model name/ {print $2}' | xargs)
if [[ "$model_name" == *Cortex-* ]]; then
    model_name=$(echo "$model_name" | awk '{print $1}')
    model_name="ARM $model_name"
fi
cpu_count=$(lscpu | grep -i "^CPU(s):" | awk '{print $2}')
online_cpus=$(lscpu | grep -i "On-line CPU(s) list" | awk -F: '{print $2}' | xargs)

echo ""
echo "${bold}$model_name${normal}"
echo "CPU(s): $cpu_count ($online_cpus)"
echo "Total memory: $total_memory"

# lstopo loop 
numa_nodes=$(lscpu | grep -i "NUMA node(s)" | awk '{print $NF}')

echo $numa_nodes