#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ODEV_ROOT="${ODEV_ROOT:-"$(dirname "$SCRIPT_DIR")"}"
WORKFLOW="$(basename "${BASH_SOURCE[0]}" .sh)"

# usage:       $CLI_PATH/hdev validate opennic --commit $commit_name_shell $commit_name_driver --device $device_index --fec $fec_option --version $vivado_version
# example: /opt/hdev/cli/hdev validate opennic --commit            8077751             1cf2578 --device             1 --fec 1           --version          2022.2

# name,short,default,description
PARAMS=(
  "ngpus,g,1,Number of GPUs"
  "nthreads,t,10,Number of Threads"
  "minbytes,b,8M,Minimum Bytes"
  "maxbytes,e,100M,Maximum Bytes"
)

declare -A V

# init defaults
for p in "${PARAMS[@]}"; do
  IFS=',' read -r name short def desc <<< "$p"
  V["$name"]="$def"
done

print_help() {
  echo "Usage: odev validate nccl [options]"
  echo ""
  echo "Options:"
  for p in "${PARAMS[@]}"; do
    IFS=',' read -r name short def desc <<< "$p"
    printf "  --%-12s -%-2s %-28s (default: %s)\n" "$name" "$short" "$desc" "$def"
  done
  echo "  -h, --help      Show this help"
}

# parse
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) print_help; exit 0 ;;
  esac

  matched=false
  for p in "${PARAMS[@]}"; do
    IFS=',' read -r name short def desc <<< "$p"
    if [[ "$1" == "--$name" || "$1" == "-$short" ]]; then
      V["$name"]="${2:-}"
      shift 2
      matched=true
      break
    fi
  done

  if [[ "$matched" == false ]]; then
    echo "Unknown option: $1"
    exit 1
  fi
done

# Example: print received values
echo "ngpus=${V[ngpus]}"
echo "minbytes=${V[minbytes]}"

echo "hola"
exit


# early exit
url="${HOSTNAME}"
hostname="${url%%.*}"

# constants
CMDB_PATH="$(eval echo "$("$ODEV_ROOT/src/read_yml.py" --db "$ODEV_ROOT/constants.yml" paths cmdb)")"
PROJECTS_PATH="$(eval echo "$("$ODEV_ROOT/src/read_yml.py" --db "$ODEV_ROOT/constants.yml" paths projects)")"
VALIDATION_PROJECT_PATH="$PROJECTS_PATH/validate.$WORKFLOW.$hostname"

# derived
MPI_HOME="$(eval echo "$("$ODEV_ROOT/src/read_yml.py" --db "$CMDB_PATH/vars.yml" mpi home)")"

# create folders
rm -rf "$VALIDATION_PROJECT_PATH"
mkdir -p "$VALIDATION_PROJECT_PATH"

# copy files from template
cp -r "$ODEV_ROOT/templates/nvidia/nccl-tests/." "$VALIDATION_PROJECT_PATH"

# build tets (for local tests, MPI flag is not needed)
cd "$VALIDATION_PROJECT_PATH"
make MPI=1 MPI_HOME=$MPI_HOME

# run
#cd "$VALIDATION_PROJECT_PATH/build"
#./all_gather_perf -g 1 -b 8M -e 1G -f 2