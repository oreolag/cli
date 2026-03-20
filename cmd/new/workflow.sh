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
#COLOR_PASSED=$($ODEV_PATH/src/color_get.sh $ODEV_PATH COLOR_PASSED)
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

# check on mandatory_flags (remove push)
if [[ -f "$WORKFLOWS_USER_PATH/GITHUB_PUSH" ]]; then
  mandatory_flags="name"
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
template=${V[template]}
push=${V[push]}
#program=${V[program]}

# read push (if applies)
if [[ -f "$WORKFLOWS_USER_PATH/GITHUB_PUSH" ]]; then
  push=$(cat $WORKFLOWS_USER_PATH/GITHUB_PUSH)
fi

# replace spaces with "_"
name="${name// /_}"

# check on flags
#if [[ "$program" != "0" && "$program" != "1" ]]; then
#  echo "Invalid flag value: --program"
#  exit 1
#fi
if [[ "$push" != "0" && "$push" != "1" ]]; then
  echo "Invalid flag value: --push"
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

# check on ~/odev
odev_path="$(dirname "$WORKFLOWS_USER_PATH")"
if [[ ! -d "$odev_path" ]]; then
  mkdir -p "$odev_path"
fi

# create a fork
if [[ "$push" == "1" && ! -d "$WORKFLOWS_USER_PATH" ]]; then
  # login to GitHub
  github_auth_status=$($ODEV_PATH/src/gh_auth_status.sh)
  if [ "$github_auth_status" = "0" ]; then
    eval "gh auth login"
  fi

  # get GitHub user
  github_user="$(gh api user --jq .login)"

  # change directory
  cd "$odev_path"

  # check if repository already exists in the account
  if gh repo view "${github_user}/workflows" >/dev/null 2>&1; then
    echo "Repository already exists: $github_user/workflows"
    rm -rf "$odev_path"
    exit 1
  fi
  
  #fork
  #gh repo fork oreolag/workflows --clone=false
  #git clone "https://github.com/${github_user}/workflows.git" workflows
  #cd workflows
  #git remote get-url upstream >/dev/null 2>&1 || git remote add upstream https://github.com/oreolag/workflows.git
  gh repo fork oreolag/workflows --clone=false >/dev/null 2>&1
  git clone "https://github.com/${github_user}/workflows.git" workflows >/dev/null 2>&1
  cd workflows
  git remote get-url upstream >/dev/null 2>&1 || \
  git remote add upstream https://github.com/oreolag/workflows.git >/dev/null 2>&1

  # save branch
  echo "$GITHUB_PUSH_BRANCH" > GITHUB_PUSH_BRANCH

  # generate string
  #msg1="${COLOR_PASSED}✓${normal} Created fork ${bold}$github_user/workflows${normal}"
  #msg2="Cloning into 'workflows'..."
fi

# create workflow folder
mkdir -p "$WORKFLOWS_USER_PATH"

# add GITHUB_PUSH
[[ -f "$WORKFLOWS_USER_PATH/GITHUB_PUSH" ]] || echo "$push" > "$WORKFLOWS_USER_PATH/GITHUB_PUSH"

# check on template
if [ ! "$template" = "-" ] && [[ ! -d "$WORKFLOWS_USER_PATH/$template" ]]; then
  # this is in fact an existing workflow
  echo "Template does not exist: $template"
  exit 1
fi

# print
#if [ ! "$msg1" = "" ]; then
#  echo -e "$msg1"
#  sleep 1
#  echo "$msg2"
#fi

# create workflow name folder
mkdir -p "$WORKFLOWS_USER_PATH/$name"
cd "$WORKFLOWS_USER_PATH/$name"

# add GITHUB_PUSH
#[[ -f "$WORKFLOWS_USER_PATH/GITHUB_PUSH" ]] || echo "$push" > "$WORKFLOWS_USER_PATH/GITHUB_PUSH"

# copy from existing workflow/template
if [ ! "$template" = "-" ]; then
  # this is in fact an existing workflow
  cp -r "$WORKFLOWS_USER_PATH/$template"/* .

  # replace in cmd_spec.sh
  sed -i "s/_${template^^}_/_${name^^}_/g" "$WORKFLOWS_USER_PATH/$name/cmd_spec.sh"
else
  cp -r "$WORKFLOWS_TEMPLATE_PATH"/* .
fi

# check on program
#if [ "$program" = "0" ]; then
#  rm "$WORKFLOWS_USER_PATH/$name/program.sh"
#fi

# replace WFNAME (and _COMMAND_)
sed -i "s/WFNAME/${name^^}/g" "$WORKFLOWS_USER_PATH/$name/cmd_spec.sh"
sed -i "s/WFNAME/${name}/g" "$WORKFLOWS_USER_PATH/$name/new.sh"
sed -i "s/_COMMAND_/new/g" "$WORKFLOWS_USER_PATH/$name/new.sh"
sed -i "s/WFNAME/${name}/g" "$WORKFLOWS_USER_PATH/$name/build.sh"
sed -i "s/_COMMAND_/build/g" "$WORKFLOWS_USER_PATH/$name/build.sh"
#if [ "$program" = "1" ]; then
  sed -i "s/WFNAME/${name}/g" "$WORKFLOWS_USER_PATH/$name/program.sh"
  sed -i "s/_COMMAND_/program/g" "$WORKFLOWS_USER_PATH/$name/program.sh"
#fi
sed -i "s/WFNAME/${name}/g" "$WORKFLOWS_USER_PATH/$name/run.sh"
sed -i "s/_COMMAND_/run/g" "$WORKFLOWS_USER_PATH/$name/run.sh"
sed -i "s/WFNAME/${name}/g" "$WORKFLOWS_USER_PATH/$name/validate.sh"
sed -i "s/_COMMAND_/validate/g" "$WORKFLOWS_USER_PATH/$name/validate.sh"
sed -i "s/WFNAME/${name}/g" "$WORKFLOWS_USER_PATH/$name/delete.sh"
sed -i "s/_COMMAND_/delete/g" "$WORKFLOWS_USER_PATH/$name/delete.sh"

# create symlinks
sudo $ODEV_PATH/src/ln_s.sh "$ODEV_PATH" "$WORKFLOWS_USER_PATH/$name/new.sh" "$ODEV_PATH/cmd/new/$name.sh"
sudo $ODEV_PATH/src/ln_s.sh "$ODEV_PATH" "$WORKFLOWS_USER_PATH/$name/build.sh" "$ODEV_PATH/cmd/build/$name.sh"
#if [ "$program" = "1" ]; then
  sudo $ODEV_PATH/src/ln_s.sh "$ODEV_PATH" "$WORKFLOWS_USER_PATH/$name/program.sh" "$ODEV_PATH/cmd/program/$name.sh"
#fi
sudo $ODEV_PATH/src/ln_s.sh "$ODEV_PATH" "$WORKFLOWS_USER_PATH/$name/run.sh" "$ODEV_PATH/cmd/run/$name.sh"
sudo $ODEV_PATH/src/ln_s.sh "$ODEV_PATH" "$WORKFLOWS_USER_PATH/$name/validate.sh" "$ODEV_PATH/cmd/validate/$name.sh"
sudo $ODEV_PATH/src/ln_s.sh "$ODEV_PATH" "$WORKFLOWS_USER_PATH/$name/delete.sh" "$ODEV_PATH/cmd/delete/$name.sh"

# commit cmd_spec.sh
if [ "$push" = "1" ]; then
  "$WORKFLOWS_USER_PATH/git_push.sh" --workflow "$name" --file "cmd_spec.sh" --comment "First commit"
fi

# print
#if [ "$push" = "0" ]; then
  echo "Workflow created: $name"
#fi

# author: https://github.com/jmoya82