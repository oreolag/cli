#!/bin/bash

# example: odev gh pr --workflow fft

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBCOMMAND="$(basename "${BASH_SOURCE[0]}" .sh)"

# derive from SCRIPT_DIR
CLI_NAME="$(basename "$(dirname "$(dirname "$SCRIPT_DIR")")")"
COMMAND="$(basename "$SCRIPT_DIR")"
ODEV_PATH="${ODEV_PATH:-"$(dirname "$(dirname "$SCRIPT_DIR")")"}"

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

# constants
PLAYBOOKS_USER_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths playbooks)")"
WORKFLOWS_USER_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths workflows)")"

# check on users
is_odev_developer=$($ODEV_PATH/src/is_member.sh $USER odev-developers)
if [ "$is_odev_developer" = "0" ]; then
  echo "Permission denied: $USER"
  exit 1
fi

# check on tools
installed="$("$ODEV_PATH/src/required_tools_print.sh" "$ODEV_PATH" "gh")"
if [[ "$installed" == "0" ]]; then
  echo "Missing tool: gh"
  exit 1
fi

# set KEY
KEY="$(printf '%s_%s' "$COMMAND" "$SUBCOMMAND" | tr '[:lower:]' '[:upper:]')"

# read command description and command flags
command_description="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "$KEY")"
mapfile -t flags < <("$ODEV_PATH/src/cmd_flags_read.sh" "$ODEV_PATH" "$KEY")

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

declare -A V
while IFS='=' read -r k v; do
  [[ -n "$k" ]] && V["$k"]="$v"
done <<< "$parsed_flags"

# select exactly one workflow or playbook
workflow=${V[workflow]:-}
playbook=${V[playbook]:-}
if [[ -n "$workflow" && -z "${V[playbook]+set}" ]]; then
  repository="workflow"
  name="$workflow"
elif [[ -n "$playbook" && -z "${V[workflow]+set}" ]]; then
  repository="playbook"
  name="$playbook"
else
  echo "Specify exactly one of --workflow or --playbook with a name"
  exit 1
fi
if [[ ! "$name" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ ]]; then
  echo "Invalid $repository name: $name"
  exit 1
fi

# use the selected repository's helper
if [[ "$repository" == "workflow" ]]; then
  repository_path="$WORKFLOWS_USER_PATH"
else
  repository_path="$PLAYBOOKS_USER_PATH"
fi
cd "$repository_path" || exit 1
exec "$repository_path/github_pr.sh" "--my_$repository" "$name"

# author: https://github.com/jmoya82
