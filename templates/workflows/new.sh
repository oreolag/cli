#!/bin/bash

# example: odev new WFNAME

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBCOMMAND="$(basename "${BASH_SOURCE[0]}" .sh)"

# derive from SCRIPT_DIR
CLI_NAME="$(basename "$(dirname "$(dirname "$SCRIPT_DIR")")")"
COMMAND="$(basename "$SCRIPT_DIR")"
ODEV_PATH="${ODEV_PATH:-"$(dirname "$SCRIPT_DIR")"}"

# early exit

# read command description
#KEY="$(printf '%s_%s' "$COMMAND" "$SUBCOMMAND" | tr '[:lower:]' '[:upper:]')"
#command_description="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "$KEY")"

# read command flags
#mapfile -t flags < <("$ODEV_PATH/src/cmd_flags_read.sh" "$ODEV_PATH" "$KEY")

# read mandatory flags
#mandatory_flags="$("$ODEV_PATH/src/cmd_mandatory_flags_read.sh" "$ODEV_PATH" "$KEY")"

# (maybe) print help
#print_range="0"
#print_default="0"
#print_both="0"
#"$ODEV_PATH/src/cmd_help_print.sh" --maybe \
#  "$CLI_NAME" "$COMMAND" "$SUBCOMMAND" "$command_description" \
#  "$print_range" "$print_default" "$print_both" \
#  "${flags[@]}" -- "$@" && exit 0 || true

# parse flags
#parsed_flags="$("$ODEV_PATH/src/cmd_parse.sh" --params "${flags[@]}" -- "$@")" || exit 1

# run interactive prompt
#parsed_flags="$("$ODEV_PATH/src/cmd_prompt.sh" --required "$mandatory_flags" --params "${flags[@]}" -- "$parsed_flags")" || exit 1

# read flags
#if [[ -n "$parsed_flags" ]]; then
#  declare -A V
#  while IFS='=' read -r k v; do
#    V["$k"]="$v"
#  done <<< "$parsed_flags"
#fi
#name=${V[name]}

# set command flags
#flags="--name $name"

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

# get hostname
url="${HOSTNAME}"
hostname="${url%%.*}"

# constants

# derived

echo "Hello from WFNAME _COMMAND_!"