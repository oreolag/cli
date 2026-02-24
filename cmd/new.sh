#!/bin/bash

# example: odev examine

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW="new"

# derive from SCRIPT_DIR
CLI_NAME="$(basename "$(dirname "$SCRIPT_DIR")")"
COMMAND="-"
ODEV_PATH="${ODEV_PATH:-"$(dirname "$SCRIPT_DIR")"}"

# read workflow description
KEY="$(printf '%s' "$WORKFLOW" | tr '[:lower:]' '[:upper:]')"
workflow_description="$("$ODEV_PATH/src/description_read.sh" "$ODEV_PATH" "$KEY")"

# read workflow commands
mapfile -t commands < <("$ODEV_PATH/src/workflow_commands_read.sh" "$ODEV_PATH" "$KEY")

# (maybe) print help
print_range="-"
print_default="-"
print_both="-"     #help_print.sh 
"$ODEV_PATH/src/help_print.sh" --maybe \
  "$CLI_NAME" "$WORKFLOW" "$COMMAND" "$workflow_description" \
  "$print_range" "$print_default" "$print_both" "${commands[@]}" -- "$@" && exit 0 || true

# parse and check flag values
parsed_flags="$("$ODEV_PATH/src/cmd_parse.sh" --params "${flags[@]}" -- "$@")" || exit 1
if [[ -n "$parsed_flags" ]]; then
  declare -A V
  while IFS='=' read -r k v; do
    V["$k"]="$v"
  done <<< "$parsed_flags"
fi

# read flags
# ...

# set command flags
# ...