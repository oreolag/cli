#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   cmd_flags_read.sh <ODEV_PATH> <KEY>
# Output:
#   FLAG=<spec>  (one per line)

ODEV_PATH="$1"
KEY="$2"

# shellcheck source=/dev/null
source "$ODEV_PATH/src/cmd_flags.sh"

flags_var="${KEY}_FLAGS"

# If variable does not exist → no flags → success
declare -p "$flags_var" >/dev/null 2>&1 || exit 0

# copy array safely
eval "__cmd_flags_arr=( \"\${${flags_var}[@]}\" )"

for f in "${__cmd_flags_arr[@]:-}"; do
    [[ -n "$f" ]] && echo "$f"
done