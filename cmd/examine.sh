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
COLOR_NIC=$($ODEV_PATH/src/color_get.sh $ODEV_PATH COLOR_NIC)
COLOR_NVIDIA=$($ODEV_PATH/src/color_get.sh $ODEV_PATH COLOR_NVIDIA)
COLOR_XILINX=$($ODEV_PATH/src/color_get.sh $ODEV_PATH COLOR_XILINX)
STORAGE_UNIT="TB"
TMP_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths tmp)")"

# check on CMDB scripts
cmdb_scripts="cmdb_get.py cmdb_get_cpu.sh cmdb_get_memory.sh cmdb_get_model.sh cmdb_get_storage.sh"
for script in $cmdb_scripts; do
    if [[ ! -f "$CMDB_PATH/$script" ]]; then
        echo "Error: $CMDB_PATH/$script not found"
        exit 1
    fi
done

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
  #echo "| 1            : 1          : ConnectX-7 : b5a5df7df3c0  : 000f:01:00.0 : 255.255.255.255/24 : 00:0A:35:0B:25:28 : enaccel0f0np0 |"
  #echo "+--------------------------------------------------------------------------------------------------------------------------------+"
}

print_numa() {
    local file="$1"
    local color="${2:-}"
    [[ -f "$file" ]] || return

    awk -v color="$color" -v reset="$normal" '{
        for(i=1;i<=NF;i++) if($i=="-") $i=" ";

        dev=$1; port=$2; model=$3; serial=$4; bdf=$5; ip=$6; mac=$7; ifc=$8;

        printf("|%s %-12s : %-10s : %-10s : %-13s : %-12s : %-18s : %-17s : %-13s %s|\n",
               color, dev, port, model, serial, bdf, ip, mac, ifc, reset);
    }' "$file"

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

is_consecutive_bdf() {
    local prev="$1"
    local curr="$2"

    local prefix_prev=${prev%.*}
    local prefix_curr=${curr%.*}

    local idx_prev=${prev##*.}
    local idx_curr=${curr##*.}

    if [[ "$prefix_prev" == "$prefix_curr" && $idx_curr -eq $((idx_prev + 1)) ]]; then
        echo "1"
    else
        echo "0"
    fi
}

get_connection_name() {
    local ip="$1"
    local mac="$2"

    ip -o link | while read -r num name rest; do
        name="${name%:}"                        # remove trailing :
        curmac=$(ip link show "$name" | awk '/link\/ether/ {print $2}')
        curip=$(ip -4 -o addr show "$name" | awk '{print $4}' | cut -d/ -f1)

        if [[ "$curip" == "$ip" && "$curmac" == "$mac" ]]; then
            echo "$name"
            return 0
        fi
    done
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
    numa_memory_system=$($CMDB_PATH/cmdb_get_memory.sh $i)
    numa_memory_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu numa $i memory)
    numa_memory=$(cmdb_print "$numa_memory_system" "$numa_memory_cmdb")
    # storage
    numa_storage_system=$($CMDB_PATH/cmdb_get_storage.sh "$STORAGE_UNIT" "$i")
    numa_storage_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu numa $i storage)
    numa_storage=$(cmdb_print "$numa_storage_system" "$numa_storage_cmdb")
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
            ip_mask_i_cmdb_mask=$(bits_to_mask "$ip_mask_i_cmdb")
            # ifconfig values
            mac_i_ifconfig=$(ifconfig "$name_i_cmdb" 2>/dev/null | awk '/ether/{print $2}')
            ip_address_i_ifconfig=$(ifconfig "$name_i_cmdb" 2>/dev/null | awk '/inet /{print $2}')
            ip_mask_i_ifconfig=$(ifconfig "$name_i_cmdb" 2>/dev/null | awk '/inet /{print $4}')
            # compare
            if [[ "$mac_i_cmdb" == "$mac_i_ifconfig" && "$ip_address_i_cmdb" == "$ip_address_i_ifconfig" && "$ip_mask_i_cmdb_mask" == "$ip_mask_i_ifconfig" ]]; then
                # increase counter
                ((endata_num_ifconfig++))

                # add to file
                device_index="$j"
                port_index="$k"
                model=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml endata $j model)
                serial_number="-"
                bdf=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml endata $j bdf $k)
                ip_address="$ip_address_i_ifconfig/$ip_mask_i_cmdb"
                mac_address="$mac_i_ifconfig"
                connection_name="$name_i_cmdb"
                # read previous line
                last_line=$(tail -n 1 "$TMP_PATH/examine_endata_$i" 2>/dev/null || true)
                if [[ -n "$last_line" ]]; then
                    bdf_0=$(awk 'END{print $5}' "$TMP_PATH/examine_endata_$i")
                    is_consecutive=$(is_consecutive_bdf "$bdf_0" "$bdf")
                    if [ "$is_consecutive" = "1" ]; then
                        device_index="-"
                        model="-"
                    fi
                fi
                # add to file
                echo "$device_index $port_index $model $serial_number $bdf $ip_address $mac_address $connection_name" >> "$TMP_PATH/examine_endata_$i"
            fi
        done
    done
    
    # GPUs
    gpu_idx_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu numa $i gpu)
    gpu_num_cmdb=$(wc -w <<< "$gpu_idx_cmdb")
    # device loop
    touch $TMP_PATH/examine_gpu_$i
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
            echo "$device_index $port_index $model $serial_number $bdf $ip_address $mac_address $connection_name" >> "$TMP_PATH/examine_gpu_$i"
        fi
    done
    
    # ADs
    accel_idx_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu numa $i accel)
    accel_num_cmdb=$(wc -w <<< "$accel_idx_cmdb")
    # device loop
    touch $TMP_PATH/examine_accel_$i
    accel_num_lspci=0
    for ((j=0; j<accel_num_cmdb; j++)); do
        vendor_i_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml accel $j vendor)
        bdf_i_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml accel $j bdf)
        bdf_i_lspci=$(lspci -D | grep -i "^$bdf_i_cmdb.*$vendor_i_cmdb")
        bdf_i_lspci="0000:c4:00.0 Processing accelerators: Xilinx Corporation Alveo U55C"
        echo "vendor_i_cmdb: $vendor_i_cmdb"
        echo "bdf_i_cmdb: $bdf_i_cmdb"
        echo "bdf_i_lspci: $bdf_i_lspci"
        if [ ! "$bdf_i_lspci" = "" ]; then
            # increase counter
            ((accel_num_lspci++))

            # add to file
            device_index="$j"
            model=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml accel $j model)
            serial_number=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml accel $j serial)
            bdf=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml accel $j bdf)
            ports_i_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml accel $j ports)
            # port loop
            for ((k=0; k<ports_i_cmdb; k++)); do
                port_index=$k
                ip_address_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml accel $j ip_address $k)
                ip_mask_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml accel $j ip_mask $k)
                ip_address_cmdb="$ip_address_cmdb/$ip_mask_cmdb"
                mac_address_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml accel $j mac $k)
                connection_name_ifconfig=$(get_connection_name "$ip_address_cmdb" "$mac_address_cmdb")
                connection_name_cmdb=$($CMDB_PATH/cmdb_get.py --db $CMDB_PATH/$hostname.yml accel $j name $k)
                if [[ "$connection_name_cmdb" != "$connection_name_ifconfig" ]]; then
                    connection_name="-"
                else
                    connection_name="$connection_name_ifconfig"
                fi
            done
            echo "$device_index $port_index $model $serial_number $bdf $ip_address_cmdb $mac_address_cmdb $connection_name" >> "$TMP_PATH/examine_accel_$i"
        fi
    done

    # print numa header
    print_numa_header "$i" "$numa_cpus" "$numa_memory" "$numa_storage" "$endata_num_ifconfig" "$gpu_num_lspci" "$accel_num_lspci"
    print_numa "$TMP_PATH/examine_endata_$i" "$COLOR_NIC"
    print_numa "$TMP_PATH/examine_gpu_$i" "$COLOR_NVIDIA"
    print_numa "$TMP_PATH/examine_accel_$i" "$COLOR_XILINX"
done
