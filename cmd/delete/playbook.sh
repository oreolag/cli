#!/bin/bash

# example: odev delete playbook --name my_playbook

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBCOMMAND="$(basename "${BASH_SOURCE[0]}" .sh)"

# derive from SCRIPT_DIR
CLI_NAME="$(basename "$(dirname "$(dirname "$SCRIPT_DIR")")")"
COMMAND="$(basename "$SCRIPT_DIR")"
ODEV_PATH="${ODEV_PATH:-"$(dirname "$(dirname "$SCRIPT_DIR")")"}"

# get hostname
url="${HOSTNAME}"
hostname="${url%%.*}"

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

# constants
PLAYBOOKS_USER_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths playbooks)")"

PLAYBOOKS_PATH="$ODEV_PATH/submodules/playbooks"

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

# check on name
if [[ ! "$name" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ ]]; then
  echo "Invalid playbook name: $name"
  exit 1
fi

# check if exists
if [[ ! -f "$PLAYBOOKS_USER_PATH/$name.yml" && ! -L "$PLAYBOOKS_USER_PATH/$name.yml" ]]; then
  echo "Playbook does not exist: $name"
  exit 1
fi

# protect community playbooks
if [[ -e "$PLAYBOOKS_PATH/$name.yml" || -L "$PLAYBOOKS_PATH/$name.yml" ]]; then
  echo "Playbook cannot be deleted: $name"
  exit 1
fi

# check on branch
cd "$PLAYBOOKS_USER_PATH" || exit 1
github_branch="$(cat "$PLAYBOOKS_USER_PATH/GITHUB_PUSH_BRANCH")" || exit 1
current_branch="$(git branch --show-current)" || exit 1
if [[ -z "$github_branch" || "$current_branch" != "$github_branch" ]]; then
  echo "Switch to the playbook branch before deleting: $github_branch" >&2
  exit 1
fi

# login to GitHub
github_auth_status=$("$ODEV_PATH/src/gh_auth_status.sh")
if [ "$github_auth_status" = "0" ]; then
  gh auth login || exit 1
fi
github_user="$(gh api user --jq .login)" || exit 1

# configure git identity if missing
if ! git config user.name >/dev/null; then
  git config user.name "$github_user" || exit 1
fi
if ! git config user.email >/dev/null; then
  git config user.email "${github_user}@users.noreply.github.com" || exit 1
fi

# include the companion variables file when tracked
targets=("$name.yml")
if git ls-files --error-unmatch -- "${name}_vars.yml" >/dev/null 2>&1; then
  targets+=("${name}_vars.yml")
fi

# delete and commit only this playbook, then push the checked branch
git rm -- "${targets[@]}" || exit 1
git commit --only -m "Delete playbook $name" -- "${targets[@]}" || exit 1
git push origin "$github_branch" || exit 1

# print
echo "Playbook deleted: $name"

# author: https://github.com/jmoya82
