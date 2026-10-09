#!/bin/bash

# example: odev validate nccl --ngpus 1 --nthreads 1 --minbytes 8M --maxbytes 1G --iters 20 --datatype float --stepfactor 2

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
WORKFLOWS_USER_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths workflows)")"

WORKFLOW_COMMAND_PATH="$ODEV_PATH/users/$(id -un)/workflows"

# check on users
is_odev_developer=$($ODEV_PATH/src/is_member.sh $USER odev-developers)
if [ "$is_odev_developer" = "0" ]; then
  echo "Permission denied: $USER"
  exit 1
fi

# check on tools
installed="$("$ODEV_PATH/src/required_tools_print.sh" "$ODEV_PATH" "gh")"
if [[ "$installed" == "0" ]]; then
  echo "Missing tool: $tool"
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

# check on flags
# ...

# set command flags
# ...

# derived
# ...

# check if exists
if [[ ! -d "$WORKFLOWS_USER_PATH/$name" ]]; then
  echo "Workflow does not exist: $name"
  exit 1
fi

# delete 
workflow_link="$("$ODEV_PATH/src/workflow_command_path.sh" "$ODEV_PATH" new "$name")" || exit 1
target="$(readlink -f "$workflow_link")"
if [[ "$target" == "$WORKFLOWS_USER_PATH/"* ]]; then
  if [[ -d "$WORKFLOWS_USER_PATH/$name" ]]; then
    # delete workflow and push
    cd "$WORKFLOWS_USER_PATH" || exit 1

    github_branch="$(cat "$WORKFLOWS_USER_PATH/GITHUB_PUSH_BRANCH")" || exit 1
    current_branch="$(git branch --show-current)" || exit 1
    if [[ -z "$github_branch" || "$current_branch" != "$github_branch" ]]; then
      echo "Switch to the workflow branch before deleting: $github_branch" >&2
      exit 1
    fi

    # Collect only this user's links, including links from older installations.
    workflow_links=()
    for command in new build program run validate delete; do
      for link in "$WORKFLOW_COMMAND_PATH/$command/$name.sh" "$ODEV_PATH/cmd/$command/$name.sh"; do
        [[ -L "$link" ]] || continue
        target="$(readlink -f "$link")" || continue
        [[ "$target" == "$(readlink -f "$WORKFLOWS_USER_PATH/$name")/"* ]] || continue
        workflow_links+=("$link")
      done
    done

    # delete locally
    rm -rf -- "$WORKFLOWS_USER_PATH/$name" || exit 1

    # delete symlinks
    for link in "${workflow_links[@]}"; do
      sudo "$ODEV_PATH/src/rm.sh" "$ODEV_PATH" "$link" || exit 1
    done

    # login to GitHub
    github_auth_status=$($ODEV_PATH/src/gh_auth_status.sh)
    if [ "$github_auth_status" = "0" ]; then
      gh auth login || exit 1
    fi

    # get GitHub user
    github_user="$(gh api user --jq .login)" || exit 1

    # configure git identity if missing
    if ! git config user.name >/dev/null; then
      git config user.name "$github_user" || exit 1
    fi

    if ! git config user.email >/dev/null; then
      git config user.email "${github_user}@users.noreply.github.com" || exit 1
    fi

    # Commit only this workflow deletion, then push the checked branch.
    git add -A -- "$name" || exit 1
    git commit --only -m "Delete workflow $name" -- "$name" || exit 1
    git push origin "$github_branch" || exit 1
    echo "Workflow deleted: $name"
  fi
  exit 0
else
  echo "Workflow cannot be deleted: $name"
  exit 1
fi
