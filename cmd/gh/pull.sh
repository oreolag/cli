#!/bin/bash

# example: odev gh pull --workflows

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

# read command description, command flags
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

# select one repository (these flags take no value)
repository=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --workflows|-w) selected="workflow" ;;
    --playbooks|-p) selected="playbook" ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
  if [[ -n "$repository" ]]; then
    echo "Specify exactly one of --workflows or --playbooks"
    exit 1
  fi
  repository="$selected"
  shift
done
if [[ -z "$repository" ]]; then
  echo "Specify exactly one of --workflows or --playbooks"
  exit 1
fi

# use the selected repository's helper
if [[ "$repository" == "workflow" ]]; then
  repository_path="$WORKFLOWS_USER_PATH"
else
  repository_path="$PLAYBOOKS_USER_PATH"
fi
cd "$repository_path" || exit 1
ODEV_PATH="$ODEV_PATH" exec "$repository_path/github_pull.sh"

# author: https://github.com/jmoya82
