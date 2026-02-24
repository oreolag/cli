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

# print help
print_range="-"
print_default="-"
print_both="-"      
"$ODEV_PATH/src/help_print.sh" --print \
  "$CLI_NAME" "$WORKFLOW" "$COMMAND" "$workflow_description" \
  "$print_range" "$print_default" "$print_both" "${commands[@]}" -- "$@" && exit 0 || true