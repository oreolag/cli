#!/bin/bash

# example: odev examine

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMAND="-"

# derive from SCRIPT_DIR
CLI_NAME="$(basename "$(dirname "$SCRIPT_DIR")")"
SUBCOMMAND="examine"
ODEV_PATH="${ODEV_PATH:-"$(dirname "$SCRIPT_DIR")"}"

# get hostname
url="${HOSTNAME}"
hostname="${url%%.*}"

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

# constants
CMDB_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths cmdb)")"
COLOR_NIC=$($ODEV_PATH/src/constant_get.sh $ODEV_PATH COLOR_NIC)
COLOR_NVIDIA=$($ODEV_PATH/src/constant_get.sh $ODEV_PATH COLOR_NVIDIA)
COLOR_XILINX=$($ODEV_PATH/src/constant_get.sh $ODEV_PATH COLOR_XILINX)
STORAGE_UNIT="TB"
STRING_ACCEL="accel"
STRING_GPUS="gpu"
STRING_NICS="endata"
TMP_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths tmp)")"

# set KEY
KEY="$(printf '%s' "$SUBCOMMAND" | tr '[:lower:]' '[:upper:]')"

# read command description, command flags
command_description="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "$KEY")"
mapfile -t flags < <("$ODEV_PATH/src/cmd_flags_read.sh" "$ODEV_PATH" "$KEY")

# (maybe) print help
print_range="0"
print_default="0"
print_both="0"
"$ODEV_PATH/src/cmd_help_print.sh" --maybe \
  "$CLI_NAME" "$COMMAND" "$SUBCOMMAND" "$command_description" \
  "$print_range" "$print_default" "$print_both" \
  "${flags[@]}" -- "$@" && exit 0 || true

# parse and assign flags
flag=$1

# check on flags
if [[ -n "$flag" && "$flag" != "--tools" && "$flag" != "-t" && "$flag" != "--servers" && "$flag" != "-s" ]]; then
    echo "Unknown flag: $flag"
    exit 1
fi

# set command flags
# ...

# print tools
if [ "$flag" = "--tools" ] || [ "$flag" = "-t" ]; then
  $ODEV_PATH/src/required_tools_print.sh $ODEV_PATH
  exit 0
fi

# print servers
if [ "$flag" = "--servers" ] || [ "$flag" = "-s" ]; then
  echo "show servers"
  exit 0
fi

# check on CMDB
if [[ ! -f "$CMDB_PATH/$hostname.yml" ]]; then
    echo "Missing file: $CMDB_PATH/$hostname.yml"
    exit 1
fi

# helper functions
print_numa_table() {
    local id="$1" cpus="$2" mem="$3" nvme="$4"
    local nics="$5" gpus="$6" ads="$7"

    awk -F '\t' -v id="$id" -v cpus="$cpus" -v mem="$mem" -v nvme="$nvme" \
        -v nics="$nics" -v gpus="$gpus" -v ads="$ads" \
        -v bold="$bold" -v reset="$normal" \
        -v nic_color="$COLOR_NIC" -v gpu_color="$COLOR_NVIDIA" -v accel_color="$COLOR_XILINX" \
        -v nic_label="$STRING_NICS" -v gpu_label="$STRING_GPUS" -v accel_label="$STRING_ACCEL" '
        function visible_length(value) {
            # Strip CSI formatting and charset selection (tput sgr0 includes ESC(B).
            gsub(/\033\[[0-?]*[ -\/]*[@-~]/, "", value)
            gsub(/\033[()][0-2A-Z]/, "", value)
            return length(value)
        }
        function rule(left, right,    i) {
            printf "%s", left
            for (i = 0; i < inner_width; i++) printf "-"
            printf "%s\n", right
        }
        function add_legend(label, color) {
            if (legend_plain != "") {
                legend_plain = legend_plain " "
                legend = legend " "
            }
            legend_plain = legend_plain label
            legend = legend color label reset
        }
        BEGIN {
            split("Device Index|Port Index|Model|Serial Number|BDF|IP Address|MAC Address|Interface", headers, "[|]")
            split("12 10 10 13 12 18 17 13", widths, " ")
            for (i = 1; i <= 8; i++)
                if (length(headers[i]) > widths[i]) widths[i] = length(headers[i])
            colors[ARGV[1]] = nic_color
            colors[ARGV[2]] = accel_color
            colors[ARGV[3]] = gpu_color
            enabled[ARGV[1]] = nics > 0
            enabled[ARGV[2]] = ads > 0
            enabled[ARGV[3]] = gpus > 0
        }
        enabled[FILENAME] {
            count++
            groups[count] = FILENAME
            for (i = 1; i <= 8; i++) {
                value = ($i == "-" ? "" : $i)
                cells[count, i] = value
                if (visible_length(value) > widths[i]) widths[i] = visible_length(value)
            }
        }
        END {
            top = bold "NUMA " id reset " | CPUs: " cpus " | Memory: " mem " | Storage: " nvme
            inner_width = 2 + 7 * 3
            for (i = 1; i <= 8; i++) inner_width += widths[i]
            if (visible_length(top) + 2 > inner_width) {
                widths[8] += visible_length(top) + 2 - inner_width
                inner_width = visible_length(top) + 2
            }
            if (ads > 0) add_legend(accel_label, accel_color)
            if (gpus > 0) add_legend(gpu_label, gpu_color)
            if (nics > 0) add_legend(nic_label, nic_color)
            printf "%*s%s\n", inner_width + 1 - length(legend_plain), "", legend
            rule("+", "+")
            printf "| %s%*s |\n", top, inner_width - visible_length(top) - 2, ""
            rule("+", "+")
            printf "| "
            for (i = 1; i <= 8; i++)
                printf "%s%*s%s", headers[i], widths[i] - length(headers[i]), "", (i < 8 ? " : " : " |\n")
            rule("|", "|")
            for (row = 1; row <= count; row++) {
                printf "|%s ", colors[groups[row]]
                for (i = 1; i <= 8; i++)
                    printf "%s%*s%s", cells[row, i], widths[i] - visible_length(cells[row, i]), "", (i < 8 ? " : " : " ")
                printf "%s|\n", reset
                if (row == count || groups[row] != groups[row + 1]) rule("+", "+")
            }
            if (count == 0) rule("+", "+")
        }
    ' "$TMP_PATH/examine_endata_$id" "$TMP_PATH/examine_accel_$id" "$TMP_PATH/examine_gpu_$id"
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
        name="${name%%@*}"                      # remove peer suffix (e.g. @if7)
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
echo "Operating system   : ${bold}${NAME} ${VERSION}${normal}"
description=$(lsb_release -d | awk -F'\t' '{print $2}' | sed 's/^[^0-9]*//')
codename=$(lsb_release -c | awk -F':' '{print $2}' | xargs)
linux_kernel=$(uname -r)
uptime_info=$(uptime -p)
echo "Description        : ${bold}$description${normal}"
echo "Codename           : ${bold}$codename${normal}"
echo "Linux kernel       : ${bold}$linux_kernel${normal}"
echo "Uptime             : ${bold}$uptime_info${normal}"

# lstopo
#rm -rf $TMP_PATH/lstopo_output
sudo $ODEV_PATH/src/rm.sh "$ODEV_PATH" "$TMP_PATH/lstopo_output"

lstopo-no-graphics 2>/dev/null > $TMP_PATH/lstopo_output

# CPU model
#model_name_system=$($CMDB_PATH/cmdb_get_model.sh)
model_name_system=$($ODEV_PATH/src/cmdb_get_model.sh)
model_name_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu model)
model_name=$(cmdb_print "$model_name_system" "$model_name_cmdb")

# CPU count
#cpu_count_system=$($CMDB_PATH/cmdb_get_cpu.sh)
cpu_count_system=$($ODEV_PATH/src/cmdb_get_cpu.sh)
cpu_count_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu count)
cpu_count=$(cmdb_print "$cpu_count_system" "$cpu_count_cmdb")

# total memory
#total_memory_system=$($CMDB_PATH/cmdb_get_memory.sh)
total_memory_system=$($ODEV_PATH/src/cmdb_get_memory.sh)
total_memory_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu memory)
total_memory=$(cmdb_print "$total_memory_system" "$total_memory_cmdb")

# total storage
total_storage=$("$ODEV_PATH/src/cmdb_get_storage.sh" "$STORAGE_UNIT") || exit 1

# print CPU information
echo ""
echo "CPU model          : ${bold}$model_name${normal}"
echo "CPU(s)             : ${bold}$cpu_count${normal}"
echo "Total memory       : ${bold}$total_memory${normal}"
echo "Total storage      : ${bold}$total_storage${normal}"
echo ""

# print tailscale information
installed="$("$ODEV_PATH/src/required_tools_print.sh" "$ODEV_PATH" "tailscale")"
if [[ "$installed" == "1" ]]; then
    logged_in="$("$ODEV_PATH/src/tailscale_auth_status.sh")"
    if [[ "$logged_in" == "1" ]]; then
        tailnet_info="$(tailscale status --json 2>/dev/null | python3 -c '
import json
import sys

try:
    status = json.load(sys.stdin)
    address = next(ip for ip in status.get("TailscaleIPs", []) if ":" not in ip)
    name = (status.get("CurrentTailnet") or {}).get("MagicDNSSuffix", "")
    if status.get("BackendState") == "Running" and name:
        print(address, name.rstrip("."))
except (ValueError, AttributeError, StopIteration):
    pass
' 2>/dev/null)" || tailnet_info=""
        if [[ -n "$tailnet_info" ]]; then
            read -r tailnet_ip tailnet_name <<< "$tailnet_info"
            tailnet_interface="$(ip -4 -o addr show | awk -v address="$tailnet_ip" '
                { split($4, ip, "/"); if (ip[1] == address) { sub(/@.*/, "", $2); print $2 } }
            ')"
            #echo ""
            echo "Tailnet interface  : ${bold}${tailnet_interface:-n/a}${normal}"
            echo "Tailnet IP         : ${bold}$tailnet_ip${normal}"
            echo "Tailnet name       : ${bold}$tailnet_name${normal}"
            echo ""
        fi
    fi
fi

# remove examine files
for f in "$TMP_PATH"/examine_*; do
    [ -e "$f" ] || continue
    sudo "$ODEV_PATH/src/rm.sh" "$ODEV_PATH" "$f"
done

# NUMA lscpu loop 
numa_nodes_lscpu=$(lscpu | grep -i "NUMA node(s)" | awk '{print $NF}')
for ((i=0; i<numa_nodes_lscpu; i++)); do
    # CPU list
    #numa_cpus_system=$($CMDB_PATH/cmdb_get_cpu.sh $i)
    numa_cpus_system=$($ODEV_PATH/src/cmdb_get_cpu.sh $i)
    numa_cpus_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu numa $i list)
    numa_cpus=$(cmdb_print "$numa_cpus_system" "$numa_cpus_cmdb")
    # memory
    #numa_memory_system=$($CMDB_PATH/cmdb_get_memory.sh $i)
    numa_memory_system=$($ODEV_PATH/src/cmdb_get_memory.sh $i)
    numa_memory_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu numa $i memory)
    numa_memory=$(cmdb_print "$numa_memory_system" "$numa_memory_cmdb")
    # storage
    numa_storage=$("$ODEV_PATH/src/cmdb_get_storage.sh" "$STORAGE_UNIT" "$i") || exit 1
    # endata NICs
    endata_idx_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu numa $i endata)
    endata_num_cmdb=$(wc -w <<< "$endata_idx_cmdb")
    # device loop
    touch $TMP_PATH/examine_endata_$i
    for ((j=0; j<endata_num_cmdb; j++)); do
        ports_i_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml endata $j ports)
        # port loop
        endata_num_ifconfig=0
        for ((k=0; k<ports_i_cmdb; k++)); do
            # cmdb values
            name_i_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml endata $j name $k)
            mac_i_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml endata $j mac $k)
            ip_address_i_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml endata $j ip_address $k)
            ip_mask_i_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml endata $j ip_mask $k)
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
                model=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml endata $j model)
                serial_number="-"
                bdf=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml endata $j bdf $k)
                ip_address="$ip_address_i_ifconfig/$ip_mask_i_cmdb"
                mac_address="$mac_i_ifconfig"
                connection_name="$name_i_cmdb"
                # read previous line
                last_line=$(tail -n 1 "$TMP_PATH/examine_endata_$i" 2>/dev/null || true)
                if [[ -n "$last_line" ]]; then
                    bdf_0=$(awk -F '\t' 'END{print $5}' "$TMP_PATH/examine_endata_$i")
                    is_consecutive=$(is_consecutive_bdf "$bdf_0" "$bdf")
                    if [ "$is_consecutive" = "1" ]; then
                        device_index="-"
                        model="-"
                    fi
                fi
                # add to file
                printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$device_index" "$port_index" "$model" "$serial_number" "$bdf" "$ip_address" "$mac_address" "$connection_name" >> "$TMP_PATH/examine_endata_$i"
            fi
        done
    done
    
    # GPUs
    gpu_idx_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu numa $i gpu)
    gpu_num_cmdb=$(wc -w <<< "$gpu_idx_cmdb")
    # device loop
    touch $TMP_PATH/examine_gpu_$i
    gpu_num_lspci=0
    for ((j=0; j<gpu_num_cmdb; j++)); do
        vendor_i_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml gpu $j vendor)
        bdf_i_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml gpu $j bdf)
        bdf_i_lspci=$(lspci -D | grep -i "^$bdf_i_cmdb.*$vendor_i_cmdb")
        if [ ! "$bdf_i_lspci" = "" ]; then
            # increase counter
            ((gpu_num_lspci++))

            # add to file
            device_index="$j"
            port_index="-"
            model=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml gpu $j model)
            serial_number=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml gpu $j uuid)
            bdf=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml gpu $j bdf)
            ip_address="-"
            mac_address="-"
            connection_name="-"
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$device_index" "$port_index" "$model" "$serial_number" "$bdf" "$ip_address" "$mac_address" "$connection_name" >> "$TMP_PATH/examine_gpu_$i"
        fi
    done
    
    # ADs
    accel_idx_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu numa $i accel)
    accel_num_cmdb=$(wc -w <<< "$accel_idx_cmdb")
    # device loop
    touch $TMP_PATH/examine_accel_$i
    accel_num_lspci=0
    for ((j=0; j<accel_num_cmdb; j++)); do
        vendor_i_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml accel $j vendor)
        bdf_i_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml accel $j bdf)
        bdf_i_lspci=$(lspci -D | grep -i "^$bdf_i_cmdb.*$vendor_i_cmdb")
        #bdf_i_lspci="0000:c4:00.0 Processing accelerators: Xilinx Corporation Alveo U55C" # remove for final version!!!!!!!
        if [ ! "$bdf_i_lspci" = "" ]; then
            # increase counter
            ((accel_num_lspci++))

            # add to file
            device_index="$j"
            model=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml accel $j model)
            serial_number=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml accel $j serial)
            bdf=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml accel $j bdf)
            ports_i_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml accel $j ports)
            # port loop
            for ((k=0; k<ports_i_cmdb; k++)); do
                port_index=$k
                # check on port index
                if [ "$port_index" -gt 0 ]; then
                    device_index="-"
                    model="-"
                    serial_number="-"
                    bdf="-"
                fi
                ip_address_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml accel $j ip_address $k)
                ip_mask_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml accel $j ip_mask $k)
                ip_address_cmdb="$ip_address_cmdb/$ip_mask_cmdb"
                mac_address_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml accel $j mac $k)
                # check on connection name
                connection_name_ifconfig=$(get_connection_name "$ip_address_cmdb" "$mac_address_cmdb")
                connection_name_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml accel $j name $k)
                if [[ "$connection_name_cmdb" != "$connection_name_ifconfig" ]]; then
                    connection_name="-"
                else
                    connection_name="$connection_name_ifconfig"
                fi
                # add to file
                printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$device_index" "$port_index" "$model" "$serial_number" "$bdf" "$ip_address_cmdb" "$mac_address_cmdb" "$connection_name" >> "$TMP_PATH/examine_accel_$i"
            done
        fi
    done

    # Size all columns together before printing this NUMA table.
    print_numa_table "$i" "$numa_cpus" "$numa_memory" "$numa_storage" "$endata_num_ifconfig" "$gpu_num_lspci" "$accel_num_lspci"

done

# author: https://github.com/jmoya82
