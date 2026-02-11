#!/bin/bash

# usage:       $CLI_PATH/hdev validate opennic --commit $commit_name_shell $commit_name_driver --device $device_index --fec $fec_option --version $vivado_version
# example: /opt/hdev/cli/hdev validate opennic --commit            8077751             1cf2578 --device             1 --fec 1           --version          2022.2

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

# command description and parameters
COMMAND_DESCRIPTION="Validate NCCL"
PARAMS=(
  "ngpus,g,Number of GPUs,1-10,1"
  "nthreads,t,Number of Threads,1-1024,10"
  "minbytes,b,Minimum Bytes,1B-1G,8M"
  "maxbytes,e,Maximum Bytes,1B-16G,100M"
)

# find if help
show_help=0
for a in "$@"; do
  if [[ "$a" == "-h" || "$a" == "--help" ]]; then
    show_help=1
    break
  fi
done

if [[ "$show_help" == "1" ]]; then
  "$ODEV_ROOT/src/print_cmd_help.sh" \
    "$CLI_NAME" \
    "$COMMAND" \
    "$WORKFLOW" \
    "$COMMAND_DESCRIPTION" \
    "0" "0" "1" \
    "${PARAMS[@]}"
  exit 0
fi

# parse
declare -A V
while IFS='=' read -r k v; do
  V["$k"]="$v"
done < <(
  "$ODEV_ROOT/src/cmd_parse.sh" \
    --params "${PARAMS[@]}" -- "$@"
)

# Example: print received values
echo "ngpus=${V[ngpus]}"
echo "minbytes=${V[minbytes]}"
exit


# early exit
url="${HOSTNAME}"
hostname="${url%%.*}"

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