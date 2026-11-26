#!/bin/bash

# example: odev reserve

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMAND="reserve"

# derive from SCRIPT_DIR
CLI_NAME="$(basename "$(dirname "$SCRIPT_DIR")")"
SUBCOMMAND="-"
ODEV_PATH="${ODEV_PATH:-"$(dirname "$SCRIPT_DIR")"}"

# Help is available on participating hosts without a Tailscale login.
mode=--participant
for arg in "$@"; do
  [[ "$arg" == --help || "$arg" == -h ]] && mode=--help-only
done
"$ODEV_PATH/src/booking_available.sh" "$ODEV_PATH" "$mode" || exit $?

mapfile -t flags < <("$ODEV_PATH/src/cmd_flags_read.sh" "$ODEV_PATH" RESERVE)
if [[ "$mode" == --help-only ]]; then
  description="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" RESERVE)" || exit 1
  mapfile -t commands < <("$ODEV_PATH/src/cmd_subcommands_read.sh" "$ODEV_PATH" RESERVE)
  exec "$ODEV_PATH/src/cmd_help_print.sh" --print \
    "$CLI_NAME" "$COMMAND" "$SUBCOMMAND" "$description" 0 0 0 \
    "${commands[@]}" --flags "${flags[@]}"
fi

parsed_flags="$("$ODEV_PATH/src/cmd_parse.sh" --params "${flags[@]}" -- "$@")" || exit 1
list_args=(--list)
if [[ -n "$parsed_flags" ]]; then
  date="${parsed_flags#history=}"
  if [[ "$date" != today && "$date" != yesterday && "$date" != tomorrow ]] &&
     { [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] ||
       ! booking_day=$(date -d "$date" +%F 2>/dev/null) || [[ "$booking_day" != "$date" ]]; }; then
    python3 "$ODEV_PATH/src/odev_messages.py" --error invalid_booking_date -- "$date"
    exit 1
  fi
  list_args+=(--date "$date")
fi

python3 "$ODEV_PATH/booking/client.py" --odev-path "$ODEV_PATH" "${list_args[@]}" || exit 1

# Offer a reservation after the current availability table in an interactive terminal.
if [[ $# -eq 0 && -t 0 && -t 1 ]]; then
  free_server="$(python3 "$ODEV_PATH/booking/client.py" --odev-path "$ODEV_PATH" --free-server)" || exit 1
  if [[ -n "$free_server" ]]; then
    echo ""
    ODEV_RESERVE_DEFAULT_SERVER="$free_server" "$ODEV_PATH/cmd/reserve/add.sh" || exit 1
  fi
fi
