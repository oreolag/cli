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
parsed_flags="$("$ODEV_PATH/src/cmd_parse.sh" --params "${flags[@]}" -- "$@")" || exit 1

# validate supplied users before asking for missing fields
validate_user() {
  local user="$1" groups
  if [[ -z "$user" || "$user" == *,* || "$user" == *[[:space:]]* || "$user" == -* ]] ||
     ! groups=$(id -nG -- "$user" 2>/dev/null) ||
     [[ " $groups " != *" odev-users "* ]]; then
    echo "Invalid user: $user" >&2
    return 1
  fi
}

has_add=false
has_remove=false
while IFS='=' read -r k v; do
  case "$k" in
    add) has_add=true; supplied_add="$v" ;;
    remove) has_remove=true; supplied_remove="$v" ;;
  esac
done <<< "$parsed_flags"
if [[ "$has_add" == true && "$has_remove" == true ]]; then
  echo "Invalid flags: --add and --remove" >&2
  exit 1
fi
if [[ "$has_remove" == true ]]; then
  validate_user "$supplied_remove" || exit 1
  mandatory_flags="$mandatory_flags,remove"
else
  if [[ "$has_add" == true ]]; then
    validate_user "$supplied_add" || exit 1
  fi
  mandatory_flags="$mandatory_flags,add"
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
add=${V[add]}
booking=${V[booking]}
remove=${V[remove]}

# validate the user entered in the dialog
if [[ "$remove" != "-" ]]; then
  validate_user "$remove" || exit 1
else
  validate_user "$add" || exit 1
fi

# Placeholder: echo parsed parameter values.
echo "$add"
echo "$booking"
echo "$remove"
