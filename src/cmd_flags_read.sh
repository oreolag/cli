#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   cmd_flags_read.sh <ODEV_PATH> <KEY> [--db CMD_SPEC]
#
# Output:
#   FLAG=<spec>  (one per line)

ODEV_PATH="$1"
KEY="$2"
shift 2

CMD_SPEC="$ODEV_PATH/src/cmd_spec.sh"

# optional arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db)
      CMD_SPEC="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# shellcheck source=/dev/null
source "$CMD_SPEC"

flags_var="${KEY}_FLAGS"

# If variable does not exist → no flags → success
declare -p "$flags_var" >/dev/null 2>&1 || exit 0

# copy array safely
eval "__cmd_flags_arr=( \"\${${flags_var}[@]}\" )"

for f in "${__cmd_flags_arr[@]:-}"; do
  [[ -n "$f" ]] && echo "$f"
done