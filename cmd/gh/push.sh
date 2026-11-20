#!/bin/bash

# example: odev gh push --repository workflows

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
PLAYBOOKS_USER_PATH="$(python3 "$ODEV_PATH/src/odev_path.py" playbooks)" || exit 1
WORKFLOWS_USER_PATH="$(python3 "$ODEV_PATH/src/odev_path.py" workflows)" || exit 1

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
parsed_flags="$("$ODEV_PATH/src/cmd_prompt.sh" --required "$mandatory_flags" --params "${flags[@]}" -- "$parsed_flags")" || exit 1

declare -A V
while IFS='=' read -r k v; do
  [[ -n "$k" ]] && V["$k"]="$v"
done <<< "$parsed_flags"

# push the current branch of the selected repository
if [[ "${V[repository]}" == "workflows" ]]; then
  repository_path="$WORKFLOWS_USER_PATH"
else
  repository_path="$PLAYBOOKS_USER_PATH"
fi
cd "$repository_path" || exit 1

# check on GitHub CLI
logged_in="$("$ODEV_PATH/src/gh_auth_status.sh")"
if [[ "$logged_in" == "0" ]]; then
  echo "Login failed: use gh auth login"
  exit 1
fi

gh_path="$(command -v gh)" || exit 1
branch="$(git symbolic-ref --quiet --short HEAD)" || exit 1
exec git -c credential.helper= \
  -c "credential.https://github.com.helper=!\"$gh_path\" auth git-credential" \
  push -u origin "HEAD:refs/heads/$branch"

# author: https://github.com/jmoya82
