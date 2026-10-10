#!/bin/bash

# example: odev new playbook --name test

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
GITHUB_PUSH_BRANCH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" github push_branch_playbooks)")"
PLAYBOOKS_PATH="$ODEV_PATH/submodules/playbooks"
PLAYBOOK_TEMPLATE_PATH="$ODEV_PATH/templates/playbook.yml"
PLAYBOOKS_USER_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths playbooks)")"

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

# check on GitHub CLI
logged_in="$("$ODEV_PATH/src/gh_auth_status.sh")"
if [[ "$logged_in" == "0" ]]; then
  echo "Login failed: use gh auth login"
  exit 1
fi

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

# check on name
if [[ ! "$name" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ ]]; then
  echo "Invalid playbook name: $name"
  exit 1
fi

# get GitHub user
github_user="$(gh api user --jq .login)" || exit 1

# check if playbook name exists (oreolag/playbooks default branch)
files="$(gh api repos/oreolag/playbooks/contents --jq '.[] | select(.type == "file") | .name')" || exit 1
if grep -Fxq -- "$name.yml" <<< "$files"; then
  echo "Playbook already exists: $name"
  exit 1
fi

# create or reuse the fork
if [[ ! -e "$PLAYBOOKS_USER_PATH" ]]; then
  mkdir -p "$(dirname "$PLAYBOOKS_USER_PATH")" || exit 1
  if gh repo view "$github_user/playbooks" >/dev/null 2>&1; then
    if ! gh api "repos/$github_user/playbooks" \
        --jq '.fork and .parent.full_name == "oreolag/playbooks"' | grep -qx true; then
      echo "Repository already exists: $github_user/playbooks"
      exit 1
    fi
  else
    gh repo fork oreolag/playbooks --clone=false || exit 1
  fi

  git clone "https://github.com/$github_user/playbooks.git" "$PLAYBOOKS_USER_PATH" || exit 1
  cd "$PLAYBOOKS_USER_PATH" || exit 1
  git remote add upstream https://github.com/oreolag/playbooks.git || exit 1
  if git show-ref --verify --quiet "refs/remotes/origin/$GITHUB_PUSH_BRANCH"; then
    git checkout -b "$GITHUB_PUSH_BRANCH" --track "origin/$GITHUB_PUSH_BRANCH" || exit 1
  else
    git checkout -b "$GITHUB_PUSH_BRANCH" || exit 1
  fi
  git push -u origin "$GITHUB_PUSH_BRANCH" || exit 1
  echo "$GITHUB_PUSH_BRANCH" > GITHUB_PUSH_BRANCH
fi

# check on checkout and branch
cd "$PLAYBOOKS_USER_PATH" || exit 1
git rev-parse --is-inside-work-tree >/dev/null || exit 1
if [[ "$(git branch --show-current)" != "$GITHUB_PUSH_BRANCH" ]]; then
  echo "Switch to the playbook branch before creating: $GITHUB_PUSH_BRANCH"
  exit 1
fi

# check if playbook name exists (fork configured branch)
files="$(gh api "repos/$github_user/playbooks/contents?ref=$GITHUB_PUSH_BRANCH" \
  --jq '.[] | select(.type == "file") | .name')" || exit 1
if grep -Fxq -- "$name.yml" <<< "$files"; then
  echo "Playbook already exists: $name"
  exit 1
fi

# check if playbook name exists (local)
if [[ -e "$PLAYBOOKS_PATH/$name.yml" || -L "$PLAYBOOKS_PATH/$name.yml" ||
      -e "$PLAYBOOKS_USER_PATH/$name.yml" || -L "$PLAYBOOKS_USER_PATH/$name.yml" ]]; then
  echo "Playbook already exists: $name"
  exit 1
fi

# configure git identity if missing
if ! git config user.name >/dev/null; then
  git config user.name "$github_user" || exit 1
fi
if ! git config user.email >/dev/null; then
  git config user.email "$github_user@users.noreply.github.com" || exit 1
fi

# copy playbook template
cp "$PLAYBOOK_TEMPLATE_PATH" "$PLAYBOOKS_USER_PATH/$name.yml" || exit 1
playbook_name="$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')"
sed -i "s/PBNAME/$playbook_name/g" "$PLAYBOOKS_USER_PATH/$name.yml" || exit 1

# commit and push only this playbook
git add -- "$name.yml" || exit 1
git commit --only -m "First commit" -- "$name.yml" || exit 1
git push -u origin "$GITHUB_PUSH_BRANCH" || exit 1

# print
echo "Playbook created: $name"

# author: https://github.com/jmoya82
