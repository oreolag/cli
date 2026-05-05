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

# read push (if applies)
if [[ -f "$WORKFLOWS_USER_PATH/GITHUB_FORK" ]]; then
  push=$(cat $WORKFLOWS_USER_PATH/GITHUB_FORK)
fi

# login to GitHub
#github_auth_status=$($ODEV_PATH/src/gh_auth_status.sh)
#if [ "$github_auth_status" = "0" ]; then
#  eval "gh auth login"
#fi

# get GitHub branch
#if [[ -f "$WORKFLOWS_USER_PATH/GITHUB_PUSH_BRANCH" ]]; then
#  github_branch=$(cat $WORKFLOWS_USER_PATH/GITHUB_PUSH_BRANCH)
#fi

# delete 
target="$(readlink -f "$ODEV_PATH/cmd/new/$name.sh")"
if [[ "$target" == "$WORKFLOWS_USER_PATH/"* ]]; then
  if [[ -d "$WORKFLOWS_USER_PATH/$name" ]]; then
    # delete workflow and push
    cd "$WORKFLOWS_USER_PATH"

    # delete locally
    rm -rf -- "$WORKFLOWS_USER_PATH/$name"

    # delete symlinks
    sudo "$ODEV_PATH/src/rm.sh" "$ODEV_PATH" "$ODEV_PATH/cmd/new/$name.sh"
    sudo "$ODEV_PATH/src/rm.sh" "$ODEV_PATH" "$ODEV_PATH/cmd/build/$name.sh"
    sudo "$ODEV_PATH/src/rm.sh" "$ODEV_PATH" "$ODEV_PATH/cmd/program/$name.sh"
    sudo "$ODEV_PATH/src/rm.sh" "$ODEV_PATH" "$ODEV_PATH/cmd/run/$name.sh"
    sudo "$ODEV_PATH/src/rm.sh" "$ODEV_PATH" "$ODEV_PATH/cmd/validate/$name.sh"
    sudo "$ODEV_PATH/src/rm.sh" "$ODEV_PATH" "$ODEV_PATH/cmd/delete/$name.sh"

    if [[ "$push" == "1" ]]; then
      # login to GitHub
      github_auth_status=$($ODEV_PATH/src/gh_auth_status.sh)
      if [ "$github_auth_status" = "0" ]; then
        eval "gh auth login"
      fi

      # get GitHub user
      github_user="$(gh api user --jq .login)"

      # configure git identity if missing
      if ! git config user.name >/dev/null; then
        git config user.name "$github_user"
      fi

      if ! git config user.email >/dev/null; then
        git config user.email "${github_user}@users.noreply.github.com"
      fi

      # get GitHub branch
      if [[ -f "$WORKFLOWS_USER_PATH/GITHUB_PUSH_BRANCH" ]]; then
        github_branch="$(cat "$WORKFLOWS_USER_PATH/GITHUB_PUSH_BRANCH")"
      fi

      # delete remotely (stage deletion!)
      if git ls-tree -r --name-only "$github_branch" -- "$name" | grep -q .; then
        git add -A "$name"
        git commit -m "Delete workflow $name"
        git push origin "$github_branch"
      fi
    else
      echo "Workflow deleted: $name"
    fi
  fi
  exit 1
else
  echo "Workflow cannot be deleted: $name"
fi