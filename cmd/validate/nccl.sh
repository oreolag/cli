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

# get command description and parameters
KEY="$(printf '%s_%s' "$COMMAND" "$WORKFLOW" | tr '[:lower:]' '[:upper:]')"
result="$("$ODEV_ROOT/src/cmd_flags_read.sh" "$ODEV_ROOT" "$KEY")"
COMMAND_DESCRIPTION="$(echo "$result" | sed -n 's/^DESCRIPTION=//p' | head -n1)"
FLAGS=()
while IFS= read -r line; do
  FLAGS+=("$line")
done < <(echo "$result" | sed -n 's/^FLAG=//p')

# (maybe) print help
print_range="0"
print_default="0"
print_both="0"
"$ODEV_ROOT/src/cmd_help_print.sh" --maybe \
  "$CLI_NAME" "$COMMAND" "$WORKFLOW" "$COMMAND_DESCRIPTION" \
  "$print_range" "$print_default" "$print_both" \
  "${FLAGS[@]}" -- "$@" && exit 0 || true

# parse
declare -A V
while IFS='=' read -r k v; do
  V["$k"]="$v"
done < <(
  "$ODEV_ROOT/src/cmd_parse.sh" \
    --params "${FLAGS[@]}" -- "$@"
)

# read flags
ngpus=${V[ngpus]}
nthreads=${V[nthreads]}
minbytes=${V[minbytes]}
maxbytes=${V[maxbytes]}
iters=${V[iters]}
datatype=${V[datatype]}

# print command
echo ""
echo "${bold}$CLI_NAME $COMMAND $WORKFLOW --ngpus $ngpus --nthreads $nthreads --minbytes $minbytes --maxbytes $maxbytes --iters $iters --datatype $datatype${normal}"
echo ""
exit

# constants
CMDB_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths cmdb)")"
PROJECTS_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths projects)")"
VALIDATION_PROJECT_PATH="$PROJECTS_PATH/validate.$WORKFLOW.$hostname"

# derived
MPI_HOME="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$CMDB_PATH/vars.yml" mpi home)")"

# create folders
rm -rf "$VALIDATION_PROJECT_PATH"
mkdir -p "$VALIDATION_PROJECT_PATH"

# copy files from template
cp -r "$ODEV_PATH/templates/nvidia/nccl-tests/." "$VALIDATION_PROJECT_PATH"

# build tets (for local tests, MPI flag is not needed)
cd "$VALIDATION_PROJECT_PATH"
make MPI=1 MPI_HOME=$MPI_HOME

# run
#cd "$VALIDATION_PROJECT_PATH/build"
#./all_gather_perf -g 1 -b 8M -e 1G -f 2