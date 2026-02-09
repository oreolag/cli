#!/bin/bash

#CLI_PATH="$(dirname "$(dirname "$0")")"
#CLI_NAME="hdev"
#bold=$(tput bold)
#normal=$(tput sgr0)

#usage:       $CLI_PATH/hdev validate opennic --commit $commit_name_shell $commit_name_driver --device $device_index --fec $fec_option --version $vivado_version
#example: /opt/hdev/cli/hdev validate opennic --commit            8077751             1cf2578 --device             1 --fec 1           --version          2022.2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ODEV_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

# constants
TMP_PATH="$("$ODEV_ROOT/src/constants_get.py" --db "$ODEV_ROOT/src/constants.yml" paths tmp)"

echo $TMP_PATH

# create folders
