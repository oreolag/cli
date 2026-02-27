#!/bin/bash

# example: odev validate nccl --ngpus 1 --nthreads 1 --minbytes 8M --maxbytes 1G --iters 20 --datatype float --stepfactor 2

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBCOMMAND="$(basename "${BASH_SOURCE[0]}" .sh)"

# derive from SCRIPT_DIR
CLI_NAME="$(basename "$(dirname "$(dirname "$SCRIPT_DIR")")")"
COMMAND="$(basename "$SCRIPT_DIR")"
ODEV_PATH="${ODEV_PATH:-"$(dirname "$SCRIPT_DIR")"}"

# read command description
KEY="$(printf '%s_%s' "$COMMAND" "$SUBCOMMAND" | tr '[:lower:]' '[:upper:]')"
command_description="$("$ODEV_PATH/src/description_read.sh" "$ODEV_PATH" "$KEY")"

# read command flags
mapfile -t flags < <("$ODEV_PATH/src/cmd_flags_read.sh" "$ODEV_PATH" "$KEY")

# (maybe) print help
print_range="1"
print_default="0"
print_both="0"
"$ODEV_PATH/src/help_print.sh" --maybe \
  "$CLI_NAME" "$COMMAND" "$SUBCOMMAND" "$command_description" \
  "$print_range" "$print_default" "$print_both" \
  "${flags[@]}" -- "$@" && exit 0 || true

# parse and check flag values
parsed_flags="$("$ODEV_PATH/src/cmd_parse.sh" --params "${flags[@]}" -- "$@")" || exit 1
if [[ -n "$parsed_flags" ]]; then
  declare -A V
  while IFS='=' read -r k v; do
    V["$k"]="$v"
  done <<< "$parsed_flags"
fi

# read flags
ngpus=${V[ngpus]}
nthreads=${V[nthreads]}
minbytes=${V[minbytes]}
maxbytes=${V[maxbytes]}
iters=${V[iters]}
datatype=${V[datatype]}
stepfactor=${V[stepfactor]}

# set command flags
flags="--ngpus $ngpus --nthreads $nthreads --minbytes $minbytes --maxbytes $maxbytes --iters $iters --datatype $datatype --stepfactor $stepfactor"

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

# get hostname
url="${HOSTNAME}"
hostname="${url%%.*}"

# constants
CMDB_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths cmdb)")"
COLOR_OREOL=$($ODEV_PATH/src/color_get.sh $ODEV_PATH COLOR_OREOL)
LOCAL_TEST="1"
PROJECTS_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths projects)")"
VALIDATION_PROJECT_PATH="$PROJECTS_PATH/validate.$COMMAND.$hostname"

# derived
MPI_HOME="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$CMDB_PATH/vars.yml" mpi home)")"

# steps
# create folders
step_1="rm -rf $VALIDATION_PROJECT_PATH"
step_2="mkdir -p $VALIDATION_PROJECT_PATH"

# copy files from template
step_3="cp -r $ODEV_PATH/templates/nvidia/nccl-tests/. $VALIDATION_PROJECT_PATH"

# build
step_4="cd $VALIDATION_PROJECT_PATH"
if [ "$LOCAL_TEST" = "1" ]; then
    step_5="make"
else
    step_5="make MPI=1 MPI_HOME=$MPI_HOME"
fi

# run
step_6="cd $VALIDATION_PROJECT_PATH/build"
step_7="./all_gather_perf $flags"

# echo steps
echo ""
echo -e "${bold}$CLI_NAME $SUBCOMMAND $COMMAND $flags${normal}"
echo ""
echo -e "${COLOR_OREOL}$step_1${normal}"
echo -e "${COLOR_OREOL}$step_2${normal}"
echo -e "${COLOR_OREOL}$step_3${normal}"
echo -e "${COLOR_OREOL}$step_4${normal}"
echo -e "${COLOR_OREOL}$step_5${normal}"
echo -e "${COLOR_OREOL}$step_6${normal}"
echo -e "${COLOR_OREOL}$step_7${normal}"
echo ""

# eval steps
eval $step_1
eval $step_2
eval $step_3
eval $step_4
eval $step_5
eval $step_6
eval $step_7

# author: https://github.com/jmoya82