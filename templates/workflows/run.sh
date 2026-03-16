#!/bin/bash

# example: odev run WFNAME

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBCOMMAND="$(basename "${BASH_SOURCE[0]}" .sh)"

# derive from SCRIPT_DIR
CLI_NAME="$(basename "$(dirname "$(dirname "$SCRIPT_DIR")")")"
COMMAND="$(basename "$SCRIPT_DIR")"
ODEV_PATH="${ODEV_PATH:-"$(dirname "$SCRIPT_DIR")"}"

# get hostname
url="${HOSTNAME}"
hostname="${url%%.*}"

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

# constants
PROJECTS_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths projects)")"
WORKFLOWS_PATH="$ODEV_PATH/submodules/workflows"
WORKFLOWS_USER_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths workflows)")"

# check on users
# ...

# check on tools
# ...

# set KEY
KEY="$(printf '%s_%s' "$COMMAND" "$SUBCOMMAND" | tr '[:lower:]' '[:upper:]')"

# read command description, command flags, and mandatory flags
target="$(readlink -f "$ODEV_PATH/cmd/$COMMAND/$SUBCOMMAND.sh")"
if [[ "$target" == "$WORKFLOWS_USER_PATH/"* ]]; then
    command_description="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "$KEY" --db "$WORKFLOWS_USER_PATH/$SUBCOMMAND/cmd_spec.sh")"
    mapfile -t flags < <("$ODEV_PATH/src/cmd_flags_read.sh" "$ODEV_PATH" "$KEY" --db "$WORKFLOWS_USER_PATH/$SUBCOMMAND/cmd_spec.sh")
    mandatory_flags="$("$ODEV_PATH/src/cmd_mandatory_flags_read.sh" "$ODEV_PATH" "$KEY" --db "$WORKFLOWS_USER_PATH/$SUBCOMMAND/cmd_spec.sh")"
else
    command_description="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "$KEY")"
    mapfile -t flags < <("$ODEV_PATH/src/cmd_flags_read.sh" "$ODEV_PATH" "$KEY")
    mandatory_flags="$("$ODEV_PATH/src/cmd_mandatory_flags_read.sh" "$ODEV_PATH" "$KEY")"
fi

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
name=${V[name]}

# replace spaces with "_"
name="${name// /_}"

# check on flags
# ...

# set command flags
# ...

# derived
# ...

# check if exists
if [[ ! -d "$PROJECTS_PATH/$SUBCOMMAND/$name" ]]; then
  echo "Project does not exist: $name"
  exit 1
fi

# add your code here!
echo "Hi from $COMMAND $SUBCOMMAND!"