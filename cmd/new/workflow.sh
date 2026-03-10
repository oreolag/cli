#!/bin/bash

# example: odev validate nccl --ngpus 1 --nthreads 1 --minbytes 8M --maxbytes 1G --iters 20 --datatype float --stepfactor 2

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBCOMMAND="$(basename "${BASH_SOURCE[0]}" .sh)"

# derive from SCRIPT_DIR
CLI_NAME="$(basename "$(dirname "$(dirname "$SCRIPT_DIR")")")"
COMMAND="$(basename "$SCRIPT_DIR")"
ODEV_PATH="${ODEV_PATH:-"$(dirname "$SCRIPT_DIR")"}"

# constants
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
required_tools=("gh")
for tool in "${required_tools[@]}"; do
  installed="$("$ODEV_PATH/src/which.sh" "$tool")"
  if [[ "$installed" == "0" ]]; then
    echo "Missing command: $tool"
  fi
done

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
#parsed_flags="$("$ODEV_PATH/src/cmd_prompt.sh" --required "$mandatory_flags" --params "${flags[@]}" -- "$parsed_flags")" || exit 1

# read flags (1)
if [[ -n "$parsed_flags" ]]; then
  declare -A V
  while IFS='=' read -r k v; do
    V["$k"]="$v"
  done <<< "$parsed_flags"
fi
name=${V[name]}
delete=${V[delete]}

# check on flags
if [[ -n "$name" && -n "$delete" ]]; then
  echo "Error: --name and --delete cannot be used together."
  exit 1
fi

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

# get hostname
url="${HOSTNAME}"
hostname="${url%%.*}"

# derived

# delete workflow
if [[ -n "$delete" ]]; then
  if [[ -d "$WORKFLOWS_USER_PATH/$delete" ]]; then
    sudo "$ODEV_PATH/src/rm.sh" "$ODEV_PATH" "$ODEV_PATH/cmd/new/$delete.sh"
    sudo "$ODEV_PATH/src/rm.sh" "$ODEV_PATH" "$ODEV_PATH/cmd/build/$delete.sh"
    sudo "$ODEV_PATH/src/rm.sh" "$ODEV_PATH" "$ODEV_PATH/cmd/program/$delete.sh"
    sudo "$ODEV_PATH/src/rm.sh" "$ODEV_PATH" "$ODEV_PATH/cmd/run/$delete.sh"
    sudo "$ODEV_PATH/src/rm.sh" "$ODEV_PATH" "$ODEV_PATH/cmd/validate/$delete.sh"
    rm -rf -- "$WORKFLOWS_USER_PATH/$delete"
  fi
  exit 1
fi

# run interactive prompt
parsed_flags="$("$ODEV_PATH/src/cmd_prompt.sh" --required "$mandatory_flags" --params "${flags[@]}" -- "$parsed_flags")" || exit 1

# read flags (2)
if [[ -n "$parsed_flags" ]]; then
  declare -A V
  while IFS='=' read -r k v; do
    V["$k"]="$v"
  done <<< "$parsed_flags"
fi
name=${V[name]}
delete=${V[delete]}

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

# create workflows folder
mkdir -p "$WORKFLOWS_USER_PATH/$name"
cd "$WORKFLOWS_USER_PATH/$name"

# copy from template
cp -r "$WORKFLOWS_TEMPLATE_PATH"/* .

# create other files
cp "$WORKFLOWS_USER_PATH/$name/new.sh" "$WORKFLOWS_USER_PATH/$name/build.sh"
cp "$WORKFLOWS_USER_PATH/$name/new.sh" "$WORKFLOWS_USER_PATH/$name/program.sh"
cp "$WORKFLOWS_USER_PATH/$name/new.sh" "$WORKFLOWS_USER_PATH/$name/run.sh"
cp "$WORKFLOWS_USER_PATH/$name/new.sh" "$WORKFLOWS_USER_PATH/$name/validate.sh"

#echo "I am a odev-developer? The answer is $is_odev_developer"
#exit

# replace WFNAME (and _COMMAND_)
sed -i "s/WFNAME/${name^^}/g" "$WORKFLOWS_USER_PATH/$name/cmd_spec.sh"
sed -i "s/WFNAME/${name}/g" "$WORKFLOWS_USER_PATH/$name/new.sh"
sed -i "s/_COMMAND_/new/g" "$WORKFLOWS_USER_PATH/$name/new.sh"
sed -i "s/WFNAME/${name}/g" "$WORKFLOWS_USER_PATH/$name/build.sh"
sed -i "s/_COMMAND_/build/g" "$WORKFLOWS_USER_PATH/$name/build.sh"
sed -i "s/WFNAME/${name}/g" "$WORKFLOWS_USER_PATH/$name/program.sh"
sed -i "s/_COMMAND_/program/g" "$WORKFLOWS_USER_PATH/$name/program.sh"
sed -i "s/WFNAME/${name}/g" "$WORKFLOWS_USER_PATH/$name/run.sh"
sed -i "s/_COMMAND_/run/g" "$WORKFLOWS_USER_PATH/$name/run.sh"
sed -i "s/WFNAME/${name}/g" "$WORKFLOWS_USER_PATH/$name/validate.sh"
sed -i "s/_COMMAND_/validate/g" "$WORKFLOWS_USER_PATH/$name/validate.sh"

# create symlinks
sudo $ODEV_PATH/src/ln_s.sh "$ODEV_PATH" "$WORKFLOWS_USER_PATH/$name/new.sh" "$ODEV_PATH/cmd/new/$name.sh"
sudo $ODEV_PATH/src/ln_s.sh "$ODEV_PATH" "$WORKFLOWS_USER_PATH/$name/build.sh" "$ODEV_PATH/cmd/build/$name.sh"
sudo $ODEV_PATH/src/ln_s.sh "$ODEV_PATH" "$WORKFLOWS_USER_PATH/$name/program.sh" "$ODEV_PATH/cmd/program/$name.sh"
sudo $ODEV_PATH/src/ln_s.sh "$ODEV_PATH" "$WORKFLOWS_USER_PATH/$name/run.sh" "$ODEV_PATH/cmd/run/$name.sh"
sudo $ODEV_PATH/src/ln_s.sh "$ODEV_PATH" "$WORKFLOWS_USER_PATH/$name/validate.sh" "$ODEV_PATH/cmd/validate/$name.sh"

# create scripts
#scripts=("new" "build" "program" "run" "validate")
#for script in "${scripts[@]}"; do
#  file="$WORKFLOWS_USER_PATH/$name/${script}.sh"
#  touch "$file"
#  echo "#!/bin/bash" >> "$file"
#  echo "" >> "$file"
#  echo "echo \"Hi from ${name}/${script}.sh script!\"" >> "$file"
#  chmod +x "$file"
#done

# create constants
#touch "$WORKFLOWS_USER_PATH/$name/constants.yml"
#echo "---" >> "$WORKFLOWS_USER_PATH/$name/constants.yml"
#echo "" >> "$WORKFLOWS_USER_PATH/$name/constants.yml"
#echo "# my_constants" >> "$WORKFLOWS_USER_PATH/$name/constants.yml"
#echo "my_constants:" >> "$WORKFLOWS_USER_PATH/$name/constants.yml"
#echo "  year: 1982" >> "$WORKFLOWS_USER_PATH/$name/constants.yml"
#echo "  month: August" >> "$WORKFLOWS_USER_PATH/$name/constants.yml"
#echo "  day: 15" >> "$WORKFLOWS_USER_PATH/$name/constants.yml"

# add to GitHub