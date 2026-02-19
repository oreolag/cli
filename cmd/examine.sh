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
STORAGE_UNIT="TB"
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
    local topo="$1"
    local cmdb="$2"

    if [[ -z "$cmdb" && -z "$topo" ]]; then
        echo "na"
    elif [[ -n "$cmdb" && "$cmdb" == "$topo" ]]; then
        echo "$cmdb"
    else
        local val="${topo:-$cmdb}"
        printf "%b%s%b\n" "$italic" "$val" "$normal"
    fi
}

get_total_storage() {
    local unit="${1:-GB}"
    local total_bytes=0 sectors

    for d in /sys/block/nvme*n1; do
        [[ -f "$d/size" ]] || continue
        sectors=$(<"$d/size")           # 512B sectors
        total_bytes=$(( total_bytes + sectors*512 ))
    done

    case "$unit" in
        B)  printf "%sB\n"  "$total_bytes" ;;
        KB) printf "%.0fKB\n" "$(awk -v b="$total_bytes" 'BEGIN{print b/1024}')" ;;
        MB) printf "%.0fMB\n" "$(awk -v b="$total_bytes" 'BEGIN{print b/1024/1024}')" ;;
        GB) printf "%.0fGB\n" "$(awk -v b="$total_bytes" 'BEGIN{print b/1024/1024/1024}')" ;;
        TB) printf "%.1fTB\n" "$(awk -v b="$total_bytes" 'BEGIN{print b/1024/1024/1024/1024}')" ;;
        *)  echo "$total_bytes" ;;
    esac
}

get_numa_storage() {
    local numa_index="$1"
    local unit="${2:-GB}"
    local lstopo_file="${TMP_PATH:-/tmp}/lstopo_output"
    local total_bytes=0
    local sectors dev size

    [[ -f "$lstopo_file" ]] || { printf "0%s\n" "$unit"; return; }

    # extract block device names (e.g. nvme0n1) within NUMANode L#<numa_index>
    devs=$(awk -v i="$numa_index" '
      $0 ~ ("NUMANode L#" i) {f=1; next}
      f && $0 ~ /^NUMANode L#/ {exit}
      f { print }
    ' "$lstopo_file" | sed -nE 's/.*Block\(Disk\)[[:space:]]+"([^"]+)".*/\1/p' | tr '\n' ' ')

    for dev in $devs; do
        [[ -f "/sys/block/$dev/size" ]] || continue
        sectors=$(</sys/block/"$dev"/size)
        total_bytes=$(( total_bytes + sectors * 512 ))
    done

    case "$unit" in
        B)  printf "%sB\n" "$total_bytes" ;;
        KB) printf "%.0fKB\n" "$(awk -v b="$total_bytes" 'BEGIN{print b/1024}')" ;;
        MB) printf "%.0fMB\n" "$(awk -v b="$total_bytes" 'BEGIN{print b/1024/1024}')" ;;
        GB) printf "%.0fGB\n" "$(awk -v b="$total_bytes" 'BEGIN{print b/1024/1024/1024}')" ;;
        TB) printf "%.2fTB\n" "$(awk -v b="$total_bytes" 'BEGIN{print b/1024/1024/1024/1024}')" ;;
        *)  printf "%s\n" "$total_bytes" ;;
    esac
}

first_decimal() {
    echo "$1" | sed -E 's/^([0-9]+\.[0-9]).*/\1/'
}

bits_to_mask() {
    local p="$1"
    local full=$((p/8))
    local rem=$((p%8))
    local mask=()

    for ((i=0;i<4;i++)); do
        if ((i<full)); then
            mask+=(255)
        elif ((i==full)); then
            mask+=($((256 - 2**(8-rem))))
        else
            mask+=(0)
        fi
    done

    printf "%d.%d.%d.%d\n" "${mask[@]}"
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

# CPU model
model_name_lscpu=$(lscpu | awk -F: '/Model name/ {print $2}' | xargs)
if [[ "$model_name_lscpu" == *Cortex-* ]]; then
    model_name_lscpu=$(echo "$model_name_lscpu" | awk '{print $1}')
    model_name_lscpu="ARM $model_name_lscpu"
fi
model_name_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu model)
model_name=$(cmdb_print "$model_name_lscpu" "$model_name_cmdb")

# CPU list
cpu_list_lscpu=$(lscpu | grep -i "On-line CPU(s) list" | awk -F: '{print $2}' | xargs)
cpu_list_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu list)
cpu_list=$(cmdb_print "$cpu_list_lscpu" "$cpu_list_cmdb")

# total memory
total_memory_lstopo=$(awk -F'[()]' '/^Machine/ {print $2}' "$TMP_PATH/lstopo_output" | awk '{print $1}')
total_memory_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu memory)
total_memory=$(cmdb_print "$total_memory_lstopo" "$total_memory_cmdb")

# total storage
total_storage_sys=$(get_total_storage "$STORAGE_UNIT")
total_storage_sys=$(first_decimal "$total_storage_sys")$STORAGE_UNIT

echo ""
echo "${bold}$model_name${normal}"
echo "CPU(s)       : $cpu_list"
echo "Total memory : $total_memory"
echo "Total storage: $total_storage_sys"

# lstopo loop 
numa_nodes_lscpu=$(lscpu | grep -i "NUMA node(s)" | awk '{print $NF}')
for ((i=0; i<numa_nodes_lscpu; i++)); do
    # CPU list
    numa_cpus_lscpu=$(lscpu | grep -i "NUMA node${i} CPU(s)" | awk -F: '{print $2}' | xargs)
    numa_cpus_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu numa $i list)
    numa_cpus=$(cmdb_print "$numa_cpus_lscpu" "$numa_cpus_cmdb")
    # memory
    numa_memory_lstopo=$(grep -i "NUMANode L#$i" "$TMP_PATH/lstopo_output" | awk -F'[()]' '{print $2}' | awk '{print $NF}')
    numa_memory_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu numa $i memory)
    numa_memory=$(cmdb_print "$numa_memory_lstopo" "$numa_memory_cmdb")
    # storage
    numa_storage_lstopo=$(get_numa_storage $i "$STORAGE_UNIT")
    numa_storage_lstopo=$(first_decimal "$numa_storage_lstopo")$STORAGE_UNIT
    numa_storage_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu numa $i storage)
    numa_storage=$(cmdb_print "$numa_storage_lstopo" "$numa_storage_cmdb")
    # endata NICs
    endata_idx_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu numa $i endata)
    endata_num_cmdb=$(wc -w <<< "$endata_idx_cmdb")
    echo "endata_num_cmdb: $endata_num_cmdb"
    # device loop
    for ((j=0; j<endata_num_cmdb; j++)); do
        ports_i_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml endata $j ports)
        echo "ports_i_cmdb: $ports_i_cmdb"
        # port loop
        endata_num_ifconfig=0
        for ((k=0; k<ports_i_cmdb; k++)); do
            # cmdb values
            name_i_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml endata $j name $k)
            #bdf_i_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml endata $j bdf $k)
            mac_i_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml endata $j mac $k)
            ip_address_i_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml endata $j ip_address $k)
            ip_mask_i_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml endata $j ip_mask $k)
            ip_mask_i_cmdb=$(bits_to_mask "$ip_mask_i_cmdb")
            # ifconfig values
            mac_i_ifconfig=$(ifconfig "$name_i_cmdb" 2>/dev/null | awk '/ether/{print $2}')
            ip_address_i_ifconfig=$(ifconfig "$name_i_cmdb" 2>/dev/null | awk '/inet /{print $2}')
            ip_mask_i_ifconfig=$(ifconfig "$name_i_cmdb" 2>/dev/null | awk '/inet /{print $4}')
            # compare
            if [[ "$mac_i_cmdb" == "$mac_i_ifconfig" && "$ip_address_i_cmdb" == "$ip_address_i_ifconfig" && "$ip_mask_i_cmdb" == "$ip_mask_i_ifconfig" ]]; then
                ((endata_num_ifconfig++))
            fi
            # format
            #numa_storage=$(cmdb_print "$mac_i_ifconfig" "$mac_i_cmdb")
            #numa_storage=$(cmdb_print "$numa_storage_lstopo" "$numa_storage_cmdb")
            #numa_storage=$(cmdb_print "$numa_storage_lstopo" "$numa_storage_cmdb")

            echo $i,$j,$k
            echo "name_i_cmdb: $name_i_cmdb"
            #echo "bdf_i_cmdb: $bdf_i_cmdb"
            echo "mac_i_cmdb: $mac_i_cmdb"
            echo "ip_address_i_cmdb: $ip_address_i_cmdb"
            echo "ip_mask_i_cmdb: $ip_mask_i_cmdb"
            echo "mac_i_ifconfig: $mac_i_ifconfig"
            echo "ip_address_i_ifconfig: $ip_address_i_ifconfig"
            echo "ip_mask_i_ifconfig: $ip_mask_i_ifconfig"

        done

        echo "endata_num_ifconfig: $endata_num_ifconfig"

    done


    #numa_storage_lstopo=$(fmt_bytes "$numa_storage_lstopo" "$STORAGE_UNIT")


    #numa_nvme=$(awk "/NUMANode L#$i/,/NUMANode L#/ " "$TMP_PATH/lstopo_output" | grep -c 'Block(Disk) "nvme')
    #numa_nics=$(awk -v i="$i" '$0~("NUMANode L#"i){f=1;next} f&&/^NUMANode L#/{exit} f' "$TMP_PATH/lstopo_output" | grep -iE '\(Ethernet\)|\(Network\)' | wc -l)
    #numa_gpus=????
    #numa_ads=???
    
    
    
    echo $numa_cpus
    echo $numa_memory
    echo $numa_storage
    #echo $numa_nics
done
