#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ODEV_ROOT="${ODEV_ROOT:-"$(dirname "$SCRIPT_DIR")"}"
WORKFLOW="$(basename "${BASH_SOURCE[0]}" .sh)"

# usage:       $CLI_PATH/hdev validate opennic --commit $commit_name_shell $commit_name_driver --device $device_index --fec $fec_option --version $vivado_version
# example: /opt/hdev/cli/hdev validate opennic --commit            8077751             1cf2578 --device             1 --fec 1           --version          2022.2

# help
print_help() {
  echo "Usage: odev validate nccl [options]"
  echo ""
  echo "Options:"
  echo "  --gpus N        Number of GPUs (default: 1)"
  echo "  -b SIZE         Bandwidth / message size (default: 8M)"
  echo "  -h, --help      Show this help"
}

# parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --gpus|-g)
      gpus="$2"
      shift 2
      ;;
    -b)
      b="$2"
      shift 2
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# print received values
echo "GPUs      : $gpus"
echo "Bandwidth : $b"

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