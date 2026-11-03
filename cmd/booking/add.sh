#!/bin/bash

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBCOMMAND="$(basename "${BASH_SOURCE[0]}" .sh)"

# derive from SCRIPT_DIR
CLI_NAME="$(basename "$(dirname "$(dirname "$SCRIPT_DIR")")")"
COMMAND="$(basename "$SCRIPT_DIR")"
ODEV_PATH="${ODEV_PATH:-"$(dirname "$(dirname "$SCRIPT_DIR")")"}"

# check on booking configuration
"$ODEV_PATH/src/booking_available.sh" "$ODEV_PATH" || exit $?
BOOKING_TIMEZONE="$(bash "$ODEV_PATH/src/booking_timezone.sh" "$ODEV_PATH")" || exit 1
export BOOKING_TIMEZONE

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

# validate supplied or completed start values
validate_start_time() {
  local date="$1" start="$2" start_timestamp now
  # validate start time (from flags or the interactive prompt)
  if [[ ! "$start" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
    echo "Invalid value for --start: '$start' (expected HH:MM from 00:00 to 23:59)" >&2
    return 1
  fi

  # validate the combined date and time in the booking timezone (odev targets Ubuntu)
  if [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] ||
     ! start_timestamp=$(TZ="$BOOKING_TIMEZONE" date -d "$date $start" +%s 2>/dev/null); then
    echo "Invalid start time: $date $start" >&2
    return 1
  fi
  now=$(date +%s)
  if (( start_timestamp < now - now % 60 )); then
    echo "Invalid start time: $date $start" >&2
    return 1
  fi
}

# parse flags
parsed_flags="$("$ODEV_PATH/src/cmd_parse.sh" --params "${flags[@]}" -- "$@")" || exit 1

# validate supplied input before asking for missing fields
supplied_date="$(TZ="$BOOKING_TIMEZONE" date +%F)"
supplied_start=""
has_start=false
while IFS='=' read -r k v; do
  case "$k" in
    date) supplied_date="$v" ;;
    start) supplied_start="$v"; has_start=true ;;
  esac
done <<< "$parsed_flags"
if [[ "$has_start" == true ]]; then
  validate_start_time "$supplied_date" "$supplied_start" || exit 1
fi

# check supplied values first, then check each answer before the next question
for field in "" ${mandatory_flags//,/ }; do
  if [[ -n "$field" && "${V[$field]:--}" != "-" ]]; then
    continue
  fi
  # run interactive prompt
  if [[ "$field" == "start" ]]; then
    mapfile -t flags < <("$ODEV_PATH/src/cmd_flags_read.sh" "$ODEV_PATH" "$KEY")
  fi
  parsed_flags="$("$ODEV_PATH/src/cmd_prompt.sh" --required "$mandatory_flags" --field "$field" --params "${flags[@]}" -- "$parsed_flags")" || exit 1

  # read flags
  if [[ -n "$parsed_flags" ]]; then
    declare -A V
    while IFS='=' read -r k v; do
      V["$k"]="$v"
    done <<< "$parsed_flags"
  fi

  # assign flags
  date=${V[date]:--}
  duration=${V[duration]:--}
  server=${V[server]:--}
  shared=${V[shared]:--}
  start=${V[start]:--}

  # check on server and duration
  booking_db="${BOOKING_DB_FILE:-}"
  if [[ -z "$booking_db" ]]; then
    booking_db="$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths booking)" || exit 1
  fi
  booking_args=(--db "${booking_db:-/opt/booking.yml}" --duration "$duration")
  if [[ "$server" != "-" ]]; then
    booking_args+=(--server "$server")
  fi
  python3 "$ODEV_PATH/src/booking_is_server.py" "${booking_args[@]}" || exit 1

  # check on date
  if [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] ||
     ! booking_day=$(TZ="$BOOKING_TIMEZONE" date -d "$date" +%F 2>/dev/null) ||
     [[ "$booking_day" != "$date" || "$date" < "$(TZ="$BOOKING_TIMEZONE" date +%F)" ]]; then
    echo "Invalid booking date: $date" >&2
    exit 1
  fi

  # check on start when supplied or answered
  if [[ "$start" != "-" ]]; then
    validate_start_time "$date" "$start" || exit 1
  fi

  # check on shared users
  if [[ "$shared" != "-" ]]; then
    IFS=',' read -r -a shared_users <<< "$shared"
    # read drops a trailing empty field.
    if [[ "$shared" == *, ]]; then
      echo "Invalid user: " >&2
      exit 1
    fi
    for user in "${shared_users[@]}"; do
      user="${user#"${user%%[![:space:]]*}"}"
      user="${user%"${user##*[![:space:]]}"}"
      if [[ -z "$user" || "$user" == -* || "$user" == *[[:space:]]* ]] ||
         ! groups=$(id -nG -- "$user" 2>/dev/null) ||
         [[ " $groups " != *" odev-users "* ]]; then
        echo "Invalid user: $user" >&2
        exit 1
      fi
    done
  fi
done

# create booking
python3 "$ODEV_PATH/booking/client.py" --odev-path "$ODEV_PATH" \
  --server "$server" --date "$date" --start "$start" \
  --duration "$duration" --shared "$shared" || exit 1
