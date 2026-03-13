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
GITHUB_PUSH_BRANCH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" github push_branch)")"
WORKFLOWS_PATH="$ODEV_PATH/submodules/workflows"
WORKFLOWS_TEMPLATE_PATH="$ODEV_PATH/templates/workflows"
WORKFLOWS_USER_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths workflows)")"

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
program=${V[program]}

# replace spaces with "_"
name="${name// /_}"

# check on flags
if [[ "$program" != "0" && "$program" != "1" ]]; then
  echo "Invalid flag value: --program"
  exit 1
fi

# set command flags
# ...

# derived
# ...

# check if exists
if [[ -d "$WORKFLOWS_PATH/$name" ]] || \
   [[ -d "$WORKFLOWS_USER_PATH/$name" ]] || \
   [[ -e "$ODEV_PATH/cmd/new/$name.sh" ]] || \
   [[ -L "$ODEV_PATH/cmd/new/$name.sh" ]]; then
  echo "Workflow already exists: $name"
  exit 1
fi

# login to GitHub
github_auth_status=$($ODEV_PATH/src/gh_auth_status.sh)
if [ "$github_auth_status" = "0" ]; then
  eval "gh auth login"
fi

# get GitHub user
github_user="$(gh api user --jq .login)"

# check on ~/odev
odev_path="$(dirname "$WORKFLOWS_USER_PATH")"
if [[ ! -d "$odev_path" ]]; then
  mkdir -p "$odev_path"
fi

# create a fork
if [[ ! -d "$WORKFLOWS_USER_PATH" ]]; then
  cd "$odev_path"

  # check if repository already exists in the account
  if gh repo view "${github_user}/workflows" >/dev/null 2>&1; then
    echo "Repository already exists: $github_user/workflows"
    exit 1
  fi
  
  #fork
  gh repo fork oreolag/workflows --clone=false
  git clone "https://github.com/${github_user}/workflows.git" workflows
  cd workflows
  git remote get-url upstream >/dev/null 2>&1 || git remote add upstream https://github.com/oreolag/workflows.git
fi

# save branch
echo "$GITHUB_PUSH_BRANCH" > GITHUB_PUSH_BRANCH

# create workflow folder
mkdir -p "$WORKFLOWS_USER_PATH/$name"
cd "$WORKFLOWS_USER_PATH/$name"

# copy from template
cp -r "$WORKFLOWS_TEMPLATE_PATH"/* .

# check on program
if [ "$program" = "0" ]; then
  rm "$WORKFLOWS_USER_PATH/$name/program.sh"
fi

# replace WFNAME (and _COMMAND_)
sed -i "s/WFNAME/${name^^}/g" "$WORKFLOWS_USER_PATH/$name/cmd_spec.sh"
sed -i "s/WFNAME/${name}/g" "$WORKFLOWS_USER_PATH/$name/new.sh"
sed -i "s/_COMMAND_/new/g" "$WORKFLOWS_USER_PATH/$name/new.sh"
sed -i "s/WFNAME/${name}/g" "$WORKFLOWS_USER_PATH/$name/build.sh"
sed -i "s/_COMMAND_/build/g" "$WORKFLOWS_USER_PATH/$name/build.sh"
if [ "$program" = "1" ]; then
  sed -i "s/WFNAME/${name}/g" "$WORKFLOWS_USER_PATH/$name/program.sh"
  sed -i "s/_COMMAND_/program/g" "$WORKFLOWS_USER_PATH/$name/program.sh"
fi
sed -i "s/WFNAME/${name}/g" "$WORKFLOWS_USER_PATH/$name/run.sh"
sed -i "s/_COMMAND_/run/g" "$WORKFLOWS_USER_PATH/$name/run.sh"
sed -i "s/WFNAME/${name}/g" "$WORKFLOWS_USER_PATH/$name/validate.sh"
sed -i "s/_COMMAND_/validate/g" "$WORKFLOWS_USER_PATH/$name/validate.sh"

# create symlinks
sudo $ODEV_PATH/src/ln_s.sh "$ODEV_PATH" "$WORKFLOWS_USER_PATH/$name/new.sh" "$ODEV_PATH/cmd/new/$name.sh"
sudo $ODEV_PATH/src/ln_s.sh "$ODEV_PATH" "$WORKFLOWS_USER_PATH/$name/build.sh" "$ODEV_PATH/cmd/build/$name.sh"
if [ "$program" = "1" ]; then
  sudo $ODEV_PATH/src/ln_s.sh "$ODEV_PATH" "$WORKFLOWS_USER_PATH/$name/program.sh" "$ODEV_PATH/cmd/program/$name.sh"
fi
sudo $ODEV_PATH/src/ln_s.sh "$ODEV_PATH" "$WORKFLOWS_USER_PATH/$name/run.sh" "$ODEV_PATH/cmd/run/$name.sh"
sudo $ODEV_PATH/src/ln_s.sh "$ODEV_PATH" "$WORKFLOWS_USER_PATH/$name/validate.sh" "$ODEV_PATH/cmd/validate/$name.sh"

# author: https://github.com/jmoya82