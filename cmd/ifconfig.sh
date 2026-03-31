#!/bin/bash

# example: odev examine

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMAND="-"

# derive from SCRIPT_DIR
CLI_NAME="$(basename "$(dirname "$SCRIPT_DIR")")"
SUBCOMMAND="ifconfig"
ODEV_PATH="${ODEV_PATH:-"$(dirname "$SCRIPT_DIR")"}"

# get hostname
url="${HOSTNAME}"
hostname="${url%%.*}"

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

# constants
CMDB_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths cmdb)")"
COLOR_NIC=$($ODEV_PATH/src/color_get.sh $ODEV_PATH COLOR_NIC)
COLOR_NVIDIA=$($ODEV_PATH/src/color_get.sh $ODEV_PATH COLOR_NVIDIA)
COLOR_XILINX=$($ODEV_PATH/src/color_get.sh $ODEV_PATH COLOR_XILINX)
#STORAGE_UNIT="TB"
#STRING_ACCEL="Adaptive devices"
#STRING_GPUS="GPUs"
#STRING_NICS="NICs"
TMP_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths tmp)")"

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
# ...

# check on flags
# ...

# set command flags
# ...

# print tools
# ...

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

print_iface() {
    local name="$1"
    local numa="$2"
    local device="$3"
    local port="$4"
    local ip="$5"
    local mask="$6"
    local mac="$7"

    mtu=$(ip link show $name | awk '{for(i=1;i<=NF;i++) if($i=="mtu") print $(i+1)}')

    echo "$name: flags=<numa=$numa,device=$device,port=$port>  mtu $mtu"
    echo "        inet $ip netmask $mask"
    echo "        ether $mac"
    echo ""
}

# run examine silently
if ! compgen -G "$TMP_PATH/examine_*" > /dev/null; then
  "$ODEV_PATH/cmd/examine.sh" > /dev/null 2>&1
fi

# NUMA lscpu loop 
numa_nodes_lscpu=$(lscpu | grep -i "NUMA node(s)" | awk '{print $NF}')
for ((i=0; i<numa_nodes_lscpu; i++)); do

    # endata
    #cat "$TMP_PATH/examine_endata_$i"
    while read -r line; do
        name=$(awk '{print $NF}' <<< "$line")
        if [ "$name" != "-" ]; then
            device=$(awk '{print $1}' "$TMP_PATH/examine_endata_$i")
            port=$(awk '{print $2}' "$TMP_PATH/examine_endata_$i")
            ip_and_mask=$(awk '{print $6}' "$TMP_PATH/examine_endata_$i")
            ip="${ip_and_mask%%/*}"
            mask="${ip_and_mask##*/}"
            mask=$(bits_to_mask "$mask")
            mac=$(awk '{print $7}' "$TMP_PATH/examine_endata_$i")

            echo $ip
            echo $mac

            mtu="100"

            print_iface $name $i $device $port $ip $mask $mac

        fi
    done < "$TMP_PATH/examine_endata_$i"




    # accel
    cat "$TMP_PATH/examine_accel_$i"


done


# author: https://github.com/jmoya82