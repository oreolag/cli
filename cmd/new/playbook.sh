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
#COLOR_PASSED=$($ODEV_PATH/src/constant_get.sh $ODEV_PATH COLOR_PASSED)
GITHUB_PUSH_BRANCH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" github push_branch_playbooks)")"
PLAYBOOKS_PATH="$ODEV_PATH/submodules/playbooks"
#PLAYBOOKS_TEMPLATE_PATH="$ODEV_PATH/templates/playbooks"
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
fi

# check on GitHub CLI
#logged_in="$("$ODEV_PATH/src/gh_auth_status.sh")"
#if [[ "$logged_in" == "0" ]]; then
#  echo "Login failed: use gh auth login"
#  exit 1
#fi

# set KEY
KEY="$(printf '%s_%s' "$COMMAND" "$SUBCOMMAND" | tr '[:lower:]' '[:upper:]')"

# read command description, command flags, mandatory flags
command_description="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "$KEY")"
mapfile -t flags < <("$ODEV_PATH/src/cmd_flags_read.sh" "$ODEV_PATH" "$KEY")
mandatory_flags="$("$ODEV_PATH/src/cmd_mandatory_flags_read.sh" "$ODEV_PATH" "$KEY")"

# check on mandatory_flags (remove push)
if [[ -f "$PLAYBOOKS_USER_PATH/GITHUB_FORK" ]]; then
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

echo "I am here!"
exit 1

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
template=${V[template]}

# replace spaces with "_"
name="${name// /_}"

# check on ~/odev
odev_path="$(dirname "$PLAYBOOKS_USER_PATH")"
if [[ ! -d "$odev_path" ]]; then
  mkdir -p "$odev_path"
fi

# create a fork
if [[ ! -d "$PLAYBOOKS_USER_PATH" ]]; then
  # early exit (name already exists in oreolag/playbooks)
  folders="$(gh api repos/oreolag/playbooks/contents --jq '.[] | select(.type == "dir") | .name')" || exit 1

  if grep -Fxq -- "$name" <<< "$folders"; then
    echo "Playbook already exists: $name"
    exit 1
  fi

  # get GitHub user
  github_user="$(gh api user --jq .login)"

  # change directory
  cd "$odev_path"

  # check repo existence and validity
  if gh repo view "${github_user}/playbooks" >/dev/null 2>&1; then
    # repo exists → check if valid fork
    if gh api "repos/${github_user}/playbooks" \
        --jq '.fork and .parent.full_name == "oreolag/playbooks"' | grep -q true; then
      :  # valid fork → continue
    else
      echo "Repository already exists: $github_user/playbooks"
      rm -rf "$odev_path"
      exit 1
    fi
  else
    # repo does not exist → create fork
    gh repo fork oreolag/playbooks --clone=false
  fi
  
  # always clone
  git clone "https://github.com/${github_user}/playbooks.git" playbooks
  cd playbooks
  if ! git remote | grep -qx upstream; then
    git remote add upstream https://github.com/oreolag/playbooks.git
  fi

  # -----------------------------
  # FIX: ensure branch is synced
  # -----------------------------
  git checkout -b "$GITHUB_PUSH_BRANCH" || git checkout "$GITHUB_PUSH_BRANCH"
  if git ls-remote --exit-code --heads origin "$GITHUB_PUSH_BRANCH" >/dev/null 2>&1; then
    git pull origin "$GITHUB_PUSH_BRANCH" --rebase
  fi
  git push -u origin "$GITHUB_PUSH_BRANCH" || true

  # save branch and fork
  echo "$GITHUB_PUSH_BRANCH" > GITHUB_PUSH_BRANCH
  #echo "$fork" > "GITHUB_FORK"

  # recreate symlinks when possible
  #scripts=(new build program run validate delete)
  #for d in "$PLAYBOOKS_USER_PATH"/*; do
  #  [[ -d "$d" ]] || continue
  #  name_i="$(basename "$d")"
  #
  #  for script in "${scripts[@]}"; do
  #    src="$PLAYBOOKS_USER_PATH/$name_i/$script.sh"
  #    dst="$ODEV_PATH/cmd/$script/$name_i.sh"
  #
  #    [[ -e "$src" ]] || continue
  #
  #    if [[ ! -e "$dst" && ! -L "$dst" ]]; then
  #      sudo "$ODEV_PATH/src/ln_s.sh" "$ODEV_PATH" "$src" "$dst"
  #    fi
  #  done
  #done
#fi

# check if workflow name exists
if [[ -d "$PLAYBOOKS_PATH/$name" ]] || \
   [[ -d "$PLAYBOOKS_USER_PATH/$name" ]] || \
   [[ -e "$ODEV_PATH/cmd/new/$name.sh" ]] || \
   [[ -L "$ODEV_PATH/cmd/new/$name.sh" ]]; then
  echo "Playbook already exists: $name"
  exit 1
fi

# copy helper scripts
#if [[ ! -e "$PLAYBOOKS_USER_PATH/git_diff.sh" ]]; then
#  cp "$PLAYBOOKS_TEMPLATE_PATH"/git_diff.sh "$PLAYBOOKS_USER_PATH"
#  #if [ "$fork" = "1" ]; then
#    cp "$PLAYBOOKS_TEMPLATE_PATH"/github_pr.sh "$PLAYBOOKS_USER_PATH"
#    cp "$PLAYBOOKS_TEMPLATE_PATH"/github_push.sh "$PLAYBOOKS_USER_PATH"
#    cp "$PLAYBOOKS_TEMPLATE_PATH"/github_sync.sh "$PLAYBOOKS_USER_PATH"
#  #fi
#fi

# check on template
#template_path=""
#if [ ! "$template" = "-" ]; then
#  if [[ -d "$PLAYBOOKS_USER_PATH/$template" ]]; then
#    template_path="$PLAYBOOKS_USER_PATH/$template"
#  elif [[ -d "$PLAYBOOKS_PATH/$template" ]]; then
#    template_path="$PLAYBOOKS_PATH/$template"
#  else
#    # this is in fact an existing workflow
#    echo "Template does not exist: $template"
#    exit 1
#  fi
#fi

# create workflow name folder
#mkdir -p "$PLAYBOOKS_USER_PATH/$name"
#cd "$PLAYBOOKS_USER_PATH/$name"

# copy playbook template
cp "$ODEV_PATH/templates/playbook.yml" "$PLAYBOOKS_USER_PATH/$name.yml"

# copy from existing workflow/template
#if [ ! "$template" = "-" ]; then
#  # this is in fact an existing workflow
#  #cp -r "$PLAYBOOKS_USER_PATH/$template"/* .
#  cp -r "$template_path"/* .
#
#  # replace in cmd_spec.sh
#  sed -i "s/_${template^^}_/_${name^^}_/g" "$PLAYBOOKS_USER_PATH/$name/cmd_spec.sh"
#else
#  #cp -r "$PLAYBOOKS_TEMPLATE_PATH"/* .
#  cp "$PLAYBOOKS_TEMPLATE_PATH"/cmd_spec.sh .
#  cp "$PLAYBOOKS_TEMPLATE_PATH"/new.sh .
#  cp "$PLAYBOOKS_TEMPLATE_PATH"/build.sh .
#  cp "$PLAYBOOKS_TEMPLATE_PATH"/program.sh .
#  cp "$PLAYBOOKS_TEMPLATE_PATH"/program.yml .
#  cp "$PLAYBOOKS_TEMPLATE_PATH"/run.sh .
#  cp "$PLAYBOOKS_TEMPLATE_PATH"/validate.sh .
#  cp "$PLAYBOOKS_TEMPLATE_PATH"/delete.sh .
#fi

# replace PBNAME
sed -i "s/PBNAME/${name^^}/g" "$PLAYBOOKS_USER_PATH/$name.yml"

# copy helper scripts
#cd "$PLAYBOOKS_USER_PATH"
#if [[ ! -e "./git_diff.sh" ]]; then
#  cp "$PLAYBOOKS_TEMPLATE_PATH"/git_diff.sh .
#  if [ "$fork" = "1" ]; then
#    cp "$PLAYBOOKS_TEMPLATE_PATH"/github_pr.sh .
#    cp "$PLAYBOOKS_TEMPLATE_PATH"/github_push.sh .
#  fi
#fi

# commit cmd_spec.sh
#fork=$(cat $PLAYBOOKS_USER_PATH/GITHUB_FORK)
cd "$PLAYBOOKS_USER_PATH"
#if [ "$fork" = "1" ]; then
  "$PLAYBOOKS_USER_PATH/github_push.sh" --workflow "$name" --file "cmd_spec.sh" --comment "First commit"
#fi

# print
echo "Playbook created: $name"

# author: https://github.com/jmoya82