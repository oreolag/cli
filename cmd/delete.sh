#!/bin/bash

# example: odev delete

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMAND="delete"

# derive from SCRIPT_DIR
CLI_NAME="$(basename "$(dirname "$SCRIPT_DIR")")"
SUBCOMMAND="-"
ODEV_PATH="${ODEV_PATH:-"$(dirname "$SCRIPT_DIR")"}"

# read workflow description
KEY="$(printf '%s' "$COMMAND" | tr '[:lower:]' '[:upper:]')"
command_description="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "$KEY")"

# read workflow commands
mapfile -t commands < <("$ODEV_PATH/src/cmd_subcommands_read.sh" "$ODEV_PATH" "$KEY")

# print help
print_range="-"
print_default="-"
print_both="-"      
"$ODEV_PATH/src/cmd_help_print.sh" --print \
  "$CLI_NAME" "$COMMAND" "$SUBCOMMAND" "$command_description" \
  "$print_range" "$print_default" "$print_both" "${commands[@]}" -- "$@" && exit 0 || true