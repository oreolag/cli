#!/bin/bash

# example: odev get mac

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

# check on numa
numa_devices=$($ODEV_PATH/src/cmdb_get.py cpu numa $numa $type)
if [[ ! "$numa" =~ ^[0-9]+$ ]] || [ "$numa_devices" = "" ]; then
  echo "Invalid numa: $numa" >&2
  exit 1
fi

# check on device
found=""
if [[ ! "$device" =~ ^[0-9]+$ ]]; then
  #echo "Invalid device: $device"
  #exit 1
  found="0"
else
  # check if device is part of numa
  found="0"
  for d in $numa_devices; do
    if [[ "$d" == "$device" ]]; then
      found="1"
      break
    fi
  done
fi

# print error
if [[ "$found" == "0" ]]; then
  echo "Invalid device: $device" >&2
  exit 1
fi

# check on port
name_cmdb=$($ODEV_PATH/src/cmdb_get.py $type $device name $port)
if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$name_cmdb" = "" ]; then
  echo "Invalid port: $port" >&2
  exit 1
fi

# get mac
mac_system=$(ifconfig "$name_cmdb" | awk '/ether /{print $2; exit}')
mac_cmdb=$($ODEV_PATH/src/cmdb_get.py $type $device mac $port)

# check on mac_system
if [[ "$mac_system" == "$mac_cmdb" ]]; then
  echo "$mac_system"
  exit 0
fi

#echo "Device not found: $type=<numa=$numa,device=$device,port=$port>  name $name_cmdb" >&2
exit 1

#if [[ "$mac_system" == *"Device not found"* ]]; then
#  echo "Device not found: $type=<numa=$numa,device=$device,port=$port>"
#  exit 1
#elif [ "$mac_system" = "$mac_cmdb" ]; then
#  echo "$mac_system"
#else
#  echo "${italic}$mac_system${normal}"
#fi

# author: https://github.com/jmoya82