#!/bin/bash

# example: odev delete WFNAME

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
COLOR_PASSED=$($ODEV_PATH/src/color_get.sh $ODEV_PATH COLOR_PASSED)
PROJECTS_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths projects)")"
WORKFLOWS_PATH="$ODEV_PATH/submodules/workflows"
WORKFLOWS_USER_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths workflows)")"

# check on users
# ...

# check on tools
installed="$("$ODEV_PATH/src/required_tools_print.sh" "$ODEV_PATH" "gh")"
if [[ "$installed" == "0" ]]; then
  echo "Missing tool: $tool"
fi

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

# check on flags
# ...

# set command flags
# ...

# derived
# ...

# check local project
if [[ ! -d "$PROJECTS_PATH/$SUBCOMMAND/$name" ]]; then
  echo "Project does not exist: $SUBCOMMAND/$name"
  exit 1
fi

# get push option
push=$(cat "$PROJECTS_PATH/$SUBCOMMAND/$name/GITHUB_PUSH")
remote_deleted="0"
if [ "$push" = "1" ]; then
  # login to GitHub
  github_auth_status=$($ODEV_PATH/src/gh_auth_status.sh)
  if [ "$github_auth_status" = "0" ]; then
    eval "gh auth login"
  fi

  # get GitHub user
  github_user="$(gh api user --jq .login)"

  # set GitHub project name
  github_name="$SUBCOMMAND-$name"

  # check remote repository
  if ! gh repo view "${github_user}/${github_name}" >/dev/null 2>&1; then
    echo "Project does not exist: ${github_user}/${github_name}"
    exit 1
  fi

  # delete remote repository
  if gh repo delete "${github_user}/${github_name}" --yes >/dev/null 2>&1; then
    remote_deleted="1"
  else
    gh auth refresh -h github.com -s delete_repo

    if gh repo delete "${github_user}/${github_name}" --yes >/dev/null 2>&1; then
      remote_deleted="1"
    else
      echo "Permission denied: ${github_user}/${github_name}"
      exit 1
    fi
  fi
fi

# delete local project
if rm -rf -- "$PROJECTS_PATH/$SUBCOMMAND/$name"; then
  echo "Project deleted: $SUBCOMMAND/$name"
fi

# report GitHub
if [ "$remote_deleted" = "1" ]; then
  echo -e "${COLOR_PASSED}✓${normal} Repository deleted: $github_user/$github_name"
fi