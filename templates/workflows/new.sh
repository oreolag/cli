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
#if [[ ! -d "$PROJECTS_PATH" ]]; then
#  mkdir -p "$PROJECTS_PATH"
#  cp "$ODEV_PATH/src/git_push.sh" "$PROJECTS_PATH"
#  cp "$ODEV_PATH/src/git_diff.sh" "$PROJECTS_PATH"
#  chmod +x "$PROJECTS_PATH/git_push.sh" "$PROJECTS_PATH/git_diff.sh"
#fi

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
name=${V[name]}
push=${V[push]}

# replace spaces with "_"
name="${name// /_}"

# check on flags
# ...

# set command flags
# ...

# derived
# ...

# set projects folder
if [[ ! -d "$PROJECTS_PATH" ]]; then
  mkdir -p "$PROJECTS_PATH"
  cp "$ODEV_PATH/src/github_push.sh" "$PROJECTS_PATH"
  cp "$ODEV_PATH/src/git_diff.sh" "$PROJECTS_PATH"
  chmod +x "$PROJECTS_PATH/github_push.sh" "$PROJECTS_PATH/git_diff.sh"
fi

# check if exists
if [[ -d "$PROJECTS_PATH/$SUBCOMMAND/$name" ]]; then
  echo "Project already exists: $SUBCOMMAND/$name"
  exit 1
fi

# create folder
mkdir -p "$PROJECTS_PATH/$SUBCOMMAND/$name"

# add WORKFLOW
[[ -f "$PROJECTS_PATH/$SUBCOMMAND/$name/WORKFLOW_NAME" ]] || echo "$SUBCOMMAND" > "$PROJECTS_PATH/$SUBCOMMAND/$name/WORKFLOW_NAME"

# add GITHUB_PUSH
[[ -f "$PROJECTS_PATH/$SUBCOMMAND/$name/GITHUB_PUSH" ]] || echo "$push" > "$PROJECTS_PATH/$SUBCOMMAND/$name/GITHUB_PUSH"

# push to GitHub
if [ "$push" = "1" ]; then
  # login
  github_auth_status=$($ODEV_PATH/src/gh_auth_status.sh)
  if [ "$github_auth_status" = "0" ]; then
    eval "gh auth login"
  fi

  # get GitHub user
  github_user="$(gh api user --jq .login)"

  # set GitHub project name
  github_name="$SUBCOMMAND-$name"

  # check if repository already exists in the account
  if gh repo view "${github_user}/$github_name" >/dev/null 2>&1; then
    echo "Project already exists: $github_user/$github_name"
    # remove locally
    rm -rf "$PROJECTS_PATH/$SUBCOMMAND/$name"
    exit 1
  fi

  # move to project
  cd "$PROJECTS_PATH/$SUBCOMMAND/$name"

  # initialize git repo if needed
  if [[ ! -d ".git" ]]; then
    git init
  fi

  # configure git identity if missing
  if ! git config user.name >/dev/null; then
    git config user.name "$github_user"
  fi

  if ! git config user.email >/dev/null; then
    git config user.email "${github_user}@users.noreply.github.com"
  fi

  # initial commit if needed
  if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    git add .
    git commit -m "Initial commit"
  fi

  gh repo create "$github_user/$github_name" --private --source=. --remote=origin --push
fi

# add your code here!
# ...

echo "Project created: $SUBCOMMAND/$name"