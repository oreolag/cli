#!/bin/bash

# example: odev booking

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMAND="booking"

# derive from SCRIPT_DIR
CLI_NAME="$(basename "$(dirname "$SCRIPT_DIR")")"
SUBCOMMAND="-"
ODEV_PATH="${ODEV_PATH:-"$(dirname "$SCRIPT_DIR")"}"

# check on booking configuration
"$ODEV_PATH/src/booking_available.sh" "$ODEV_PATH" || exit $?

# read command description and subcommands
KEY="$(printf '%s' "$COMMAND" | tr '[:lower:]' '[:upper:]')"
command_description="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "$KEY")"
mapfile -t commands < <("$ODEV_PATH/src/cmd_subcommands_read.sh" "$ODEV_PATH" "$KEY")

# print help (subcommands are resolved by odev.sh)
print_range="-"
print_default="-"
print_both="-"
"$ODEV_PATH/src/cmd_help_print.sh" --print \
  "$CLI_NAME" "$COMMAND" "$SUBCOMMAND" "$command_description" \
  "$print_range" "$print_default" "$print_both" "${commands[@]}" -- "$@" && exit 0 || true
