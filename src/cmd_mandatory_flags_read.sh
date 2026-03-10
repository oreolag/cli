#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   cmd_mandatory_flags_read.sh <ODEV_PATH> <KEY> [--db CMD_SPEC]
#
# Output:
#   MANDATORY flags string (e.g. name,ngpus)

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

mandatory_var="${KEY}_FLAGS_MANDATORY"
mandatory="${!mandatory_var:-}"

[[ -n "$mandatory" ]] || { echo "cmd_mandatory_flags_read: missing $mandatory_var" >&2; exit 1; }

echo "$mandatory"