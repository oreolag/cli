#!/bin/bash

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBCOMMAND="$(basename "${BASH_SOURCE[0]}" .sh)"

# derive from SCRIPT_DIR
CLI_NAME="$(basename "$(dirname "$(dirname "$SCRIPT_DIR")")")"
COMMAND="$(basename "$SCRIPT_DIR")"
ODEV_PATH="${ODEV_PATH:-"$(dirname "$(dirname "$SCRIPT_DIR")")"}"

# check on booking configuration
"$ODEV_PATH/src/booking_available.sh" "$ODEV_PATH" --participant || exit $?

# set KEY
KEY="$(printf '%s_%s' "$COMMAND" "$SUBCOMMAND" | tr '[:lower:]' '[:upper:]')"

# read command description, command flags, mandatory flags
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
args=()
for flag in "$@"; do
  args+=("$flag")
  if [[ "$flag" == "--active" || "$flag" == "-a" ]]; then
    args+=("1")
  fi
done
parsed_flags="$("$ODEV_PATH/src/cmd_parse.sh" --params "${flags[@]}" -- "${args[@]}")" || exit 1

history_supplied=false
if [[ $'\n'$parsed_flags == *$'\n'history=* ]]; then
  history_supplied=true
fi

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
date=${V[history]}

# check on date and service scope
list_args=(--list)
if [[ "${V[active]}" == "1" ]]; then
  if [[ "$history_supplied" == true ]]; then
    echo "Invalid flags: --active and --history" >&2
    exit 1
  fi
  list_args+=(--active)
fi
if [[ "$history_supplied" == true ]]; then
  if [[ "$date" != today && "$date" != yesterday && "$date" != tomorrow ]] &&
     { [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] ||
       ! booking_day=$(date -d "$date" +%F 2>/dev/null) || [[ "$booking_day" != "$date" ]]; }; then
    echo "Invalid booking date: $date" >&2
    exit 1
  fi
  list_args+=(--date "$date")
fi

# list bookings
python3 "$ODEV_PATH/booking/client.py" --odev-path "$ODEV_PATH" "${list_args[@]}" || exit 1
