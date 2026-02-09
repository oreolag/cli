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

# create folders
mkdir -p "$PROJECTS_PATH/validate_$WORKFLOW_$hostname"