#!/bin/bash

# example: odev validate nccl --ngpus 1 --nthreads 1 --minbytes 8M --maxbytes 1G --iters 20 --datatype float

# early exit
url="${HOSTNAME}"
hostname="${url%%.*}"

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW="$(basename "${BASH_SOURCE[0]}" .sh)"

# derive from SCRIPT_DIR
CLI_NAME="$(basename "$(dirname "$(dirname "$SCRIPT_DIR")")")"
COMMAND="$(basename "$SCRIPT_DIR")"
ODEV_PATH="${ODEV_PATH:-"$(dirname "$SCRIPT_DIR")"}"

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

# constants
CMDB_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths cmdb)")"
COLOR_OREOL=$($ODEV_PATH/src/color_get.sh $ODEV_PATH COLOR_OREOL)
LOCAL_TEST="1"
PROJECTS_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths projects)")"
VALIDATION_PROJECT_PATH="$PROJECTS_PATH/validate.$WORKFLOW.$hostname"

# derived
MPI_HOME="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$CMDB_PATH/vars.yml" mpi home)")"

# get command description and parameters
KEY="$(printf '%s_%s' "$COMMAND" "$WORKFLOW" | tr '[:lower:]' '[:upper:]')"
result="$("$ODEV_ROOT/src/cmd_flags_read.sh" "$ODEV_ROOT" "$KEY")"
COMMAND_DESCRIPTION="$(echo "$result" | sed -n 's/^DESCRIPTION=//p' | head -n1)"
FLAGS=()
while IFS= read -r line; do
  FLAGS+=("$line")
done < <(echo "$result" | sed -n 's/^FLAG=//p')

# (maybe) print help
print_range="1"
print_default="0"
print_both="0"
"$ODEV_ROOT/src/cmd_help_print.sh" --maybe \
  "$CLI_NAME" "$COMMAND" "$WORKFLOW" "$COMMAND_DESCRIPTION" \
  "$print_range" "$print_default" "$print_both" \
  "${FLAGS[@]}" -- "$@" && exit 0 || true

# parse and check flag values
parsed_flags="$("$ODEV_ROOT/src/cmd_parse.sh" --params "${FLAGS[@]}" -- "$@")" || exit 1
declare -A V
while IFS='=' read -r k v; do
  V["$k"]="$v"
done <<< "$parsed_flags"

# read flags
ngpus=${V[ngpus]}
nthreads=${V[nthreads]}
minbytes=${V[minbytes]}
maxbytes=${V[maxbytes]}
iters=${V[iters]}
datatype=${V[datatype]}
stepfactor=${V[stepfactor]}

# ------------------------------------------------------------
flags="--ngpus $ngpus --nthreads $nthreads --minbytes $minbytes --maxbytes $maxbytes --iters $iters --datatype $datatype --stepfactor $stepfactor"
# ------------------------------------------------------------

# create folders
step_1="rm -rf $VALIDATION_PROJECT_PATH"
step_2="mkdir -p $VALIDATION_PROJECT_PATH"

# copy files from template
step_3="cp -r $ODEV_PATH/templates/nvidia/nccl-tests/. $VALIDATION_PROJECT_PATH"

# build tets
step_4="cd $VALIDATION_PROJECT_PATH"
if [ "$LOCAL_TEST" = "1" ]; then
    step_5="make"
else
    step_5="make MPI=1 MPI_HOME=$MPI_HOME"
fi

# run
step_6="cd $VALIDATION_PROJECT_PATH/build"
step_7="./all_gather_perf $flags"
#step_7=$command
#step_7="./all_gather_perf -g 1 -b 8M -e 1G -f 2"

# echo steps
echo ""
echo -e "${bold}$CLI_NAME $COMMAND $WORKFLOW $flags${normal}"
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
#eval "$command -f 2"

#./all_gather_perf --ngpus $ngpus --nthreads $nthreads --minbytes $minbytes --maxbytes $maxbytes --iters $iters --datatype $datatype



#./odev validate nccl --ngpus 1 --nthreads 1 --minbytes 8M --maxbytes 1G --iters 20 --datatype float
#./all_gather_perf -g 1 -b 8M -e 1G -f 2