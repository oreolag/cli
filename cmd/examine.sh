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
print_numa_header() {
  local id="$1"
  local cpus="$2"
  local mem="$3"
  local nvme="$4"
  local nics="$5"
  local gpus="$6"
  local ads="$7"

  separator_length="130"
  top_ruler="${bold}NUMA $id${normal} | CPUs: $cpus | Memory: $mem | Storage: $nvme"
  len=$(printf '%s' "$top_ruler" | sed -E 's/\x1B\[[0-9;]*m//g' | wc -m)
  filling=$(printf '%*s' $((separator_length - len - 1)) '')

  echo "+--------------------------------------------------------------------------------------------------------------------------------+"
  echo "| $top_ruler$filling |"
  echo "+--------------------------------------------------------------------------------------------------------------------------------+"
  echo "| Device Index : Port Index : Model      : Serial Number : BDF          : IP Address         : MAC Address       : Interface     |"
  echo "|--------------------------------------------------------------------------------------------------------------------------------|"
  echo "| 1            : 1          : ConnectX-7 : b5a5df7df3c0  : 000f:01:00.0 : 255.255.255.255/24 : 00:0A:35:0B:25:28 : enaccel0f0np0 |"
  echo "+--------------------------------------------------------------------------------------------------------------------------------+"
}

cmdb_print() {
    local topo="$1"
    local cmdb="$2"

    if [[ -z "$cmdb" && -z "$topo" ]]; then
        echo "na"
    elif [[ -n "$cmdb" && "$cmdb" == "$topo" ]]; then
        echo "$cmdb"
    else
        # topo wins
        local val="${topo:-$cmdb}"
        printf "%b%s%b\n" "$italic" "$val" "$normal"
    fi
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
model_name_system=$($CMDB_PATH/cmdb_get_model.sh)
model_name_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu model)
model_name=$(cmdb_print "$model_name_system" "$model_name_cmdb")

# CPU count
cpu_count_system=$($CMDB_PATH/cmdb_get_cpu.sh)
cpu_count_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu count)
cpu_count=$(cmdb_print "$cpu_count_system" "$cpu_count_cmdb")

# total memory
total_memory_system=$($CMDB_PATH/cmdb_get_memory.sh)
total_memory_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu memory)
total_memory=$(cmdb_print "$total_memory_system" "$total_memory_cmdb")

# total storage
total_storage_system=$($CMDB_PATH/cmdb_get_storage.sh "$STORAGE_UNIT")
total_storage_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu storage)
total_storage=$(cmdb_print "$total_storage_system" "$total_storage_cmdb")

echo ""
echo "${bold}$model_name${normal}"
echo "CPU(s)       : $cpu_count"
echo "Total memory : $total_memory"
echo "Total storage: $total_storage"
echo ""

# remove examine files
rm -rf $TMP_PATH/examine_*

# NUMA lstopo loop 
numa_nodes_lscpu=$(lscpu | grep -i "NUMA node(s)" | awk '{print $NF}')
for ((i=0; i<numa_nodes_lscpu; i++)); do
    # CPU list
    numa_cpus_system=$($CMDB_PATH/cmdb_get_cpu.sh $i)
    numa_cpus_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu numa $i list)
    numa_cpus=$(cmdb_print "$numa_cpus_system" "$numa_cpus_cmdb")
    # memory
    numa_memory_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu numa $i memory)
    # storage
    numa_storage_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu numa $i storage)
    # endata NICs
    endata_idx_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu numa $i endata)
    endata_num_cmdb=$(wc -w <<< "$endata_idx_cmdb")
    # device loop
    touch $TMP_PATH/examine_endata_$i
    for ((j=0; j<endata_num_cmdb; j++)); do
        ports_i_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml endata $j ports)
        # port loop
        endata_num_ifconfig=0
        for ((k=0; k<ports_i_cmdb; k++)); do
            # cmdb values
            name_i_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml endata $j name $k)
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
                # increase counter
                ((endata_num_ifconfig++))

                # add to file
                device_index="$j"
                port_index="$k"
                model=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml endata $j model)
                serial_number="-"
                bdf=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml endata $j bdf $k)
                ip_address="$ip_address_i_ifconfig"
                mac_address="$mac_i_ifconfig"
                connection_name="$name_i_cmdb"
                echo "$device_index $port_index $model $serial_number $bdf $ip_address $mac_address $connection_name" >> "$TMP_PATH/examine_endata_$i"
            fi
        done
    done
    
    # GPUs
    gpu_idx_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu numa $i gpu)
    gpu_num_cmdb=$(wc -w <<< "$gpu_idx_cmdb")
    # device loop
    touch $TMP_PATH/examine_gpus_$i
    gpu_num_lspci=0
    for ((j=0; j<gpu_num_cmdb; j++)); do
        vendor_i_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml gpu $j vendor)
        bdf_i_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml gpu $j bdf)
        bdf_i_lspci=$(lspci -D | grep -i "^$bdf_i_cmdb.*$vendor_i_cmdb")
        if [ ! "$bdf_i_lspci" = "" ]; then
            # increase counter
            ((gpu_num_lspci++))

            # add to file
            device_index="$j"
            port_index="-"
            model=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml gpu $j model)
            serial_number=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml gpu $j uuid)
            bdf=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml gpu $j bdf)
            ip_address="-"
            mac_address="-"
            connection_name="-"
            echo "$device_index $port_index $model $serial_number $bdf $ip_address $mac_address $connection_name" >> "$TMP_PATH/examine_gpus_$i"
        fi
    done
    
    # ADs
    # ...
    ad_num_lspci=0

    # print numa header
    print_numa_header "$i" "$numa_cpus" "$numa_memory_cmdb" "$numa_storage_cmdb" "$endata_num_ifconfig" "$gpu_num_lspci" "$ad_num_lspci"

done
