#!/bin/bash

# example: get ip

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBCOMMAND="$(basename "${BASH_SOURCE[0]}" .sh)"

# derive from SCRIPT_DIR
CLI_NAME="$(basename "$(dirname "$SCRIPT_DIR")")"
COMMAND="$(basename "$SCRIPT_DIR")"
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
TMP_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths tmp)")"

# check on users
# ...

# check on tools
# ...

# set KEY
KEY="$(printf '%s_%s' "$COMMAND" "$SUBCOMMAND" | tr '[:lower:]' '[:upper:]')"

# read command description, command flags, and mandatory flags
command_description="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "$KEY")"
mapfile -t flags < <("$ODEV_PATH/src/cmd_flags_read.sh" "$ODEV_PATH" "$KEY")
mandatory_flags="$("$ODEV_PATH/src/cmd_mandatory_flags_read.sh" "$ODEV_PATH" "$KEY")"

# (maybe) print help
print_range="0"
print_default="0"
print_both="0"
"$ODEV_PATH/src/cmd_help_print.sh" --maybe \
  "$CLI_NAME" "$COMMAND" "$SUBCOMMAND" "$command_description" \
  "$print_range" "$print_default" "$print_both" \
  "${flags[@]}" -- "$@" && exit 0 || true

# parse flags
parsed_flags="$("$ODEV_PATH/src/cmd_parse.sh" --params "${flags[@]}" -- "$@")" || exit 1

# run interactive prompt
parsed_flags="$("$ODEV_PATH/src/cmd_prompt.sh" --required "$mandatory_flags" --params "${flags[@]}" -- "$parsed_flags")" || exit 1

# read flags
if [[ -n "$parsed_flags" ]]; then
  declare -A V
  while IFS='=' read -r k v; do
    V["$k"]="$v"
  done <<< "$parsed_flags"
fi

# assign flags
device=${V[device]}
numa=${V[numa]}
port=${V[port]}
type=${V[type]}

echo $device
echo $numa
echo $port
echo $type

exit

# check on flags
# ...

# check on devices
if [[ ! "$devices" =~ ^[0-9]+(,\ ?[0-9]+)*$ ]]; then
    echo "Invalid devices format: $devices"
    exit 1
fi

# convert devices to an array
devices_array=$(echo "$devices" | tr -d ' ')
IFS=',' read -ra devices_array <<< "$devices_array"

# remove duplicates
mapfile -t devices_array < <(printf "%s\n" "${devices_array[@]}" | awk '!seen[$0]++')

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
    local type="$1"
    local name="$2"
    local numa="$3"
    local device="$4"
    local port="$5"

    mtu=$(ip link show $name | awk '{for(i=1;i<=NF;i++) if($i=="mtu") print $(i+1)}')

    echo "$name: $type=<numa=$numa,device=$device,port=$port>  mtu $mtu"
    ifconfig $name | tail -n +2
}

# run examine silently
if ! compgen -G "$TMP_PATH/examine_*" > /dev/null; then
  "$ODEV_PATH/cmd/examine.sh" > /dev/null 2>&1
fi

# NUMA lscpu loop 
numa_nodes_lscpu=$(lscpu | grep -i "NUMA node(s)" | awk '{print $NF}')
for ((i=0; i<numa_nodes_lscpu; i++)); do
    # endata
    while read -r line; do
        name=$(awk '{print $NF}' <<< "$line")
        if [ "$name" != "-" ]; then
            device=$(awk '{print $1}' "$TMP_PATH/examine_endata_$i")
            port=$(awk '{print $2}' "$TMP_PATH/examine_endata_$i")
            print_iface "endata" $name $i $device $port
        fi
    done < "$TMP_PATH/examine_endata_$i"
    # accel
    while read -r line; do
        name=$(awk '{print $NF}' <<< "$line")
        if [ "$name" != "-" ]; then
            device=$(awk '{print $1}' "$TMP_PATH/examine_accel_$i")
            port=$(awk '{print $2}' "$TMP_PATH/examine_accel_$i")
            print_iface "accel" $name $i $device $port
        fi
    done < "$TMP_PATH/examine_accel_$i"
done

# author: https://github.com/jmoya82