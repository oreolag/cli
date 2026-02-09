#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ODEV_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
WORKFLOW="$(basename "${BASH_SOURCE[0]}" .sh)"

# usage:       $CLI_PATH/hdev validate opennic --commit $commit_name_shell $commit_name_driver --device $device_index --fec $fec_option --version $vivado_version
# example: /opt/hdev/cli/hdev validate opennic --commit            8077751             1cf2578 --device             1 --fec 1           --version          2022.2

# early exit
url="${HOSTNAME}"
hostname="${url%%.*}"

# constants
PROJECTS_PATH="$(eval echo "$("$ODEV_ROOT/src/constants_get.py" --db "$ODEV_ROOT/src/constants.yml" paths projects)")"
VALIDATION_PROJECT_PATH="$PROJECTS_PATH/validate.$WORKFLOW.$hostname"

# create folders
rm -rf "$VALIDATION_PROJECT_PATH"
mkdir -p "$VALIDATION_PROJECT_PATH"

# copy files from template
cp -r "$ODEV_ROOT/src/templates/nvidia/nccl-tests/." "$VALIDATION_PROJECT_PATH"

# build tets
cd "$VALIDATION_PROJECT_PATH"
make #make MPI=1


# run
cd "$VALIDATION_PROJECT_PATH/build"
./all_gather_perf -g 1 -b 8M -e 1G -f 2