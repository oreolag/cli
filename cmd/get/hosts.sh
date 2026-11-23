#!/bin/bash

# example: odev get mac

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBCOMMAND="$(basename "${BASH_SOURCE[0]}" .sh)"

# derive from SCRIPT_DIR
CLI_NAME="$(basename "$(dirname "$SCRIPT_DIR")")"
COMMAND="$(basename "$SCRIPT_DIR")"
ODEV_PATH="${ODEV_PATH:-"$(dirname "$SCRIPT_DIR")"}"

# get hostname
#url="${HOSTNAME}"
#hostname="${url%%.*}"

# get username
username="$(id -un)"

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

# constants
INVENTORY_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths inventory)")"

# check on users
# ...

# check on tools
# ...

# set KEY
KEY="$(printf '%s_%s' "$COMMAND" "$SUBCOMMAND" | tr '[:lower:]' '[:upper:]')"

# read command description, command flags, and mandatory flags
command_description="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "$KEY")"
mapfile -t flags < <("$ODEV_PATH/src/cmd_flags_read.sh" "$ODEV_PATH" "$KEY")
mandatory_flags="$("$ODEV_PATH/src/cmd_mandatory_flags_read.sh" "$ODEV_PATH" "$KEY")"

# (maybe) print help
print_range="0"
print_default="1"
print_both="0"
"$ODEV_PATH/src/cmd_help_print.sh" --maybe \
  "$CLI_NAME" "$COMMAND" "$SUBCOMMAND" "$command_description" \
  "$print_range" "$print_default" "$print_both" \
  "${flags[@]}" -- "$@" && exit 0 || true

# refresh the user's Ansible inventory (requires Tailscale login)
"$ODEV_PATH/src/get_ansible_hosts.sh" "$username" >/dev/null 2>&1 || true

# print file
cat "$INVENTORY_PATH/hosts_$USER"

# author: https://github.com/jmoya82