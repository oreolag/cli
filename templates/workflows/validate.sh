#!/bin/bash

# example: odev new WFNAME

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
CMDB_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths cmdb)")"
PROJECTS_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths projects)")"
WORKFLOWS_PATH="$ODEV_PATH/submodules/workflows"
WORKFLOWS_USER_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths workflows)")"

# check on users
# ...

# check on tools
# ...

# set projects folder
if [[ ! -d "$PROJECTS_PATH" ]]; then
  mkdir -p "$PROJECTS_PATH"
  cp "$ODEV_PATH/src/github_push.sh" "$PROJECTS_PATH"
  cp "$ODEV_PATH/src/git_diff.sh" "$PROJECTS_PATH"
  chmod +x "$PROJECTS_PATH/github_push.sh" "$PROJECTS_PATH/git_diff.sh"
fi

# set KEY
KEY="$(printf '%s_%s' "$COMMAND" "$SUBCOMMAND" | tr '[:lower:]' '[:upper:]')"

# get cmd_spec.sh path
target="$(readlink -f "$ODEV_PATH/cmd/$COMMAND/$SUBCOMMAND.sh")"
CMD_SPEC_PATH="$(dirname "$target")"

# read command description, command flags, and mandatory flags
command_description="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "$KEY" --db "$CMD_SPEC_PATH/cmd_spec.sh")"
mapfile -t flags < <("$ODEV_PATH/src/cmd_flags_read.sh" "$ODEV_PATH" "$KEY" --db "$CMD_SPEC_PATH/cmd_spec.sh")
mandatory_flags="$("$ODEV_PATH/src/cmd_mandatory_flags_read.sh" "$ODEV_PATH" "$KEY" --db "$CMD_SPEC_PATH/cmd_spec.sh")"

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
devices=${V[devices]}
flag1=${V[flag1]}
flag2=${V[flag2]}

# replace spaces with "_"
flag1="${flag1// /_}"
flag2="${flag2// /_}"

# check on flags
# ...

# check on devices
if [[ ! "$devices" =~ ^[0-9]+(,\ ?[0-9]+)*$ ]]; then
    echo "Invalid devices format: $devices"
    exit 1
fi

# convert devices to an array
devices_array=$(echo "$devices" | tr -d ' ')
IFS=',' read -ra devices_array <<< "$devices_array"

# remove duplicates
mapfile -t devices_array < <(printf "%s\n" "${devices_array[@]}" | awk '!seen[$0]++')

# device loop
for d in "${devices_array[@]}"; do
  name_system="A"
  name_cmdb="A"
  if [[ "$name_system" != "$name_cmdb" ]]; then
    echo "Invalid device index: $d"
    exit 1
  fi
done

# set command flags
# ...

# derived
# ...

# add your code here!
echo "Hi from $COMMAND $SUBCOMMAND (with flag1=$flag1 and flag2=$flag2)!"