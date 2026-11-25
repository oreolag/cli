#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ODEV_PATH="${ODEV_PATH:-"$(dirname "$(dirname "$SCRIPT_DIR")")"}"

description="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" GET_RESERVED)" || exit 1
"$ODEV_PATH/src/cmd_help_print.sh" --maybe \
  odev get reserved "$description" 0 0 0 -- "$@" && exit 0

"$ODEV_PATH/src/cmd_parse.sh" --params -- "$@" || exit 1
"$ODEV_PATH/src/booking_available.sh" "$ODEV_PATH" --participant || exit $?
exec python3 "$ODEV_PATH/booking/client.py" --odev-path "$ODEV_PATH" --list --active
