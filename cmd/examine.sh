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
CMDB_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths cmdb)")"
TMP_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths tmp)")"

# check on cmdb_get.py
if [[ ! -f "$CMDB_PATH/cmdb_get.py" ]]; then
    echo "Error: $CMDB_PATH/cmdb_get.py not found"
    exit 1
fi

# check on CMDB
if [[ ! -f "$CMDB_PATH/$hostname.yml" ]]; then
    echo "Error: $CMDB_PATH/$hostname.yml not found"
    exit 1
fi

# helper functions
print_numa_header (){
  echo "+-----------------------------------------------------------------------------------------+"
  echo "| NUMA $i | CPUs: $numa_cpus | $numa_memory | NVMe: $numa_nvme | NICs: $numa_nics | GPUs: $numa_gpus | ADs: $numa_ads |            Driver Version: 580.126.09     CUDA Version: 13.0     |"
  echo "+-----------------------------------------------------------------------------------------+"
}

cmdb_print() {
    local cmdb="$1"
    local topo="$2"

    if [[ -z "$cmdb" && -z "$topo" ]]; then
        echo "na"
    elif [[ -n "$cmdb" && "$cmdb" == "$topo" ]]; then
        echo "$cmdb"
    else
        local val="${topo:-$cmdb}"
        printf "%b%s%b\n" "$italic" "$val" "$normal"
    fi
}

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
for ((i=0; i<numa_nodes; i++)); do
    # CPU list
    numa_cpus_lstopo=$(lscpu | grep -i "NUMA node${i} CPU(s)" | awk -F: '{print $2}' | xargs)
    numa_cpus_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu 0 list)
    
    numa_cpus_lstopo="0-10"
    numa_cpus=$(cmdb_print "$numa_cpus_cmdb" "$numa_cpus_lstopo")
    
    numa_memory=$(lstopo-no-graphics 2>/dev/null | grep -i "NUMANode L#$i" | awk -F'[()]' '{print $2}' | awk '{print $NF}')
    numa_nvme=$(awk "/NUMANode L#$i/,/NUMANode L#/ " "$TMP_PATH/lstopo_output" | grep -c 'Block(Disk) "nvme')
    numa_nics=$(awk -v i="$i" '$0~("NUMANode L#"i){f=1;next} f&&/^NUMANode L#/{exit} f' "$TMP_PATH/lstopo_output" | grep -iE '\(Ethernet\)|\(Network\)' | wc -l)
    numa_gpus=????
    numa_ads=???
    
    
    
    echo $numa_cpus_lstopo
    echo $numa_cpus_cmdb
    echo $numa_cpus
    echo $numa_memory
    echo $numa_nvme
    echo $numa_nics
done
